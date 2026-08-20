module Sprig
  class Planter
    # Internal signal raised to trigger a rollback of the seeding transaction.
    # Adapter-specific wrapping translates or rescues this as appropriate.
    class Rollback < StandardError; end

    class MissingDependencyError < StandardError; end

    class CircularDependencyError < StandardError; end

    # `transactional_anchor_class` is an optional hint used only by the Mongoid
    # wrapping path (see #transactional_anchor_class below) to open a DB transaction
    def initialize(transactional_anchor_class = nil)
      @planted = {}                                # dependency_id => true
      @waiting_for = Hash.new { |h, k| h[k] = [] }  # unmet dependency_id => [descriptor]
      @pending_count = {}                           # descriptor => remaining unmet count
      @transactional_anchor_class_hint = transactional_anchor_class
    end

    # Offers a descriptor for planting. If everything it depends on has already
    # been planted, it -- and anything that was only waiting on it -- is planted
    # immediately; otherwise it's held until its remaining dependencies resolve.
    def <<(descriptor)
      unmet = unmet_dependency_ids(descriptor)
      if unmet.empty?
        plant_and_cascade(descriptor)
      else
        @pending_count[descriptor] = unmet.size
        unmet.each { |id| @waiting_for[id] << descriptor }
      end
    end

    # Wraps population -- performed by the given block, which is expected to push
    # descriptors via `<<` -- and finalization in the seeding transaction, if
    # configured/supported. Unlike the old whole-graph-then-plant design (where
    # `sprig` just looped over an already-complete, pre-sorted list), records are
    # now built and saved continuously as they're offered, so the transaction has
    # to wrap the population step itself -- wrapping only the finalization below
    # would let every real save happen outside of it, making rollback a no-op.
    def sprig
      wrap_in_transaction_if_supported do
        yield

        raise_if_anything_left_unresolved

        if notifier.errors? && transactional_wrapping_requested_and_supported?
          notifier.rollback
          raise Rollback
        end
      end

      notifier.finished
    end

    private

    attr_reader :transactional_anchor_class_hint

    def notifier
      @notifier ||= ProcessNotifier.new
    end

    def unmet_dependency_ids(descriptor)
      descriptor.dependencies.map(&:id).reject { |id| @planted[id] }
    end

    # Iterative, not recursive: a long chain (self-referencing hierarchies are
    # exactly what this gem is often used to seed) can cascade-resolve thousands of
    # waiters at once when the blocking record finally arrives -- a recursive
    # version of this would blow Ruby's stack at ~11,000 deep during prototyping.
    def plant_and_cascade(first)
      queue = [first]
      until queue.empty?
        descriptor = queue.shift
        plant(descriptor)

        # Marked "planted" (attempted) regardless of whether the save itself
        # succeeded -- this is what lets a descriptor whose dependency failed to
        # save still be attempted and independently fail/skip on its own instead of
        # being stuck forever as if the dependency graph itself were broken.
        @planted[descriptor.dependency_id] = true

        woken = @waiting_for.delete(descriptor.dependency_id) || []
        woken.each do |waiting|
          @pending_count[waiting] -= 1
          if @pending_count[waiting] == 0
            @pending_count.delete(waiting)
            queue << waiting
          end
        end
      end
    end

    def plant(descriptor)
      notifier.in_progress(descriptor)
      entry = descriptor.to_entry
      entry.before_save

      if entry.save_record
        entry.save_to_store
        notifier.success(entry)
      else
        notifier.error(entry)
      end
    rescue => e
      notifier.exception(entry || descriptor, e)
    end

    # Anything still waiting once every descriptor has been offered shows a
    # structural problem: either a genuine reference to a sprig_id that appears
    # nowhere in the data, or a cycle (directly, or a chain stuck behind one
    # elsewhere). A missing reference is reported in preference to a cycle when
    # both are present.
    def raise_if_anything_left_unresolved
      return if @pending_count.empty?

      stuck = @pending_count.keys
      stuck_ids = {}
      stuck.each { |descriptor| stuck_ids[descriptor.dependency_id] = true }

      stuck.each do |descriptor|
        unmet_dependency_ids(descriptor).each do |id|
          unless stuck_ids[id]
            raise MissingDependencyError, "Undefined reference to '#{format_dependency_id(id)}'"
          end
        end
      end

      formatted = stuck_ids.keys.map { |id| format_dependency_id(id) }
      raise CircularDependencyError, "Your sprig directives contain circular dependencies among: #{formatted.join(", ")}"
    end

    # A Dependency#id is always "<klass.name> <sprig_id>" -- klass.name can never
    # contain a space, so splitting on the first one reliably recovers both parts.
    def format_dependency_id(id)
      klass_name, sprig_id = id.split(" ", 2)
      "sprig_record(#{klass_name}, #{sprig_id})"
    end

    def transactional_wrapping_requested_and_supported?
      Sprig.configuration.wrap_in_transaction && !transactional_anchor_class.nil?
    end

    def wrap_in_transaction_if_supported
      return yield unless Sprig.configuration.wrap_in_transaction

      klass = transactional_anchor_class

      unless klass
        notifier.warning("The `#{Sprig.adapter}` adapter doesn't support transactional wrapping.")
        return yield
      end

      case Sprig.adapter
      when :active_record
        wrap_in_active_record_transaction(klass) { yield }
      when :mongoid
        wrap_in_mongoid_transaction(klass) { yield }
      end
    end

    def wrap_in_active_record_transaction(klass)
      klass.transaction do
        begin
          yield
        rescue Rollback
          raise ActiveRecord::Rollback
        end
      end
    end

    # Mongoid's own `.transaction` convenience method (and
    # `Mongoid::Errors::Rollback`) only exist as of Mongoid 9, so this drives
    # the underlying Mongo::Session directly - `with_session`/`with_transaction`
    # are available on every Mongoid version Sprig supports. All persistence
    # operations inside the block pick up the session implicitly via
    # Mongoid's thread-local session tracking.
    def wrap_in_mongoid_transaction(klass)
      klass.with_session do |session|
        session.with_transaction { yield }
      end
    rescue Rollback
      nil
    end

    # The class whose client a seeding run's transaction is anchored to.
    # ActiveRecord's connection is shared across all its models, so
    # ActiveRecord::Base works as a generic anchor regardless of what's being
    # seeded. Mongoid sessions are scoped to a specific model's client, so a real
    # seeded class has to be used instead of the `Mongoid::Document` module --
    # supplied via the constructor hint (see #initialize).
    def transactional_anchor_class
      @transactional_anchor_class ||= case Sprig.adapter
      when :active_record
        ActiveRecord::Base
      when :mongoid
        transactional_anchor_class_hint
      end
    end
  end
end

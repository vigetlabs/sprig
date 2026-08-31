module Sprig
  class Planter
    # Internal signal raised to trigger a rollback of the seeding transaction.
    # Adapter-specific wrapping translates or rescues this as appropriate.
    class Rollback < StandardError; end

    def initialize(seeds)
      @seeds = seeds.to_a
    end

    def sprig
      wrap_in_transaction_if_supported do
        dependency_sorted_seeds.each do |seed|
          plant(seed)
        end

        if notifier.errors? && transactional_wrapping_requested_and_supported?
          notifier.rollback
          raise Rollback
        end
      end

      notifier.finished
    end

    private

    attr_reader :seeds

    def dependency_sorted_seeds
      @dependency_sorted_seeds ||= DependencySorter.new(seeds).sorted_items
    end

    def notifier
      @notifier ||= ProcessNotifier.new
    end

    def plant(seed)
      notifier.in_progress(seed)
      entry = seed.to_entry
      entry.before_save

      if entry.save_record
        entry.save_to_store
        notifier.success(entry)
      else
        notifier.error(entry)
      end
    rescue => e
      notifier.exception(entry || seed, e)
    end

    def transactional_wrapping_requested_and_supported?
      Sprig.configuration.wrap_in_transaction && !transactional_anchor_class.nil?
    end

    def wrap_in_transaction_if_supported
      return yield unless Sprig.configuration.wrap_in_transaction
      return yield if dependency_sorted_seeds.empty?

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
    # ActiveRecord::Base works as a generic anchor. Mongoid sessions are
    # scoped to a specific model's client, so a real seeded class has to be
    # used instead of the `Mongoid::Document` module.
    def transactional_anchor_class
      case Sprig.adapter
      when :active_record
        ActiveRecord::Base
      when :mongoid
        dependency_sorted_seeds.first.klass
      end
    end
  end
end

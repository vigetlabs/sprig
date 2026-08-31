require "delegate"

module Sprig
  class SprigRecordStore
    # Given that the overwhelming majority of references to a sprig_record are for
    # the id, we allow responding to sprig_record.id without a database call; a #get
    # for any other attribute/method will result in an actual database fetch,
    # memoized for the lifetime of the LazyRecord instance.
    #
    # Built on SimpleDelegator rather than a hand-rolled method_missing so that
    # methods the real record inherits from Object (#to_s, #inspect, #hash,
    # ActiveSupport's #as_json/#to_json, etc.) delegate correctly too -- those
    # are already defined on Object, so a plain method_missing override would
    # never even be consulted for them; Delegator's own method_missing fires
    # for those specifically because Delegator < BasicObject undefines its own
    # copies of them. Delegator does *not* similarly override #is_a?/#kind_of?/
    # #instance_of?/#class, so those still need their own overrides below.
    class LazyRecord < SimpleDelegator
      def initialize(klass, id)
        @klass = klass
        @id = id
        super(nil)
      end

      def id
        record = __getobj__(materialize: false)
        record ? record.id : @id
      end

      def to_real_record
        __getobj__
      end

      # Lazily fetched into (and cached in) SimpleDelegator's own __setobj__
      # storage -- not a separate ivar -- so that #dup/#clone, which work by
      # calling __getobj__ on the original and __setobj__ on the copy (see
      # Delegator#initialize_dup/#initialize_clone), duplicate *that* real
      # record and wire the copy up to use it, rather than the copy silently
      # re-fetching and re-wrapping the original by id.
      def __getobj__(materialize: true)
        record = super()
        return record if record || !materialize

        __setobj__(@klass.unscoped.find(@id))
      end

      # After a real dup/clone, #id must reflect the *new* record's own id
      # (nil for an unsaved dup) instead of the original's -- otherwise
      # #to_real_record above would be self-consistent but the fast-path
      # #id reader would still report the original's id.
      def initialize_dup(other)
        super
        @id = __getobj__.id
      end

      def initialize_clone(other, freeze: nil)
        if Sprig.adapter == :mongoid
          # Delegator's own #initialize_clone always calls
          # `obj.__getobj__.clone(freeze: freeze)` -- but Mongoid::Copyable#clone
          # (unlike ActiveRecord's) takes no arguments at all, so forwarding
          # freeze: through raises ArgumentError. Nothing else about cloning a
          # Mongoid document depends on freeze: anyway, so just drop it.
          __setobj__(other.__getobj__.clone)
        else
          super
        end
        @id = __getobj__.id
      end

      # Answered from the class given at construction, without triggering a
      # fetch -- also what makes this proxy pass a Rails/Mongoid association
      # assignment's own type check (which calls #is_a?, and in some versions
      # #class, on the value being assigned) as if it were the real record.
      #
      # This is only safe when @klass can't understate the real record's type,
      # i.e. when @klass isn't STI-enabled -- otherwise the row #id points at
      # could actually be a more specific subclass (e.g. sprig_record(Post, 1)
      # whose row is really a SpecialPost), and answering from @klass alone
      # would silently report the wrong class/ancestry. #sti_capable? gates a
      # fetch to only that case, so the common non-STI path still never queries.
      # Only meaningful for ActiveRecord -- Mongoid has no equivalent of
      # #columns_hash/#inheritance_column, and Mongoid::Document's own
      # polymorphic (`_type`-based) inheritance is a separate mechanism this
      # doesn't attempt to detect, so #sti_capable? is unconditionally false
      # there and this stays exactly as safe as it was before that fix.
      def class
        return @klass unless sti_capable?

        __getobj__.class
      end

      def is_a?(klass)
        return true if @klass <= klass
        return false unless sti_capable?

        __getobj__.is_a?(klass)
      end
      alias_method :kind_of?, :is_a?

      def instance_of?(klass)
        return @klass == klass unless sti_capable?

        __getobj__.instance_of?(klass)
      end

      private

      # True when @klass's table has an inheritance (STI) column -- meaning
      # @klass.find(@id) could actually return an instance of a more specific
      # subclass than @klass itself. Checked structurally (does the table have
      # the column), not by inspecting this particular row, so the common
      # non-STI model never pays for a fetch just to answer #class/#is_a?/
      # #instance_of?. #columns_hash/#inheritance_column are ActiveRecord::
      # ModelSchema methods Mongoid::Document doesn't define at all, so this
      # is gated to the active_record adapter rather than raising for Mongoid.
      def sti_capable?
        Sprig.adapter == :active_record && @klass.columns_hash.key?(@klass.inheritance_column.to_s)
      end
    end
  end
end

module Sprig
  class SprigRecordStore
    # What #get hands back for a saved sprig_id: the id itself, answered directly
    # with no database access, since that's all SprigRecordStore ever held onto.
    # Any other call -- an attribute, an association, anything beyond the id --
    # falls through to a real klass.find(id), fetched at most once and memoized,
    # then delegated to. sprig_record(Klass, id) usages that only ever need the id
    # (by far the common case -- setting a foreign key) never touch the database
    # at all; usages that need more than the id pay for exactly one real fetch,
    # same as before.
    #
    # Known limitation: this responds to arbitrary methods via delegation, but
    # #is_a?/#kind_of?/#instance_of? report LazyRecord's own class, not the
    # wrapped record's -- code that type-checks a sprig_record(...) result against
    # the model class directly (rather than calling a method on it) would need to
    # go through #to_real_record first.
    class LazyRecord
      attr_reader :id

      def initialize(klass, id)
        @klass = klass
        @id = id
      end

      def to_real_record
        @real_record ||= @klass.find(@id)
      end

      def ==(other)
        to_real_record == other
      end
      alias_method :eql?, :==

      def hash
        to_real_record.hash
      end

      def method_missing(name, *args, &block)
        to_real_record.public_send(name, *args, &block)
      end

      def respond_to_missing?(name, include_private = false)
        to_real_record.respond_to?(name, include_private)
      end
    end
  end
end

module Sprig
  class SprigRecordStore
    # Given that the overwhelming majority of references to a sprig_record are for
    # the id, we allow responding to sprig_record.id without a database call; a #get
    # for any other attribute/method will result in an actual database fetch,
    # memoized for the lifetime of the LazyRecord instance.
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

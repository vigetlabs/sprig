module Sprig
  class Dependency
    class << self
      def for(klass, sprig_id)
        new(to_klass(klass), sprig_id.to_s)
      end

      private

      def to_klass(klass)
        if klass.is_a?(String)
          klass = klass.classify.constantize
        end

        raise ArgumentError, "First argument must be a Class." unless klass.is_a?(Class)

        klass
      end
    end

    def initialize(klass, sprig_id)
      @klass = klass
      @sprig_id = sprig_id
    end

    # Deterministic IDs eliminate the need for caching. Using a space (the first space, if multiple
    # exist) is a safe delimiter -- Ruby class names cannot contain spaces.
    def id
      "#{klass.name} #{sprig_id}"
    end

    def sprig_record_reference
      "sprig_record(#{klass}, #{sprig_id})"
    end

    def ==(other)
      other.is_a?(Dependency) && id == other.id
    end
    alias_method :eql?, :==

    def hash
      id.hash
    end

    private

    attr_reader :klass, :sprig_id
  end
end

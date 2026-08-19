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

    # Deterministic, not cached: two separate Dependency.for(klass, sprig_id) calls with
    # the same arguments always produce the same id, so tsort's graph can link a
    # reference to the node it points at without any global registry keeping every
    # ever-seen Dependency alive for the whole run. The space is a safe separator --
    # neither a Ruby constant name nor a realistic sprig_id contains one.
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

module Sprig
  class Dependency
    attr_reader :id

    def self.for(klass, sprig_id)
      klass = to_klass(klass)
      sprig_id = sprig_id.to_s

      collection.get(klass, sprig_id) || new(klass, sprig_id)
    end

    def initialize(klass, sprig_id)
      @klass = klass
      @sprig_id = sprig_id
      @id = SecureRandom.uuid

      self.class.collection.set(klass, sprig_id, self)
    end

    def sprig_record_reference
      "sprig_record(#{klass}, #{sprig_id})"
    end

    private

    attr_reader :klass, :sprig_id

    def self.to_klass(klass)
      if klass.is_a?(String)
        klass = klass.classify.constantize
      end

      raise ArgumentError, 'First argument must be a Class.' unless klass.is_a?(Class)

      klass
    end

    def self.collection
      @@collection ||= DependencyCollection.new
    end
  end
end

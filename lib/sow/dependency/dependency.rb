module Sow
  module Dependency
    class Dependency
      attr_reader :id

      def self.for(klass, sow_id)
        klass = to_klass(klass)
        sow_id = sow_id.to_s

        collection.get(klass, sow_id) || new(klass, sow_id)
      end

      private

      def initialize(klass, sow_id)
        @klass = klass
        @sow_id = sow_id
        @id = SecureRandom.uuid

        self.class.collection.set(klass, sow_id, self)
      end

      def self.to_klass(klass)
        if klass.is_a?(String)
          klass = klass.classify.constantize
        end

        raise ArgumentError, 'First argument must be a Class.' unless klass.is_a?(Class)

        klass
      rescue NameError => e
        raise NameError, e.message
        #TODO: rescue bad class references
      end

      def self.collection
        @@collection ||= Collection.new
      end
    end
  end
end

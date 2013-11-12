module Sow
  module Dependency
    class Collection
      def initialize
        @records = {}
      end

      def get(klass, id)
        records_for_klass(klass)[id]
      end

      def set(klass, id, value)
        records_for_klass(klass)[id] = value
      end

      private

      attr_reader :records

      def records_for_klass(klass)
        records[klass] ||= {}
      end
    end
  end
end

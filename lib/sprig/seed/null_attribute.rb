module Sprig
  module Seed
    class NullAttribute
      attr_reader :name

      def initialize(name)
        @name = name.to_s
      end

      def dependencies
        []
      end

      def value
        nil
      end
    end
  end
end

module Sprig
  module Seed
    class AttributeCollection
      include Enumerable

      delegate :each, :to => :attributes

      def initialize(attrs_hash)
        @attrs_hash = attrs_hash.to_hash
      end

      def find_by_name(name)
        attributes.detect {|attribute| attribute.name == name.to_s } || NullAttribute.new(name)
      end

      private

      attr_reader :attrs_hash

      def attributes
        @attributes ||= attrs_hash.map do |name, value|
          Attribute.new(name, value)
        end
      end
    end
  end
end

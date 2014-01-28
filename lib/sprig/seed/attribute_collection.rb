module Sprig
  module Seed
    class AttributeCollection
      include Enumerable

      delegate :each, :to => :attributes

      def initialize(attrs_hash)
        @attrs_hash = attrs_hash.to_hash
      end

      def find_by_name(name)
        attributes.detect {|attribute| attribute.name == name.to_s } || attribute_not_found(name)
      end

      private

      attr_reader :attrs_hash

      class AttributeNotFoundError < StandardError; end

      def attributes
        @attributes ||= attrs_hash.map do |name, value|
          Attribute.new(name, value)
        end
      end

      def attribute_not_found(name)
        raise AttributeNotFoundError, "Attribute '#{name}' is not present."
      end
    end
  end
end

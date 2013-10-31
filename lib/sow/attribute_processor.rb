module Sow
  class AttributeProcessor
    def initialize(attributes)
      @attributes = attributes
    end

    def process
      return {} if @attributes.empty?

      @attributes.tap do |attrs|
        attrs.each do |name, value|
          process_attribute(attrs, name, value)
        end
      end
    end

    private

    def process_attribute(attributes, name, value)
      match = /{{(.*)}}/.match(value.to_s)

      if match
        attributes[name] = eval(match[1], PROCESSOR_BINDING)
      end
    end
  end
end

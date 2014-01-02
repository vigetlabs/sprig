module Sow
  module Seed
    class Attribute
      attr_reader :name, :raw_value, :value

      def initialize(name, raw_value)
        @name = name.to_s
        @raw_value = raw_value
      end

      def dependencies
        @dependencies ||= determine_dependencies.uniq
      end

      def value
        compute_value if @value.nil?

        @value
      end

      private

      def determine_dependencies
        if computed_value?
          matches = raw_value.scan(/(sow_record\(([A-Z][^,]*), ([\d]*)\))+/)
          matches.map {|match| Dependency.for(match[1], match[2]) }
        else
          []
        end
      end

      def string?
        raw_value.is_a?(String)
      end

      def computed_value?
        string? && raw_value =~ computed_value_regex
      end

      def computed_value_regex
        /<%[=]?(.*)%>/
      end

      def compute_value
        @value = if computed_value?
          matches = computed_value_regex.match(raw_value)
          eval(matches[1])
        else
          raw_value
        end
      end
    end
  end
end

module Sprig
  module Seed
    class Attribute
      attr_reader :name, :raw_value, :value

      def initialize(name, raw_value)
        @name = name.to_s
        @raw_value = raw_value
      end

      def dependencies
        @dependencies ||= find_dependencies_within(raw_value).uniq
      end

      def value
        @value = compute_value(raw_value) if @value.nil?

        @value
      end

      private

      def find_dependencies_within(value)
        if array?(value)
          find_dependencies_within_array(value)
        elsif string?(value) && computed_value?(value)
          find_dependencies_within_string(value)
        else
          []
        end
      end

      def find_dependencies_within_array(array)
        array.flat_map do |value|
          find_dependencies_within(value)
        end
      end

      def find_dependencies_within_string(string)
        matches = string.scan(/(sprig_record\(([A-Z][^,]*), ([\d]*)\))+/)
        matches.map { |match| Dependency.for(match[1], match[2]) }
      end

      def string?(value)
        value.is_a?(String)
      end

      def array?(value)
        value.is_a?(Array)
      end

      def computed_value?(value)
        String(value) =~ computed_value_regex
      end

      def computed_value_regex
        /<%[=]?(.*)%>/
      end

      def compute_value(value)
        if array?(value)
          compute_array_value(value)
        elsif string?(value) && computed_value?(value)
          compute_string_value(value)
        else
          value
        end
      end

      def compute_array_value(array)
        array.map do |value|
          compute_value(value)
        end
      end

      def compute_string_value(string)
        matches = computed_value_regex.match(string)
        eval(matches[1])
      end

    end
  end
end

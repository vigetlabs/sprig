module Sprig
  module Seed
    class Attribute
      include Sprig::Helpers

      # Matches a `sprig_record(Klass, <id text>)` reference, capturing the
      # klass name and the raw, unparsed id text between the comma and the
      # closing paren, eliminating any wrapping whitespace.
      # Example matches: `5`, `'cooldev'`, `"cooldev"`, or `:cooldev`.
      SPRIG_RECORD_REFERENCE = /sprig_record\(([A-Z][^,]*),\s*([^)]*?)\s*\)/

      # The four literal shapes an id can take, each capturing its unquoted value.
      SINGLE_QUOTED_ID = /'([^']*)'/
      DOUBLE_QUOTED_ID = /"([^"]*)"/
      SYMBOL_ID = /:(\w+)/
      NUMERIC_ID = /(\d+)/

      # Matches the raw id text captured above in its entirety against each of
      # the shapes above, figuring out which literal it is.
      ID_LITERAL = /\A(?:#{SINGLE_QUOTED_ID}|#{DOUBLE_QUOTED_ID}|#{SYMBOL_ID}|#{NUMERIC_ID})\z/

      attr_reader :name, :raw_value

      def initialize(name, raw_value)
        @name = name.to_s
        @raw_value = raw_value
      end

      def dependencies
        @dependencies ||= find_dependencies_within(raw_value).uniq
      end

      def value
        return @value if defined?(@value)

        @value = compute_value(raw_value)
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
        matches = string.scan(SPRIG_RECORD_REFERENCE)
        matches.map do |klass, id_text|
          Dependency.for(klass, id_from(id_text))
        end
      end

      def id_from(id_text)
        single_quoted, double_quoted, symbol, numeric = ID_LITERAL.match(id_text)&.captures
        single_quoted || double_quoted || symbol || numeric
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
        /(<%=?(.*?)%>)/
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

      def completely_dynamic_value?(string, matches)
        return false if matches.count > 1

        test_string = string.clone

        matches.each do |match|
          test_string = test_string.sub(match[0], "")
        end

        test_string.strip.length == 0
      end

      def compute_string_value(string)
        matches = string.scan(computed_value_regex)

        # Values come from developer-authored seed files (YAML/CSV in db/seeds),
        # not runtime user input — arbitrary Ruby evaluation is the intended feature.
        if completely_dynamic_value?(string, matches)
          # If the dynamic portion is the entire value, return the result of the eval
          # (This allows for the return of non-string types.)
          eval(matches.first[1]) # rubocop:disable Security/Eval
        else
          # Otherwise return the dynamic portion within the larger string.
          string.clone.tap do |return_string|
            matches.each do |match|
              return_string.sub!(match[0], eval(match[1]).to_s) # rubocop:disable Security/Eval
            end
          end
        end
      end
    end
  end
end

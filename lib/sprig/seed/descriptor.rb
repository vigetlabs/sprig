module Sprig
  module Seed
    class Descriptor
      COMPUTED_VALUE_REGEX = /(<%=?(.*?)%>)/

      attr_reader :klass

      def initialize(klass, raw_attrs, options)
        @klass = klass
        @raw_attrs = raw_attrs
        @options = options
      end

      # Computed on demand rather than memoized: DependencySorter reads this at most
      # twice, immediately after construction, so caching it would just be a
      # permanently-retained string with no benefit -- the graph structures that
      # actually need to persist (id_dictionary, dependency_hash) already hold their
      # own copies once they've read it.
      def dependency_id
        Dependency.for(klass, sprig_id).id
      end

      # Same reasoning as dependency_id: DependencySorter reads this exactly once,
      # right after construction, to build its graph -- so recomputing from raw_attrs
      # here instead of caching an array of Dependency objects means this descriptor
      # never needs to retain them at all.
      def dependencies
        deps = []

        raw_attrs.each_pair do |key, value|
          next if key.to_s == "sprig_id"

          scan_value(value) { |dep_klass, dep_sprig_id| deps << Dependency.for(dep_klass, dep_sprig_id) }
        end

        deps.uniq
      end

      def sprig_id
        @sprig_id ||= raw_attrs[:sprig_id] || raw_attrs["sprig_id"] || SecureRandom.uuid
      end

      def in_progress_text
        "Planting #{klass.name} with sprig_id #{sprig_id}"
      end

      def error_log_text
        "There was an error saving #{klass.name} with sprig_id #{sprig_id}."
      end

      def to_entry
        Entry.new(klass, raw_attrs, options, sprig_id)
      end

      private

      attr_reader :raw_attrs, :options

      def scan_value(value, &block)
        if value.is_a?(Array)
          value.each { |v| scan_value(v, &block) }
        elsif value.is_a?(String) && String(value) =~ COMPUTED_VALUE_REGEX
          value.scan(Attribute::SPRIG_RECORD_REFERENCE).each { |dep_klass, id_text| block.call(dep_klass, id_from(id_text)) }
        end
      end

      def id_from(id_text)
        single_quoted, double_quoted, symbol, numeric = Attribute::ID_LITERAL.match(id_text)&.captures
        single_quoted || double_quoted || symbol || numeric
      end
    end
  end
end

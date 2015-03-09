module Sprig
  module Seed
    class Factory
      def self.new_from_directive(directive)
        raise ArgumentError, 'Must provide a Directive' unless directive.is_a? Directive

        new(
          directive.klass,
          directive.datasource,
          directive.options
        )
      end

      def initialize(klass, datasource, options)
        self.klass           = klass
        self.datasource      = datasource
        self.initial_options = options
      end

      def add_seeds_to_hopper(hopper)
        datasource.records.each do |record_data|
          hopper << Entry.new(klass, record_data, options)
        end
      end

      private

      attr_reader :datasource, :initial_options, :klass

      def klass=(klass)
        raise ArgumentError, 'Must provide a Class as first argument' unless klass.is_a? Class

        klass.reset_column_information if defined?(ActiveRecord) && klass < ActiveRecord::Base
        @klass = klass
      end

      def datasource=(datasource)
        raise ArgumentError, 'Datasource must respond to #records and #options' unless datasource.respond_to?(:records) && datasource.respond_to?(:options)

        @datasource = datasource
      end

      def initial_options=(initial_options)
        initial_options ||= {}
        @initial_options = initial_options.to_hash
      end

      def options
        @options ||= datasource.options.merge(initial_options)
      end
    end
  end
end

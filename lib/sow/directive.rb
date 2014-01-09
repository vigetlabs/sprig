module Sow
  class Directive
    attr_reader :attributes

    def initialize(args)
      @attributes = args.is_a?(Hash) ? args : { :class => args }
    end

    def klass
      @klass ||= attributes.fetch(:class) { raise ArgumentError, 'Sow::Directive must provide a class' }
    end

    def options
      @options ||= attributes.except(:class)
    end

    def data
      @data ||= datasource.to_hash.with_indifferent_access
    end

    def datasource
      @datasource ||= Sow::Data::Source.new(table_name, options)
    end

    private

    def table_name
      @table_name ||= klass.to_s.tableize
    end
  end
end

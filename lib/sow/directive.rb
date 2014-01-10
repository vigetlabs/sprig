module Sow
  class Directive
    attr_reader :attributes

    def initialize(args)
      @attributes = begin
        case
        when args.is_a?(Hash)
          args
        when args < ActiveRecord::Base
          { :class => args }
        else
          raise ArgumentError, argument_error_message
        end
      end
    end

    def klass
      @klass ||= attributes.fetch(:class) { raise ArgumentError, argument_error_message }
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

    def argument_error_message
      'Sow::Directive must be instantiated with an '\
      'ActiveRecord subclass or a Hash with :class defined'
    end
  end
end

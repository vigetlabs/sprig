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

    def datasource
      @datasource ||= Source.new(klass.to_s.tableize, options)
    end

    private

    def argument_error_message
      'Sow::Directive must be instantiated with an '\
      'ActiveRecord subclass or a Hash with :class defined'
    end
  end
end

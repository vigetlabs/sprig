module Sprig
  class Directive
    attr_reader :attributes

    def initialize(args)
      @attributes = if args.is_a?(Hash)
        args
      elsif args.is_a?(Class) && args < Sprig.adapter_model_class
        {class: args}
      else
        raise ArgumentError, argument_error_message
      end
    end

    def klass
      @klass ||= attributes.fetch(:class) { raise ArgumentError, argument_error_message }
    end

    def options
      @options ||= attributes.except(:class)
    end

    def datasource
      @datasource ||= Source.new(table_name, options)
    end

    # Public so ReferenceScanner can resolve the same underlying file #datasource
    # will stream from, without going through Source (which hands the IO straight
    # to a parser rather than exposing it for a raw-text prescan).
    def table_name
      @table_name ||= klass.to_s.tableize.tr("/", "_")
    end

    private

    def argument_error_message
      "Sprig::Directive must be instantiated with a(n) " \
      "#{Sprig.adapter_model_class} class or a Hash with :class defined"
    end
  end
end

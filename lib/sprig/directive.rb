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
      @datasource ||= Source.new(klass.to_s.tableize.tr("/", "_"), options)
    end

    private

    def argument_error_message
      "Sprig::Directive must be instantiated with a(n) " \
      "#{Sprig.adapter_model_class} class or a Hash with :class defined"
    end
  end
end

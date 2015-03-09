module Sprig
  class Directive
    attr_reader :attributes

    def initialize(args)
      @attributes = begin
        case
        when args.is_a?(Hash)
          args
        when args.is_a?(Class) && args < orm_model
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
      @datasource ||= Source.new(klass.to_s.tableize.gsub("/", "_"), options)
    end

    private

    def argument_error_message
      'Sprig::Directive must be instantiated with a(n) '\
      "#{orm_model} class or a Hash with :class defined"
    end

    def orm_model
      case Sprig.adapter
      when :active_record
        ActiveRecord::Base
      when :mongoid
        Mongoid::Document
      end
    end
  end
end

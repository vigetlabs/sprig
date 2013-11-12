module Sow
  class Directive
    attr_reader :klass, :options

    def initialize(instructions)
      self.klass   = instructions.fetch(0)
      self.options = instructions.fetch(1) { Hash.new }
    end

    def data
      @data ||= datasource.to_hash.with_indifferent_access
    end

    def datasource
      @datasource ||= Sow::Data::Source.new(table_name, options[:data])
    end

    private

    def klass=(klass)
      raise ArgumentError, 'Must provide a Class' unless klass.is_a?(Class)

      @klass = klass
    end

    def options=(options)
      @options = options.to_hash
    end

    def table_name
      @table_name ||= klass.to_s.tableize
    end
  end
end

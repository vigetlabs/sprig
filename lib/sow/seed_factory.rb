module Sow
  class SeedFactory
    def initialize(klass, options = {})
      @klass = klass
      @datasource_class = options[:datasource_class] || Datasources::Yaml
      @seed_options = options[:seed_options] || {}
    end

    def new_seeds
      seed_definitions.map do |seed_definition|
        new_seed(seed_definition)
      end
    end

    private

    delegate :seed_definitions, :to => :datasource

    def new_seed(seed_definition)
      Seed.new(@klass, seed_definition, seed_options)
    end

    def seed_options
      datasource.seed_options.merge(@seed_options)
    end

    def datasource
      @datasource ||= @datasource_class.new(@klass)
    end
  end
end

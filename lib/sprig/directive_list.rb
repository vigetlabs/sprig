module Sprig
  class DirectiveList

    def initialize(definitions)
      @definitions = Array(definitions)
    end

    def add_seeds_to_hopper(hopper)
      seed_factories.each do |factory|
        factory.add_seeds_to_hopper(hopper)
      end
    end

    private

    attr_reader :definitions

    def directives
      @directives ||= definitions.map do |definition|
        Directive.new(definition)
      end
    end

    def seed_factories
      directives.map do |directive|
        Seed::Factory.new_from_directive(directive)
      end
    end
  end
end

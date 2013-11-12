module Sow
  class DirectiveList
    def initialize(directive_definitions)
      @directive_definitions = Array(directive_definitions)
    end

    def add_seeds_to_hopper(hopper)
      seed_factories.each do |factory|
        factory.add_seeds_to_hopper(hopper)
      end
    end

    private

    attr_reader :directive_definitions

    def directives
      @directives ||= directive_definitions.map do |definition|
        Directive.new(Array(definition))
      end
    end

    def seed_factories
      directives.map do |directive|
        Seed::Factory.new_from_directive(directive)
      end
    end
  end
end

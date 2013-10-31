module Sow
  module Datasources
    class Yaml
      def initialize(klass)
        @klass = klass
      end

      def seed_definitions
        seed_data['seeds']
      end

      def seed_options
        seed_data['options'] || {}
      end

      private

      def seed_data
        @seed_data ||= YAML.load_file(seed_data_file)
      end

      def seed_data_file
        Rails.root.join('db', 'seeds', Rails.env, "#{@klass.name.tableize}.yml")
      end
    end
  end
end

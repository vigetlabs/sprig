module Sprig
  module Harvest
    class Configuration
      VALID_CLASSES = ActiveRecord::Base.subclasses

      attr_reader :limit, :ignored_attrs

      def env
        @env ||= Rails.env
      end

      def env=(given_env)
        parse_valid_env_from given_env do |environment|
          @env = environment
        end
      end

      def classes
        @classes ||= VALID_CLASSES
      end

      def classes=(given_classes)
        parse_valid_classes_from given_classes do |classes|
          @classes = classes
        end
      end

      def limit=(given_limit)
        parse_limit_from given_limit do |limit|
          @limit = limit
        end
      end

      def ignored_attrs=(given_attrs)
        parse_ignored_attrs_from given_attrs do |attrs|
          @ignored_attrs = attrs
        end
      end

      def ignored_attrs
        @ignored_attrs ||= []
      end

      def models=(inputs)
        self.model_configurations = inputs.map { |input| create_model_config_from(input) }
      end

      def model_configurations
        @model_configurations ||= classes.map { |klass| ModelConfig.new(klass) }
      end

      private

      attr_writer :model_configurations

      def parse_valid_env_from(input)
        return if input.nil?
        environment = input.strip.downcase
        create_seeds_folder(environment)
        yield environment
      end

      def create_seeds_folder(env)
        folder = Rails.root.join('db', 'seeds', env)
        FileUtils.mkdir_p(folder) unless File.directory? folder
      end

      def parse_valid_classes_from(input)
        return if input.nil?

        classes = if input.is_a? String
          input.split(',').map { |klass_string| klass_string.strip.classify.constantize }
        else
          input
        end

        yield classes
      end

      def parse_limit_from(input)
        return if input.nil?

        int = input.to_i

        unless int > 0
          raise ArgumentError, "Limit can only be set to an integer above 0 (received #{int})"
        end

        yield int
      end

      def parse_ignored_attrs_from(input)
        return if input.nil?

        attrs = if input.is_a? String
          input.split(',').map(&:strip)
        else
          input.map(&:to_s).map(&:strip)
        end

        yield attrs
      end

      def create_model_config_from(input)
        if input.is_a? Hash
          klass = input.delete(:class)
          ModelConfig.new(klass, input)
        elsif input.is_a? Class
          ModelConfig.new(input)
        else
          raise ArgumentError,
            "Sprig::Harvest.configure expects `models=` to be given an array containing classes and/or hashes (received #{input.class})"
        end
      end
    end
  end
end

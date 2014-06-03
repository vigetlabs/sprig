module Sprig
  module Harvest
    class Configuration
      VALID_CLASSES = ActiveRecord::Base.subclasses

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

      private

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

        validate_classes(classes)

        yield classes
      end

      def validate_classes(classes)
        classes.each do |klass|
          unless VALID_CLASSES.include? klass
            raise ArgumentError, "Cannot create a seed file for #{klass} because it is not a subclass of ActiveRecord::Base."
          end
        end
      end
    end
  end
end

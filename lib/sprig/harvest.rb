module Sprig
  module Harvest
    autoload :Model,    'sprig/harvest/model'
    autoload :Record,   'sprig/harvest/record'
    autoload :SeedFile, 'sprig/harvest/seed_file'

    class << self
      def reap(options = {})
        configure do |config|
          config.env     = options[:env] unless options[:env].nil?
          config.classes = options[:classes] unless options[:classes].nil?
        end

        Model.all.each { |model| SeedFile.new(model).write }
      end

      private

      cattr_reader :configuration

      delegate :env, :classes, to: :configuration

      def configuration
        @@configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end
    end

    private

    class Configuration
      VALID_CLASSES = ActiveRecord::Base.descendants

      def env
        @env ||= Rails.env
      end

      def env=(environment)
        seeds_folder = Rails.root.join('db', 'seeds', environment)

        FileUtils.mkdir_p(seeds_folder) unless File.directory? seeds_folder

        @env = environment
      end

      def classes
        @classes ||= VALID_CLASSES
      end

      def classes=(classes)
        classes.each do |klass|
          unless VALID_CLASSES.include? klass
            raise ArgumentError, "Cannot create a seed file for #{klass} because it is not an ActiveRecord::Base-descendant."
          end
        end

        @classes = classes
      end
    end
  end
end

module Sprig
  module Harvest
    autoload :Configuration, 'sprig/harvest/configuration'
    autoload :ModelConfig,   'sprig/harvest/model_config'
    autoload :Model,         'sprig/harvest/model'
    autoload :Record,        'sprig/harvest/record'
    autoload :SeedFile,      'sprig/harvest/seed_file'

    class << self
      def reap(options = {})
        file_path = options[:file] || options['FILE']

        if file_path && File.exists?(file_path)
          load(file_path)
        else
          configure do |config|
            config.env           = options[:env]           || options['ENV']
            config.classes       = options[:models]        || options['MODELS']
            config.limit         = options[:limit]         || options['LIMIT']
            config.ignored_attrs = options[:ignored_attrs] || options['IGNORED_ATTRS']
          end
        end

        Model.all.each { |model| SeedFile.new(model).write }
      end

      def configure
        yield configuration
      end

      private

      cattr_reader :configuration

      delegate :env,
               :classes,
               :limit,
               :ignored_attrs,
               :model_configurations,
               :to => :configuration

      def configuration
        @@configuration ||= Configuration.new
      end
    end
  end
end

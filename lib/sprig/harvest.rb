module Sprig
  module Harvest
    autoload :Configuration, 'sprig/harvest/configuration'
    autoload :Model,         'sprig/harvest/model'
    autoload :Record,        'sprig/harvest/record'
    autoload :SeedFile,      'sprig/harvest/seed_file'

    class << self
      def reap(options = {})
        configure do |config|
          config.env     = options[:env]    || options['ENV']
          config.classes = options[:models] || options['MODELS']
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
  end
end

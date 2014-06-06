module Sprig
  module Harvest
    class Model
      def self.all
        @@all ||= begin
          models = Sprig::Harvest.model_configurations.map { |config| new(config) }
          
          tsorted_classes(models).map do |klass|
            models.find { |model| model.klass == klass }
          end
        end
      end

      def self.find(klass, id)
        all.find { |model| model.klass == klass }.find(id)
      end

      attr_reader :config
      attr_writer :existing_sprig_ids

      delegate :klass,
               :attributes,
               :dependencies,
               :collection,
               :limit,
               :ignored_attrs,
               :to => :config


      def initialize(config)
        unless config.is_a? ModelConfig
          raise ArgumentError, "Must be instantiated with a Sprig::Harvest::ModelConfig (received #{config.class} instead)"
        end

        @config = config
      end

      def existing_sprig_ids
        @existing_sprig_ids ||= []
      end

      def generate_sprig_id
        existing_sprig_ids.select { |i| i.is_a? Integer }.sort.last + 1
      end

      def find(id)
        records.find { |record| record.id == id }
      end

      def to_s
        klass.to_s
      end

      def to_yaml(options = {})
        namespace         = options[:namespace]
        formatted_records = records.map(&:to_hash)

        yaml = if namespace
          { namespace => formatted_records }.to_yaml
        else
          formatted_records.to_yaml
        end

        yaml.gsub("---\n", '') # Remove annoying YAML separator
      end

      def records
        @records ||= begin
          record_set = limit ? collection.slice(0...limit) : collection

          record_set.map { |record| Record.new(record, self) }
        end
      end

      private

      def self.tsorted_classes(models)
        models.reduce(TsortableHash.new) do |hash, model|
          hash.merge(model.klass => model.dependencies)
        end.tsort
      end
    end
  end
end

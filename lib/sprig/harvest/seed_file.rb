module Sprig
  module Harvest
    class SeedFile
      DEFAULT_NAMESPACE = 'records'

      attr_reader :model

      def initialize(model)
        raise ArgumentError, 'Must initialize with a Sprig::Harvest::Model' unless model.is_a? Model

        @model = model
      end

      def path
        Rails.root.join('db', 'seeds', Sprig::Harvest.env, "#{model.to_s.tableize}.yml")
      end

      def exists?
        File.exists?(path)
      end

      def write
        initialize_file do |file, namespace|
          file.write model.to_yaml(:namespace => namespace)
        end
      end

      private

      def initialize_file
        existing_file = exists?
        access_type = existing_file ? 'a+' : 'w'

        File.open(path, access_type) do |file|
          namespace = DEFAULT_NAMESPACE

          if existing_file
            model.existing_sprig_ids = existing_sprig_ids(file.read)
            namespace = nil
            file.write("\n")
          end

          yield file, namespace
        end
      end

      def existing_sprig_ids(yaml)
        YAML.load(yaml).fetch(DEFAULT_NAMESPACE).to_a.map do |record|
          record.fetch('sprig_id')
        end
      end
    end
  end
end

module Sprig
  module Harvest
    class Model
      def self.all
        @@all ||= begin
          models = ActiveRecord::Base.descendants.map { |klass| new(klass) }
          
          models.reduce(TsortableHash.new) do |hash, model|
            hash.merge(model.klass => model.dependencies)
          end.tsort.map do |klass| 
            models.find { |model| model.klass == klass }
          end
        end
      end

      def self.find(klass, id)
        all.find { |model| model.klass == klass }.find(id)
      end

      attr_reader :klass
      attr_writer :existing_sprig_ids

      def initialize(klass)
        @klass = klass
      end

      def attributes
        klass.column_names
      end

      def dependencies
        @dependencies ||= klass.reflect_on_all_associations(:belongs_to).map do |association|
          association.name.to_s.classify.constantize
        end
      end

      def existing_sprig_ids
        @existing_sprig_ids ||= []
      end

      def generate_sprig_id
        existing_sprig_ids.sort.last + 1
        
        # TODO Handle non-integer sprig_ids
      end

      def find(id)
        records.find { |record| record.id == id }
      end

      def to_s
        klass.to_s
      end

      def to_yaml(namespace: nil)
        formatted_records = records.map(&:to_hash)

        yaml = if namespace
          { namespace => formatted_records }.to_yaml
        else
          formatted_records.to_yaml
        end

        yaml.gsub("---\n", '') # Remove annoying YAML separator
      end

      def records
        @records ||= klass.all.map { |record| Record.new(record, self) }
      end

      private

      # TODO Extract TsortableHash (also exists in the DependencySorter)

      class TsortableHash < Hash
        include TSort

        alias tsort_each_node each_key

        def tsort_each_child(node, &block)
          fetch(node).each(&block)
        end
      end
    end
  end
end

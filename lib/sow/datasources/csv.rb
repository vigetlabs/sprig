require 'csv'

module Sow
  module Datasources
    class Csv
      def initialize(klass)
        @klass = klass
      end

      def seed_definitions
        @seed_definitions ||= seeds_from_csv
      end

      def seed_options
        {}
      end

      private

      def seeds_from_csv
        [].tap do |seed_definitions|
          ::CSV.foreach(File.open(seed_data_file), :headers => true) do |row|
            seed_definitions << Row.new(row).to_h
          end
        end
      end

      def seed_data_file
        Rails.root.join('db', 'seeds', Rails.env, "#{@klass.name.tableize}.csv")
      end

      class Row
        attr_reader :row

        def initialize(row)
          @row = row
        end

        def to_h
          {
            'seed_id' => seed_id,
            'attributes' => Hash[*attribute_array]
          }
        end

        private

        def seed_id
         row[0].to_i
        end

        def attribute_array
          row.to_a.drop(1).flatten
        end
      end
    end
  end
end

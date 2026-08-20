# Serializes the row arrays from row_data.rb into the three source formats this
# matrix benchmark compares. Each writer takes the same generic input (a plain Hash
# of {"records" => [...], "options" => {}} -- options always empty here, since this
# dataset never uses find_existing_by) and produces a file Sprig's own parsers can
# read unmodified, so the exact same generated data is what every format actually
# tests, not three independently-assembled approximations of it.
require "csv"
require "json"
require "yaml"

module Sprig
  module BenchmarkMatrix
    module Writers
      def self.write(path, records)
        case File.extname(path)
        when ".yml", ".yaml"
          write_yaml(path, records)
        when ".json"
          write_json(path, records)
        when ".csv"
          write_csv(path, records)
        else
          raise "Unsupported extension for #{path}"
        end
      end

      def self.write_yaml(path, records)
        File.write(path, YAML.dump("records" => records))
      end

      def self.write_json(path, records)
        File.write(path, JSON.generate("records" => records))
      end

      # CSV has no nested structure, so every row needs the same column set -- the
      # union of every key across all rows (e.g. Project rows only sometimes have
      # customer_id). A row missing a given column is written as an empty field,
      # which Sprig::Parser::Csv (via CSV.foreach) reads back as nil, matching the
      # same "no customer" case the YAML/JSON versions represent by omitting the key.
      def self.write_csv(path, records)
        headers = records.flat_map(&:keys).uniq
        CSV.open(path, "w") do |csv|
          csv << headers
          records.each do |record|
            csv << headers.map { |h| record[h] }
          end
        end
      end
    end
  end
end

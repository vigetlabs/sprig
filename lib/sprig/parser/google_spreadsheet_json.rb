module Sprig
  module Parser
    class GoogleSpreadsheetJson < Base

      def parse
        { :records => records }
      end

      private

      def records
        @records ||= raw_records.map { |record| build_record(record) }
      end

      def build_record(record)
        hash = {}

        record.keys.each do |key|
          attr_name = key.tr('-', '_').scan(/gsx\$([a-z_]+$)/).flatten.first
          hash[attr_name] = record[key]['$t'] if attr_name
        end

        hash
      end

      def raw_records
        json['feed']['entry']
      end

      def json
        @json ||= JSON.load(data_io)
      end
    end
  end
end

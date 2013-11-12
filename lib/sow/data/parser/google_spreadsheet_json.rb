module Sow
  module Data
    module Parser
      class GoogleSpreadsheetJson < Base
        def parse
          { :records => records }
        end

        private

        def json
          @json ||= JSON.load(data_io)
        end

        def raw_records
          json['feed']['entry']
        end

        def records
          raw_records.map do |record|
            {}.tap do |new_record|
              record.keys.each do |key|

                attribute_name = key.gsub('-', '_').scan(/gsx\$([a-z_]+$)/).flatten.first

                if attribute_name
                  new_record[attribute_name] = record[key]['$t']
                end
              end
            end
          end
        end
      end
    end
  end
end

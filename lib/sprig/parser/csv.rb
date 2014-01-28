require 'csv'

module Sprig
  module Parser
    class Csv < Base

      def parse
        { :records => records }
      end

      private

      def records
        [].tap do |records|
          CSV.foreach(data_io, headers: :first_row, skip_blanks: true) do |row|
            records << row.to_hash
          end
        end
      end
    end
  end
end

require "csv"

module Sprig
  module Parser
    class Csv < Base
      # Stream directly off data_io via CSV.foreach -- no buffering of the
      # file into memory at all.
      def parse
        {records: Enumerator.new { |yielder| stream_records { |row| yielder << row } }}
      end

      private

      def stream_records(&block)
        CSV.foreach(data_io, headers: :first_row, skip_blanks: true) do |row|
          block.call(row.to_hash)
        end
      end
    end
  end
end

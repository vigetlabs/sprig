require "csv"

module Sprig
  module Parser
    class Csv < Base
      # CSV has no options:/records: sibling-key structure to worry about, and
      # Source#data no longer closes data_io until this enumerator is exhausted, so
      # this can stream directly off data_io via CSV.foreach -- no buffering of the
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

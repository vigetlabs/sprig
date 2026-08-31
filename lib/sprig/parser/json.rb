require "oj"

module Sprig
  module Parser
    class Json < Base
      RECORDS_KEY = "records"
      OPTIONS_KEY = "options"

      # See Sprig::Parser::Yml#parse for the reasoning: two passes are required
      # (options captured eagerly, records streamed lazily) regardless of key order in
      # the file, and both read directly from data_io when it's rewindable so peak
      # memory never scales with file size -- falling back to a one-time buffered read
      # only for non-rewindable custom sources.
      def parse
        input = rewindable? ? data_io : data_io.read

        {
          options: capture_options(input) || {},
          records: Enumerator.new { |yielder| stream_records(input) { |row| yielder << row } }
        }
      end

      private

      def rewindable?
        data_io.rewind
        true
      rescue IOError, Errno::ESPIPE, NotImplementedError
        false
      end

      def capture_options(input)
        handler = EventHandler.new(capture_key: OPTIONS_KEY)
        Oj.sc_parse(handler, input)
        data_io.rewind if input.equal?(data_io)
        handler.capture_value
      end

      def stream_records(input, &block)
        handler = EventHandler.new(stream_key: RECORDS_KEY, &block)
        Oj.sc_parse(handler, input)
      end
    end
  end
end

require_relative "json/event_handler"

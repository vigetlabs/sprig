module Sprig
  module Parser
    class Base
      attr_reader :data_io

      def initialize(data_io)
        @data_io = data_io
      end

      def parse
        raise NotImplementedError, "Parsers must implement #parse"
      end

      # Like #parse, but for callers (namely ReferenceScanner's prescan) that only
      # ever need records: and never look at options: at all. The default here just
      # falls back to #parse and discards options:, so it costs nothing extra for
      # any parser that doesn't override it (Csv, or a custom :parser:) -- but Yml
      # and Json override it to skip their options-capturing pass entirely, since
      # that pass is pure waste when nothing will ever read its result.
      def parse_records_only
        Source.normalize_parsed(parse)[:records]
      end

      # True if io can be rewound back to its start -- verified by actually
      # calling #rewind, not merely checking #respond_to?, which a custom
      # :source: can satisfy while still raising when #rewind is actually
      # called (a non-seekable stream, most commonly).
      def self.rewindable?(io)
        return false unless io.respond_to?(:rewind)

        io.rewind
        true
      rescue StandardError, NotImplementedError
        # A custom :source: can raise anything from its own #rewind; StandardError
        # covers that plus the built-in cases (IOError on a closed stream,
        # Errno::ESPIPE on a pipe). NotImplementedError is listed separately
        # because it's a ScriptError, not a StandardError, so it isn't covered
        # by the first class alone.
        false
      end
    end
  end
end

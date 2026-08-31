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

      # True if io can be rewound back to its start -- verified by actually
      # calling #rewind, not merely checking #respond_to?, which a custom
      # :source: can satisfy while still raising when #rewind is actually
      # called (a non-seekable stream, most commonly).
      def self.rewindable?(io)
        return false unless io.respond_to?(:rewind)

        io.rewind
        true
      rescue IOError, Errno::ESPIPE, NotImplementedError
        false
      end
    end
  end
end

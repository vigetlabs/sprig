module Sprig
  module Parser
    class Base
      attr_reader :data_io

      def initialize(data_io)
        @data_io = data_io
      end

      def parse
        raise NotImplementedError, 'Parsers must implement #parse'
      end
    end
  end
end

module Sprig
  module Parser
    class Json < Base
      def parse
        JSON.load(data_io)
      end
    end
  end
end

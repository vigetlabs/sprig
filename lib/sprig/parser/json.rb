module Sprig
  module Parser
    class Json < Base
      def parse
        JSON.load(data_io) # rubocop:disable Security/JSONLoad
      end
    end
  end
end

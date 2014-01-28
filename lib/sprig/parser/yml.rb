module Sprig
  module Parser
    class Yml < Base
      def parse
        YAML.load(data_io)
      end
    end
  end
end

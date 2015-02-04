module Sprig
  module Parser
    class Fixtures < Base
      def parse
        {
          records: YAML.load(data_io).map{ |k,v| v.merge({sprig_id: k}) }
        }
      end
    end
  end
end

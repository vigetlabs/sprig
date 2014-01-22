require 'sow/data/parser/base'

module Sow
  module Data
    module Parser
      class Yml < Base
        def parse
          YAML.load(data_io)
        end
      end
    end
  end
end

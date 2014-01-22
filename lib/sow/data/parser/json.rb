require 'sow/data/parser/base'

module Sow
  module Data
    module Parser
      class Json < Base
        def parse
          JSON.load(data_io)
        end
      end
    end
  end
end

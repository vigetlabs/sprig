module Sow
  module Data
    module Parser
      autoload :Base, 'sow/data/parser/base'
      autoload :Csv, 'sow/data/parser/csv'
      autoload :GoogleSpreadsheetJson, 'sow/data/parser/google_spreadsheet_json'
      autoload :Json, 'sow/data/parser/json'
      autoload :Yml, 'sow/data/parser/yml'
    end
  end
end

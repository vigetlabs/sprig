module Sow
  module Parser
    autoload :Base,                  'sow/parser/base'
    autoload :Csv,                   'sow/parser/csv'
    autoload :Json,                  'sow/parser/json'
    autoload :Yml,                   'sow/parser/yml'
    autoload :GoogleSpreadsheetJson, 'sow/parser/google_spreadsheet_json'
  end
end

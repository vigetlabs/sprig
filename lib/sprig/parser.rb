module Sprig
  module Parser
    autoload :Base,                  'sprig/parser/base'
    autoload :Csv,                   'sprig/parser/csv'
    autoload :Json,                  'sprig/parser/json'
    autoload :Yml,                   'sprig/parser/yml'
    autoload :GoogleSpreadsheetJson, 'sprig/parser/google_spreadsheet_json'
  end
end

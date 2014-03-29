module Sprig
  class NullRecord
    include Logging

    def initialize(error)
      log_error "#{error} (Substituted with NullRecord)"
    end

    def method_missing(*)
      nil
    end
  end
end

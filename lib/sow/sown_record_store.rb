module Sow
  class SownRecordStore
    include Singleton

    class RecordNotFoundError < StandardError;end

    def save(record, sow_id)
      records_of_klass(record.class)[sow_id.to_s] = record
    end

    def get(klass, sow_id)
      records_of_klass(klass)[sow_id.to_s] || record_not_found
    end

    private

    def records_of_klass(klass)
      records[klass.name.tableize] ||= {}
    end

    def records
      @records ||= {}
    end

    def record_not_found
      raise(RecordNotFoundError, "Record for class #{klass} and sow_id #{sow_id} could not be found.")
    end
  end
end

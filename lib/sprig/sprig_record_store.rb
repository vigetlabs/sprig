require 'singleton'

module Sprig
  class SprigRecordStore
    include Singleton

    class RecordNotFoundError < StandardError;end

    def save(record, sprig_id)
      records_of_klass(record.class)[sprig_id.to_s] = record

      return unless record.class.column_names.include? record.class.inheritance_column

      begin
        sti_base_class = record.class.table_name.classify.constantize
        records_of_klass(sti_base_class)[sprig_id.to_s] = record
      rescue NameError
      end
    end

    def get(klass, sprig_id)
      records_of_klass(klass)[sprig_id.to_s] || record_not_found(klass, sprig_id)
    end

    private

    def records_of_klass(klass)
      records[klass.name.tableize] ||= {}
    end

    def records
      @records ||= {}
    end

    def record_not_found(klass, sprig_id)
      raise(RecordNotFoundError, "Record for class #{klass} and sprig_id #{sprig_id} could not be found.")
    end
  end
end

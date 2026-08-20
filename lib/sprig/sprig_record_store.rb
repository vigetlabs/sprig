require "singleton"

module Sprig
  class SprigRecordStore
    # Use a single, global store to avoid having to pass references everywhere;
    # NOTE: This has the side effect of potentially allowing the store to persist
    # between runs within the same session (e.g. during testing); it must be reset
    # between runs to ensure stale data doesn't leak.
    include Singleton

    class RecordNotFoundError < StandardError; end

    # sprig_id is a seed-file-only identifier, never saved to the database, so 
    # we need to track the mapping between sprig_id and the record's actual id.
    def save(record, sprig_id)
      records_of_klass(record.class)[sprig_id.to_s] = record.id
    end

    # Since the majority of get calls will be for the id, we return a LazyRecord that
    # answers id directly without a database call (any other attributes still work but
    # will trigger a database fetch).
    def get(klass, sprig_id)
      id = records_of_klass(klass)[sprig_id.to_s] || record_not_found(klass, sprig_id)
      LazyRecord.new(klass, id)
    end

    def reset
      @records = {}
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

require_relative "sprig_record_store/lazy_record"

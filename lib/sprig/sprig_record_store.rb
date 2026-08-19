require "singleton"

module Sprig
  class SprigRecordStore
    # Use a single, global store to avoid having to pass references everywhere;
    # NOTE: This has the side effect of potentially allowing the store to persist
    # between runs within the same session (e.g. during testing); it must be reset
    # between runs to ensure stale data doesn't leak.
    include Singleton

    class RecordNotFoundError < StandardError; end

    # sprig_id is a seed-file-only identifier -- Entry#initialize deletes it from a
    # record's attributes before it's ever saved, so it never becomes a real column,
    # and there's no way to look a record back up by sprig_id via the database
    # directly. What's kept here is only enough to bridge that gap: the record's
    # real primary key. The record itself is never held in memory for the whole
    # run -- a live ActiveRecord/Mongoid instance is far larger than the row it
    # represents (every column becomes its own type-cast/dirty-tracking wrapper
    # object).
    def save(record, sprig_id)
      records_of_klass(record.class)[sprig_id.to_s] = record.id
    end

    # Returns a LazyRecord, not a fetched record -- #get itself never queries the
    # database. sprig_record(Klass, id) is overwhelmingly used just to read the id
    # back off (setting a foreign key), and the id is already sitting right here;
    # LazyRecord answers that directly, and only falls through to a real
    # klass.find(id) if something beyond the id is actually asked of it.
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

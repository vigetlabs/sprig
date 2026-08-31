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
    #
    # When pruning is enabled (see #preload_referenced_ids), a sprig_id nothing
    # else's sprig_record(...) will ever ask for has no key here at all -- the
    # record is still planted and saved to the database normally, this store just
    # never holds onto it. A key that *was* preloaded (nil, until this overwrites
    # it) is what makes a sprig_id "needed" -- there's no separate structure
    # tracking that, so nothing is ever stored twice.
    def save(record, sprig_id)
      sprig_id = sprig_id.to_s
      klass_records = records_of_klass(record.class)
      return if pruning? && !klass_records.key?(sprig_id)

      klass_records[sprig_id] = record.id
    end

    # Since the majority of get calls will be for the id, we return a LazyRecord that
    # answers id directly without a database call (any other attributes still work but
    # will trigger a database fetch).
    def get(klass, sprig_id)
      id = records_of_klass(klass)[sprig_id.to_s] || record_not_found(klass, sprig_id)
      LazyRecord.new(klass, id)
    end

    # Opts this run into pruning: pre-registers every referenced id (a
    # Dependency#klass_and_sprig_id string, e.g. "Post 1") gathered by ReferenceScanner
    # scanning every source file for sprig_record(...) calls before planting starts,
    # each as a key with a nil placeholder value. #save then only overwrites a key
    # that's already present -- anything not preloaded here never gets a key at
    # all, so it costs nothing beyond the instant it's looked at. Not calling this
    # (the default) keeps every planted record's id, as before.
    def preload_referenced_ids(klass_and_sprig_ids)
      @pruning = true
      klass_and_sprig_ids.each do |klass_and_sprig_id|
        klass_name, sprig_id = Dependency.split(klass_and_sprig_id)
        (records[klass_name.tableize] ||= {})[sprig_id] = nil
      end
    end

    def reset
      @records = {}
      @pruning = false
    end

    private

    def pruning?
      @pruning
    end

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

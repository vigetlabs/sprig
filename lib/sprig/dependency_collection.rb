require "singleton"

module Sprig
  class DependencyCollection
    # Use a single, global store to avoid having to pass references everywhere;
    # NOTE: This has the side effect of potentially allowing the store to persist
    # between runs within the same session (e.g. during testing); it must be reset
    # between runs to ensure stale data doesn't leak.
    include Singleton

    def get(klass, id)
      records_for_klass(klass)[id]
    end

    def set(klass, id, value)
      records_for_klass(klass)[id] = value
    end

    def reset
      @records = {}
    end

    private

    def records
      @records ||= {}
    end

    def records_for_klass(klass)
      records[klass] ||= {}
    end
  end
end

require "singleton"
require "tmpdir"
require "fileutils"

module Sprig
  class RawRowStore
    # Use a single, global store to avoid having to pass references everywhere;
    # NOTE: This has the side effect of potentially allowing the store to persist
    # between runs within the same session (e.g. during testing); it must be reset
    # between runs to ensure stale data doesn't leak.
    include Singleton

    class RecordNotFoundError < StandardError; end

    # Cleans up any previous run's temp store and starts a fresh one. Only
    # actually allocates a temp file when enabled -- callers are
    # expected to gate calls to #reset/#put/#fetch/#cleanup on
    # Sprig.configuration.spill_seed_rows_to_disk themselves.
    def reset
      cleanup
      @dir = Dir.mktmpdir("sprig-seed-rows")
      @log = File.open(File.join(@dir, "rows.log"), "wb")
      @index = {}
    end

    # The real, user-facing duplicate-sprig_id check is Planter's (raised before a
    # descriptor is ever offered a second time, well before #spill_to_disk! could be
    # called for the same id) -- this is only a last-resort internal assertion in
    # case that guarantee is ever broken elsewhere, not a second copy of it.
    def put(id, raw_hash)
      raise "A row is already spilled to disk for id #{id} -- Planter should have rejected this duplicate sprig_id before ever spilling it twice." if @index.key?(id)

      dumped = Marshal.dump(raw_hash)
      @index[id] = @log.pos
      @log.write([dumped.bytesize].pack("N"))
      @log.write(dumped)
      @log.flush
    end

    # A row is only ever fetched once (right before the descriptor that spilled it is
    # planted -- see Descriptor#spill_to_disk!), so its index entry is removed here:
    # this keeps @index down to the size of what's *currently* waiting rather than
    # growing for the whole run, and turns an accidental second fetch of the same id
    # into a clear RecordNotFoundError instead of silently succeeding.
    def fetch(id)
      offset = @index.fetch(id) { record_not_found(id) }
      read_log.seek(offset)
      size = read_log.read(4).unpack1("N")
      data = Marshal.load(read_log.read(size))
      @index.delete(id)
      data
    end

    def cleanup
      return unless @dir

      @log&.close
      @read_log&.close
      FileUtils.remove_entry(@dir) if Dir.exist?(@dir)
      @dir = nil
      @log = nil
      @read_log = nil
      @index = nil
    end

    private

    # Opened once and reused (seeking per #fetch) rather than opening/closing a
    # fresh handle on every call -- a row is only ever fetched once, but a run
    # with many spilled rows still means many fetches in total.
    def read_log
      @read_log ||= File.open(@log.path, "rb")
    end

    def record_not_found(id)
      raise RecordNotFoundError, "No raw row spilled to disk for id #{id}."
    end
  end
end

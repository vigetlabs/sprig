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
    # actually allocates a temp file when Option C is enabled -- callers are
    # expected to gate calls to #reset/#put/#fetch/#cleanup on
    # Sprig.configuration.spill_seed_rows_to_disk themselves.
    def reset
      cleanup
      @dir = Dir.mktmpdir("sprig-seed-rows")
      @log = File.open(File.join(@dir, "rows.log"), "wb")
      @index = {}
    end

    def put(id, raw_hash)
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
      data = File.open(@log.path, "rb") do |f|
        f.seek(offset)
        size = f.read(4).unpack1("N")
        Marshal.load(f.read(size))
      end
      @index.delete(id)
      data
    end

    def cleanup
      return unless @dir

      @log&.close
      FileUtils.remove_entry(@dir) if Dir.exist?(@dir)
      @dir = nil
      @log = nil
      @index = nil
    end

    private

    def record_not_found(id)
      raise RecordNotFoundError, "No raw row spilled to disk for id #{id}."
    end
  end
end

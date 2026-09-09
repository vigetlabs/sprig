module Sprig
  # A prescan that finds every `sprig_record(Klass, id)` reference across every
  # directive's source file *before* planting starts, so SprigRecordStore can tell
  # which planted records will actually be looked back up later and which never
  # will be (see SprigRecordStore#preload_referenced_ids).
  #
  # This works on all three source formats (YAML/JSON/CSV) with the same code
  # because it never actually parses them -- it streams each file's raw bytes and
  # regex-matches the literal `sprig_record(...)` text, the same way a value's
  # dependencies are found in Seed::Attribute/Seed::Descriptor, just applied to
  # a whole file instead of one already-parsed field at a time. That also means it
  # can (harmlessly) match text that isn't really inside a `<%= ... %>` tag -- e.g.
  # inside an unrelated comment -- which only makes the result a superset of what's
  # truly referenced. A superset is safe here (it just means a few extra ids get
  # kept that didn't strictly need to be); underestimating would not be, since a
  # missed reference would make a later, legitimate `sprig_record(...)` lookup
  # raise SprigRecordStore::RecordNotFoundError. See #scan for what makes the
  # result unusable rather than merely imprecise.
  class ReferenceScanner
    # Read in fixed-size chunks so peak memory is bounded by this, not file size.
    CHUNK_SIZE = 1 << 16

    # Carried over from the end of one chunk to the start of the next so a
    # `sprig_record(Klass, id)` reference split across a chunk boundary is still
    # matched whole. Generous relative to any realistic klass name + id literal.
    OVERLAP = 512

    def self.scan(directive_definitions)
      new(directive_definitions).scan
    end

    def initialize(directive_definitions)
      @directives = Array(directive_definitions).map { |definition| Directive.new(definition) }
    end

    # Returns a Set of Dependency#id strings ("Klass sprig_id") referenced
    # anywhere across every directive being seeded this run, or nil if any
    # directive's source couldn't be safely read twice -- a custom, non-rewindable
    # `:source:` IO, most commonly -- in which case pruning must be skipped
    # entirely rather than risk discarding an id something still needs.
    def scan
      needed = Set.new

      @directives.each do |directive|
        return nil unless scan_directive(directive, needed)
      end

      needed
    end

    private

    def scan_directive(directive, needed)
      if directive.options.key?(:source)
        scan_custom_source(directive.options[:source], needed)
      else
        scan_default_file(directive, needed)
      end
    end

    # The common case: no custom :source: was given, so this is our own File
    # handle, independent of whatever #datasource opens later to actually parse
    # the file -- nothing to rewind or otherwise put back the way we found it.
    def scan_default_file(directive, needed)
      file = Source::SourceDeterminer.new(directive.table_name).file
      scan_io(file, needed)
      true
    ensure
      file&.close
    end

    # A custom :source: IO is the exact object the real parser will read from
    # later -- it can only be prescanned without disturbing that if it supports
    # #rewind (true of File/StringIO, the realistic cases; a one-shot stream does
    # not). When it doesn't, bail out for the whole run rather than guess.
    def scan_custom_source(source, needed)
      return false unless source.respond_to?(:rewind)

      scan_io(source, needed)
      true
    ensure
      source.rewind if source.respond_to?(:rewind)
    end

    def scan_io(io, needed)
      tail = ""

      while (chunk = io.read(CHUNK_SIZE))
        text = tail + chunk
        extract_references(text, needed)
        tail = text[-OVERLAP..] || text
      end
    end

    def extract_references(text, needed)
      text.scan(Seed::Attribute::SPRIG_RECORD_REFERENCE) do |klass_name, id_text|
        id = id_from(id_text)
        needed << Dependency.for(klass_name, id).id if id
      rescue NameError, ArgumentError
        # klass_name doesn't resolve to a real class -- not a genuine
        # sprig_record(...) reference, just matching text. Skip it rather than
        # fail the whole prescan over a false positive.
      end
    end

    def id_from(id_text)
      single_quoted, double_quoted, symbol, numeric = Seed::Attribute::ID_LITERAL.match(id_text)&.captures
      single_quoted || double_quoted || symbol || numeric
    end
  end
end

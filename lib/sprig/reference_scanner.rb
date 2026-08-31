module Sprig
  # A prescan that finds every `sprig_record(Klass, id)` reference across every
  # directive's source file *before* planting starts, so SprigRecordStore can tell
  # which planted records will actually be looked back up later and which never
  # will be (see SprigRecordStore#preload_referenced_ids).
  #
  # Runs each directive's own real parser (the same streaming Yml/Json/Csv
  # parsers the actual planting pass uses) and the same Seed::Descriptor
  # dependency-scanning logic, rather than regex-matching raw file bytes --
  # a reference is recognized correctly regardless of the source format's own
  # string-escaping or character encoding, because it's decoded exactly once,
  # the same way, whether this prescan or the real pass is doing the decoding.
  # A missed reference would make a later, legitimate `sprig_record(...)` lookup
  # raise SprigRecordStore::RecordNotFoundError, so see #scan for what makes the
  # result unusable (and pruning skipped for the whole run) rather than risking that.
  class ReferenceScanner
    def self.scan(directive_definitions)
      new(directive_definitions).scan
    end

    def initialize(directive_definitions)
      @directives = Array(directive_definitions).map { |definition| Directive.new(definition) }
    end

    # Returns a Set of Dependency#klass_and_sprig_id strings ("Klass sprig_id") referenced
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
        scan_custom_source(directive, needed)
      else
        scan_default_file(directive, needed)
      end
    end

    # The common case: no custom :source: was given, so this is our own File
    # handle, independent of whatever #datasource opens later to actually parse
    # the file -- nothing to rewind or otherwise put back the way we found it.
    def scan_default_file(directive, needed)
      file = Source::SourceDeterminer.new(directive.table_name).file
      parser_class = Source.parser_class_for(file, directive.options)
      collect_dependencies(directive, parser_class, file, needed)
      true
    ensure
      file&.close
    end

    # A custom :source: IO is the exact object the real parser will read from
    # later, so it can only be prescanned without disturbing that if it truly
    # supports being rewound back to the start afterward. Verified by actually
    # rewinding *before* reading anything -- not merely checking #respond_to?,
    # which a source can satisfy while still raising when #rewind is actually
    # called (a non-seekable stream, most commonly). Checking only after
    # already having read from it would be too late to fall back safely.
    def scan_custom_source(directive, needed)
      source = directive.options[:source]
      return false unless Parser::Base.rewindable?(source)

      begin
        parser_class = Source.parser_class_for(source, directive.options)
        collect_dependencies(directive, parser_class, source, needed)
        true
      ensure
        # The probe above already proved #rewind works on this source, so this
        # shouldn't itself raise -- but an ensure block is the wrong place to
        # risk masking the method's real return value (or a pending exception
        # from the begin body) with a new one, so guard it defensively anyway.
        source.rewind rescue nil # rubocop:disable Style/RescueModifier
      end
    end

    # Prefers #parse_records_only over #parse -- this prescan never looks at
    # options: at all, so for Yml/Json there's no reason to pay for the
    # options-capturing pass here too (see Parser::Base#parse_records_only).
    # Falls back to plain #parse for a custom :parser: that doesn't define it
    # (only #parse is a documented requirement for those -- see README).
    def collect_dependencies(directive, parser_class, io, needed)
      parser = parser_class.new(io)
      records = if parser.respond_to?(:parse_records_only)
        parser.parse_records_only
      else
        Source.normalize_parsed(parser.parse)[:records]
      end || []

      records.each do |raw_attrs|
        descriptor = Seed::Descriptor.new(directive.klass, raw_attrs, directive.options)
        descriptor.dependencies.each { |dependency| needed << dependency.klass_and_sprig_id }
      end
    end
  end
end

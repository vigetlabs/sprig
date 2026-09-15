require "psych"

module Sprig
  module Parser
    class Yml < Base
      RECORDS_KEY = "records"
      OPTIONS_KEY = "options"

      # `options:` and `records:` are sibling keys that can appear in either order, and
      # Factory needs options fully resolved before it processes the first record -- so
      # this always takes two full passes: one that fully captures `options:` (small, so
      # cheap to build eagerly), and one -- deferred until the returned Enumerator is
      # actually iterated -- that streams `records:` one row at a time, never building
      # the full array.
      #
      # When data_io is rewindable (a real file, StringIO, anything seekable -- the
      # common case), both passes read directly from it, so peak memory never scales
      # with file size, only with one row at a time. Source#data only closes data_io
      # once the records enumerator is exhausted, so it's safe for this second pass to
      # stay deferred. When data_io can't be rewound (e.g. a one-shot custom :source
      # like a pipe or network stream), this falls back to reading the whole file into
      # a string once and running both passes against that instead.
      def parse
        input = Base.rewindable?(data_io) ? data_io : data_io.read

        # One visitor shared between both passes so a `&anchor` defined in
        # options: is still resolvable by a `*alias` in records: (see
        # EventHandler#initialize) -- capture_options runs first (eagerly, right
        # here) so its anchors are always registered before the deferred
        # records pass can reference them.
        ruby_visitor = Psych::Visitors::ToRuby.create

        {
          options: capture_options(input, ruby_visitor) || {},
          records: Enumerator.new { |yielder| stream_records(input, ruby_visitor) { |row| yielder << row } }
        }
      end

      # See Base#parse_records_only: skips the options-capturing pass entirely
      # (no anchor-sharing concern here, since there's only one pass to share
      # a visitor across) -- used by ReferenceScanner's prescan, which only
      # ever looks at records:.
      def parse_records_only
        input = Base.rewindable?(data_io) ? data_io : data_io.read
        Enumerator.new { |yielder| stream_records(input, Psych::Visitors::ToRuby.create) { |row| yielder << row } }
      end

      private

      def capture_options(input, ruby_visitor)
        handler = EventHandler.new(capture_key: OPTIONS_KEY, ruby_visitor: ruby_visitor)
        Psych::Parser.new(handler).parse(input)
        data_io.rewind if input.equal?(data_io)
        handler.capture_value
      end

      def stream_records(input, ruby_visitor, &block)
        handler = EventHandler.new(stream_key: RECORDS_KEY, ruby_visitor: ruby_visitor, &block)
        Psych::Parser.new(handler).parse(input)
      end
    end
  end
end

require_relative "yml/event_handler"

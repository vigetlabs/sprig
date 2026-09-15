require "psych"

module Sprig
  module Parser
    class Yml
      # Walks a YAML document once via Psych::Parser and, for two named top-level
      # keys, either fully materializes that key's value into a plain Ruby object
      # ("capture", used for `options:`) or yields each element of that key's
      # sequence value one at a time via a block ("stream", used for `records:`)
      # without ever building the full sequence in memory.
      #
      # Keys are matched by name, not by position or "the first sequence
      # encountered" -- `options:`/`records:` can appear in either order, and an
      # option's own value (e.g. find_existing_by: [...]) can itself be an array,
      # so position/shape alone can't tell them apart.
      #
      # Assumes the shape Sprig's seed files actually use: the captured key's
      # value is a single node (a mapping, in practice), and the streamed key's
      # value is a sequence of mappings (one per record).
      class EventHandler < Psych::Handler
        # A YAML merge key (`<<:`) at the document root would need this handler to
        # promote another mapping's (or, in the common `<<: *anchor` form, an
        # aliased mapping's) keys up into the root's own key namespace -- doing
        # that correctly means tracking anchors for nodes this handler never
        # otherwise touches, which is squarely the job Psych's own full-document
        # Composer/Resolver already do and this streaming handler deliberately
        # bypasses for memory efficiency. Rather than silently ignore `<<:` (the
        # previous behavior -- indistinguishable from an empty/missing records:
        # key), raise clearly instead.
        class UnsupportedMergeKeyError < StandardError; end

        MERGE_KEY = "<<"

        def initialize(capture_key: nil, stream_key: nil, ruby_visitor: Psych::Visitors::ToRuby.create, &on_streamed_row)
          @capture_key = capture_key
          @stream_key = stream_key
          @on_streamed_row = on_streamed_row

          @depth = 0
          @pending_key = nil
          @stream_depth = nil
          @stream_open_depth = nil

          @builder = nil
          @builder_mode = nil
          @builder_close_depth = nil

          # One shared visitor for the whole pass, so a `&anchor` defined in one
          # streamed row's node is still resolvable by a `*alias` in a later row --
          # each row is built via its own throwaway Psych::TreeBuilder document (see
          # #start_builder), so anchor resolution can't rely on Psych's usual
          # single-document Node#to_ruby; it has to be threaded through explicitly.
          #
          # Accepted as a parameter (rather than always created fresh here) so the
          # options-capturing pass and the records-streaming pass -- two separate
          # EventHandler instances, see Yml#parse -- can share the same visitor:
          # otherwise an `&anchor` in `options:` would be invisible to a `*alias`
          # in `records:`, since each pass would only ever see its own handler's
          # anchor table.
          @ruby_visitor = ruby_visitor
        end

        attr_reader :capture_value

        def start_mapping(anchor, tag, implicit, style)
          before_entering_node!
          @depth += 1
          @builder&.start_mapping(anchor, tag, implicit, style)
        end

        def end_mapping
          @builder&.end_mapping
          @depth -= 1
          finish_builder_if_done
        end

        def start_sequence(anchor, tag, implicit, style)
          before_entering_node!
          @depth += 1
          @builder&.start_sequence(anchor, tag, implicit, style)
        end

        def end_sequence
          @builder&.end_sequence
          @depth -= 1
          finish_builder_if_done
          @stream_depth = nil if @stream_depth && @depth == @stream_open_depth
        end

        def scalar(value, anchor, tag, plain, quoted, style)
          if @builder
            @builder.scalar(value, anchor, tag, plain, quoted, style)
          elsif @depth == 1
            @pending_key = value
          end
        end

        def alias(anchor)
          if @builder
            @builder.alias(anchor)
          else
            # An alias can be a depth-1 key's value too (most commonly
            # `<<: *anchor`) -- reject_root_merge_key! must be checked here as
            # well as in claim_pending_key!, since no start_mapping/
            # start_sequence event (the only other place a node "arrives")
            # fires for an aliased value.
            reject_root_merge_key!
          end
          @pending_key = nil
        end

        private

        # Called before descending into any new mapping/sequence node. Decides
        # whether this node is the value of a key we care about.
        def before_entering_node!
          return if @builder

          if @depth == 1 && @pending_key
            claim_pending_key!
          elsif @stream_depth && @depth == @stream_depth
            start_builder(:stream_row)
          end
        end

        def claim_pending_key!
          reject_root_merge_key!

          if @capture_key && matches_key?(@capture_key)
            start_builder(:capture)
          elsif @stream_key && matches_key?(@stream_key)
            @stream_open_depth = @depth
            @stream_depth = @depth + 1
          end
          @pending_key = nil
        end

        # A YAML merge key is only meaningful as a mapping key, so this only
        # ever needs to check depth 1 -- a `<<` appearing as a plain scalar
        # *value* (not a key) elsewhere is not a merge key at all.
        def reject_root_merge_key!
          return unless @depth == 1 && @pending_key == MERGE_KEY

          raise UnsupportedMergeKeyError,
            "Sprig's streaming YAML parser doesn't support a merge key (<<:) at the document root -- " \
            "rewrite the file with plain `options:`/`records:` keys instead."
        end

        # Matches a plain string key ("records") and also the legacy YAML
        # symbol-scalar convention (":records", parsed as a plain scalar whose
        # text literally starts with a colon -- Psych only resolves this to a
        # real Ruby Symbol later, during to_ruby conversion, not at the raw
        # parser-event level this handler works at).
        def matches_key?(key)
          @pending_key == key || @pending_key == ":#{key}"
        end

        def start_builder(mode)
          @builder = Psych::TreeBuilder.new
          @builder.start_stream(Psych::Nodes::Stream::UTF8)
          @builder.start_document([1, 1], [], true)
          @builder_mode = mode
          @builder_close_depth = @depth
        end

        def finish_builder_if_done
          return unless @builder && @depth == @builder_close_depth

          @builder.end_document
          @builder.end_stream
          document_node = @builder.root.children.first
          value_node = document_node.children.first
          ruby_value = @ruby_visitor.accept(value_node)

          if @builder_mode == :capture
            @capture_value = ruby_value
          else
            @on_streamed_row.call(ruby_value)
          end

          @builder = nil
          @builder_mode = nil
          @builder_close_depth = nil
        end
      end
    end
  end
end

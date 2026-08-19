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
        def initialize(capture_key: nil, stream_key: nil, &on_streamed_row)
          @capture_key = capture_key
          @stream_key = stream_key
          @on_streamed_row = on_streamed_row

          @depth = 0
          @pending_key = nil
          @stream_depth = nil

          @builder = nil
          @builder_mode = nil
          @builder_close_depth = nil
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
        end

        def scalar(value, anchor, tag, plain, quoted, style)
          if @builder
            @builder.scalar(value, anchor, tag, plain, quoted, style)
          elsif @depth == 1
            @pending_key = value
          end
        end

        def alias(anchor)
          @builder&.alias(anchor)
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
          if @capture_key && @pending_key == @capture_key
            start_builder(:capture)
          elsif @stream_key && @pending_key == @stream_key
            @stream_depth = @depth + 1
          end
          @pending_key = nil
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
          ruby_value = value_node.to_ruby

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

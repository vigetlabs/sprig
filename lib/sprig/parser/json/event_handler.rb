require "oj"

module Sprig
  module Parser
    class Json
      # An Oj::ScHandler that, for two named top-level keys, either fully
      # materializes that key's value into a plain Ruby object ("capture", used
      # for `options`) or yields each element of that key's array value one at a
      # time via a block ("stream", used for `records`) -- without ever building
      # the full array. Oj already builds nested Ruby structures incrementally via
      # these callbacks, so the only extra bookkeeping needed here is: (a) tracking
      # depth so only the *root* `options`/`records` keys are matched, not a
      # same-named field nested inside a record, (b) recognizing "the array
      # that's the value of the streamed key" by object identity via a sentinel,
      # so array_append can redirect to the block instead of growing a real array,
      # and (c) discarding -- not building at all -- the value of any root key that
      # is neither of the two we care about (e.g. `records` during a capture-only
      # pass), so a pass that only wants `options` never materializes the whole
      # `records` array just to throw it away once Oj returns.
      #
      # Keys are matched by name, not position: `options`/`records` can appear in
      # either order, and an option's own value (e.g. find_existing_by: [...])
      # can itself be an array.
      class EventHandler < Oj::ScHandler
        def initialize(capture_key: nil, stream_key: nil, &on_streamed_row)
          super()
          @capture_key = capture_key
          @stream_key = stream_key
          @on_streamed_row = on_streamed_row

          @depth = 0
          @awaiting_key = nil

          # Distinct, always-real sentinel objects -- never `nil` -- so a
          # legitimate JSON `null` value is never mistaken for "this is the
          # marker" via #equal?.
          @stream_marker = Object.new.freeze
          @stream_claimed = false
          @discard_marker = Object.new.freeze
          @discard_depth = nil

          @capture_value = nil
        end

        attr_reader :capture_value

        def hash_start
          @depth += 1
          return @discard_marker if discarding?
          maybe_start_discard!
          discarding? ? @discard_marker : {}
        end

        def hash_end
          @depth -= 1
          clear_discard_if_done
        end

        def hash_key(key)
          @awaiting_key = key if @depth == 1
          key
        end

        def hash_set(h, key, value)
          return if h.equal?(@discard_marker)
          @capture_value = value if @depth == 1 && @capture_key && key == @capture_key
          h[key] = value unless value.equal?(@stream_marker)
        end

        def array_start
          @depth += 1
          if @stream_key && @awaiting_key == @stream_key && !@stream_claimed
            @stream_claimed = true
            return @stream_marker
          end
          return @discard_marker if discarding?
          maybe_start_discard!
          discarding? ? @discard_marker : []
        end

        def array_end
          @depth -= 1
          clear_discard_if_done
        end

        def array_append(array, value)
          return if array.equal?(@discard_marker)
          if array.equal?(@stream_marker)
            @on_streamed_row.call(value)
          else
            array << value
          end
        end

        private

        def discarding?
          !@discard_depth.nil?
        end

        # Called right after entering a new depth-1 key's value (i.e. @depth has
        # just become 2). If that key is neither the capture key nor the stream
        # key, nothing under it needs to be built at all -- mark this depth as
        # the start of a discard region so every hash/array underneath (however
        # deeply nested) is skipped too, until it closes back out.
        def maybe_start_discard!
          return unless @depth == 2 && @awaiting_key

          wanted = (@capture_key && @awaiting_key == @capture_key) ||
            (@stream_key && @awaiting_key == @stream_key)
          @discard_depth = @depth unless wanted
        end

        def clear_discard_if_done
          @discard_depth = nil if @discard_depth && @depth < @discard_depth
        end
      end
    end
  end
end

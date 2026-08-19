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
      # same-named field nested inside a record, and (b) recognizing "the array
      # that's the value of the streamed key" by object identity via a sentinel,
      # so array_append can redirect to the block instead of growing a real array.
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
          @stream_marker = nil
          @capture_value = nil
        end

        attr_reader :capture_value

        def hash_start
          @depth += 1
          {}
        end

        def hash_end
          @depth -= 1
        end

        def hash_key(key)
          @awaiting_key = key if @depth == 1
          key
        end

        def hash_set(h, key, value)
          @capture_value = value if @depth == 1 && @capture_key && key == @capture_key
          h[key] = value unless value.equal?(@stream_marker)
        end

        def array_start
          @depth += 1
          if @stream_key && @awaiting_key == @stream_key && @stream_marker.nil?
            @stream_marker = Object.new.freeze
          else
            []
          end
        end

        def array_end
          @depth -= 1
        end

        def array_append(array, value)
          if array.equal?(@stream_marker)
            @on_streamed_row.call(value)
          else
            array << value
          end
        end
      end
    end
  end
end

require "spec_helper"

RSpec.describe Sprig::Parser::Json do
  describe "#parse" do
    it "matches JSON.load for a simple records-only file" do
      file = File.open("spec/fixtures/seeds/test/posts.json")
      expected = JSON.load_file("spec/fixtures/seeds/test/posts.json")

      result = described_class.new(file).parse

      expect(result[:records].to_a).to eq(expected["records"])
      file.close
    end

    it "matches JSON.load when options (with an array-valued suboption) appears before records" do
      data = <<~JSON
        {
          "options": {"find_existing_by": ["title", "content"]},
          "records": [
            {"sprig_id": 1, "title": "Such Title"},
            {"sprig_id": 2, "title": "Other Title"}
          ]
        }
      JSON
      expected = JSON.parse(data)

      result = described_class.new(StringIO.new(data)).parse

      expect(result[:options]).to eq(expected["options"])
      expect(result[:records].to_a).to eq(expected["records"])
    end

    it "matches JSON.load for a record with a nested array attribute" do
      data = <<~JSON
        {
          "records": [
            {"sprig_id": 1, "title": "A", "tags": ["x", "y"]}
          ],
          "options": {"delete_existing_by": "title"}
        }
      JSON
      expected = JSON.parse(data)

      result = described_class.new(StringIO.new(data)).parse

      expect(result[:records].to_a).to eq(expected["records"])
      expect(result[:options]).to eq(expected["options"])
    end

    it "returns an empty hash for options when the file has none" do
      file = File.open("spec/fixtures/seeds/test/posts.json")

      result = described_class.new(file).parse

      expect(result[:options]).to eq({})
      file.close
    end

    it "returns records as an Enumerator, not a realized Array" do
      file = File.open("spec/fixtures/seeds/test/posts.json")

      result = described_class.new(file).parse

      expect(result[:records]).to be_an(Enumerator)
      file.close
    end

    it "falls back to buffering the whole file when data_io is not rewindable (e.g. a pipe)" do
      read_end, write_end = IO.pipe
      write_end.write(File.read("spec/fixtures/seeds/test/posts.json"))
      write_end.close
      expected = JSON.load_file("spec/fixtures/seeds/test/posts.json")

      result = described_class.new(read_end).parse

      expect(result[:records].to_a).to eq(expected["records"])
      read_end.close
    end
  end

  describe "memory characteristics" do
    # A subclass that instruments #array_append to record the largest *real*
    # (non-marker, non-discarded) array it ever builds, without changing any
    # other behavior. Used to prove the options-only capture pass never
    # materializes the (potentially large) records array just to throw it
    # away once Oj.sc_parse returns.
    let(:instrumented_handler_class) do
      Class.new(Sprig::Parser::Json::EventHandler) do
        attr_reader :max_real_array_size

        def initialize(...)
          super
          @max_real_array_size = 0
        end

        def array_append(array, value)
          super
          @max_real_array_size = array.size if !array.equal?(@stream_marker) && !array.equal?(@discard_marker) && array.size > @max_real_array_size
        end
      end
    end

    it "never builds the full records array during a capture-only (options) pass" do
      records = Array.new(1000) { |i| {"sprig_id" => i, "title" => "Post #{i}"} }
      json = JSON.generate({"options" => {"a" => 1}, "records" => records})

      handler = instrumented_handler_class.new(capture_key: "options")
      Oj.sc_parse(handler, json)

      expect(handler.capture_value).to eq({"a" => 1})
      expect(handler.max_real_array_size).to eq(0)
    end

    it "still streams every row correctly during the real (stream-key) pass" do
      records = Array.new(1000) { |i| {"sprig_id" => i, "title" => "Post #{i}"} }
      json = JSON.generate({"records" => records})

      streamed = []
      handler = Sprig::Parser::Json::EventHandler.new(stream_key: "records") { |row| streamed << row }
      Oj.sc_parse(handler, json)

      expect(streamed).to eq(records)
    end
  end
end

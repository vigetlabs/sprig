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
end

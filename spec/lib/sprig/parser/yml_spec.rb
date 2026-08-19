require "spec_helper"

RSpec.describe Sprig::Parser::Yml do
  describe "#parse" do
    it "matches YAML.load for a simple records-only file" do
      file = File.open("spec/fixtures/seeds/test/posts.yml")
      expected = YAML.load_file("spec/fixtures/seeds/test/posts.yml")

      result = described_class.new(file).parse

      expect(result[:records].to_a).to eq(expected["records"])
      file.close
    end

    it "matches YAML.load when options (with an array-valued suboption) appears before records" do
      file = File.open("spec/fixtures/seeds/test/posts_find_existing_by_multiple.yml")
      expected = YAML.load_file("spec/fixtures/seeds/test/posts_find_existing_by_multiple.yml")

      result = described_class.new(file).parse

      expect(result[:options]).to eq(expected["options"])
      expect(result[:records].to_a).to eq(expected["records"])
      file.close
    end

    it "matches YAML.load for a record with a nested array attribute" do
      file = File.open("spec/fixtures/seeds/test/posts_with_habtm.yml")
      expected = YAML.load_file("spec/fixtures/seeds/test/posts_with_habtm.yml")

      result = described_class.new(file).parse

      expect(result[:records].to_a).to eq(expected["records"])
      file.close
    end

    it "returns an empty hash for options when the file has none" do
      file = File.open("spec/fixtures/seeds/test/posts.yml")

      result = described_class.new(file).parse

      expect(result[:options]).to eq({})
      file.close
    end

    it "returns records as an Enumerator, not a realized Array" do
      file = File.open("spec/fixtures/seeds/test/posts.yml")

      result = described_class.new(file).parse

      expect(result[:records]).to be_an(Enumerator)
      file.close
    end

    it "falls back to buffering the whole file when data_io is not rewindable (e.g. a pipe)" do
      read_end, write_end = IO.pipe
      write_end.write(File.read("spec/fixtures/seeds/test/posts.yml"))
      write_end.close
      expected = YAML.load_file("spec/fixtures/seeds/test/posts.yml")

      result = described_class.new(read_end).parse

      expect(result[:records].to_a).to eq(expected["records"])
      read_end.close
    end
  end
end

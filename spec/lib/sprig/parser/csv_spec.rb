require "spec_helper"

RSpec.describe Sprig::Parser::Csv do
  describe "#parse" do
    it "matches a plain CSV.foreach parse of the same file" do
      file = File.open("spec/fixtures/seeds/test/posts.csv")
      expected = CSV.foreach("spec/fixtures/seeds/test/posts.csv", headers: :first_row, skip_blanks: true).map(&:to_hash)

      result = described_class.new(file).parse

      expect(result[:records].to_a).to eq(expected)
      file.close
    end

    it "returns records as an Enumerator, not a realized Array" do
      file = File.open("spec/fixtures/seeds/test/posts.csv")

      result = described_class.new(file).parse

      expect(result[:records]).to be_an(Enumerator)
      file.close
    end

    it "iterates records correctly even after the original IO has been closed" do
      file = File.open("spec/fixtures/seeds/test/posts.csv")
      expected = CSV.foreach("spec/fixtures/seeds/test/posts.csv", headers: :first_row, skip_blanks: true).map(&:to_hash)

      result = described_class.new(file).parse
      file.close

      expect(result[:records].to_a).to eq(expected)
    end

    it "skips blank lines, matching today's behavior" do
      content = "sprig_id,title\n1,First\n\n2,Second\n"
      file = StringIO.new(content)

      result = described_class.new(file).parse

      expect(result[:records].to_a).to eq([{"sprig_id" => "1", "title" => "First"}, {"sprig_id" => "2", "title" => "Second"}])
    end
  end
end

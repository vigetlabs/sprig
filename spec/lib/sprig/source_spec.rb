require 'spec_helper'

RSpec.describe Sprig::Source do
  describe "#records" do
    it "returns the records from a custom source" do
      source = File.open('spec/fixtures/seeds/test/posts.yml')
      subject = Sprig::Source.new('posts', source: source, parser: Sprig::Parser::Yml)

      expect(subject.records).to be_an(Array)
      expect(subject.records.first['title']).to eq('Yaml title')
    end

    it "returns an empty array when the parsed data has no records" do
      source = StringIO.new("options:\n  delete_existing_by: title\n")
      subject = Sprig::Source.new('posts', source: source, parser: Sprig::Parser::Yml)

      expect(subject.records).to eq([])
    end
  end

  describe "#options" do
    it "returns an empty hash when no options are in the data" do
      source = File.open('spec/fixtures/seeds/test/posts.yml')
      subject = Sprig::Source.new('posts', source: source, parser: Sprig::Parser::Yml)

      expect(subject.options).to eq({})
    end

    it "returns the options from the parsed data when present" do
      data = "{ \"records\": [], \"options\": { \"delete_existing_by\": [\"title\"] } }"
      source = StringIO.new(data)
      subject = Sprig::Source.new('posts', source: source, parser: Sprig::Parser::Json)

      expect(subject.options).to eq({ 'delete_existing_by' => ['title'] })
    end
  end

  describe "with a custom source" do
    it "raises an ArgumentError if the source does not act like an IO" do
      expect {
        Sprig::Source.new('posts', source: 'not an io').records
      }.to raise_error(ArgumentError, 'Data sources must act like an IO.')
    end

    it "raises an ArgumentError if the parser does not define #parse" do
      not_a_parser = Class.new
      source = StringIO.new('records: []')

      expect {
        Sprig::Source.new('posts', source: source, parser: not_a_parser).records
      }.to raise_error(ArgumentError, 'Parsers must define #parse.')
    end
  end

  describe "default source" do
    around do |example|
      load_seeds('posts.yml', &example)
    end

    before do
      stub_rails_root('./spec/fixtures')
    end

    it "finds the seed file by table name" do
      source = Sprig::Source.new('posts')

      expect(source.records.first['title']).to eq('Yaml title')
    end
  end

  describe Sprig::Source::SourceDeterminer do
    describe "#file" do
      around do |example|
        load_seeds('posts.yml', &example)
      end

      before do
        stub_rails_root('./spec/fixtures')
      end

      it "returns the matching file for the table name" do
        determiner = Sprig::Source::SourceDeterminer.new('posts')

        expect(determiner.file).to be_a(File)
      end

      it "raises FileNotFoundError when no seed file matches" do
        expect {
          Sprig::Source::SourceDeterminer.new('missing').file
        }.to raise_error(Sprig::Source::SourceDeterminer::FileNotFoundError)
      end
    end
  end

  describe Sprig::Source::ParserDeterminer do
    describe "#parser" do
      it "returns Yml for .yml files" do
        file = File.new('spec/fixtures/seeds/test/posts.yml')
        determiner = Sprig::Source::ParserDeterminer.new(file)

        expect(determiner.parser).to eq(Sprig::Parser::Yml)
        file.close
      end

      it "returns Json for .json files" do
        file = File.new('spec/fixtures/seeds/test/posts.json')
        determiner = Sprig::Source::ParserDeterminer.new(file)

        expect(determiner.parser).to eq(Sprig::Parser::Json)
        file.close
      end

      it "raises UnparsableFileError for an unknown extension" do
        file = File.new('spec/fixtures/seeds/test/posts.md')
        determiner = Sprig::Source::ParserDeterminer.new(file)

        expect {
          determiner.parser
        }.to raise_error(Sprig::Source::ParserDeterminer::UnparsableFileError)
        file.close
      end
    end
  end
end

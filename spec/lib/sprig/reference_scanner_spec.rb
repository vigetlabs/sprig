require "spec_helper"
require "open-uri"

RSpec.describe Sprig::ReferenceScanner do
  before { stub_rails_root }

  describe ".scan" do
    context "with a file that references another class's sprig_id" do
      around { |example| load_seeds("posts.yml", "comments.yml", &example) }

      it "finds the reference, even though it hasn't planted anything yet" do
        needed = described_class.scan([Post, Comment])

        expect(needed).to eq(Set["Post 1"])
      end
    end

    context "with a many-to-many reference inside an array attribute" do
      around { |example| load_seeds("posts_with_habtm.yml", "tags.yml", &example) }

      it "finds every referenced id" do
        needed = described_class.scan([
          Tag,
          {class: Post, source: open("spec/fixtures/seeds/test/posts_with_habtm.yml")}
        ])

        expect(needed).to eq(Set["Tag 1", "Tag 2"])
      end
    end

    context "with no references anywhere" do
      around { |example| load_seeds("posts.yml", &example) }

      it "returns an empty set" do
        needed = described_class.scan([Post])

        expect(needed).to eq(Set.new)
      end
    end

    context "with a custom :source: that supports #rewind" do
      around { |example| load_seeds("posts.yml", "comments.yml", &example) }

      it "leaves the source readable from the start for the real parse afterward" do
        source = open("spec/fixtures/seeds/test/comments.yml")

        needed = described_class.scan([Post, {class: Comment, source: source}])

        expect(needed).to eq(Set["Post 1"])
        expect(source.read).to eq(File.read("spec/fixtures/seeds/test/comments.yml"))
      end
    end

    context "with a custom :source: that does not support #rewind" do
      around { |example| load_seeds("posts.yml", "comments.yml", &example) }

      it "returns nil instead of guessing, since it can't be safely read twice" do
        non_rewindable = double("IO", read: nil, close: nil)

        needed = described_class.scan([Post, {class: Comment, source: non_rewindable}])

        expect(needed).to be_nil
      end
    end

    context "with a custom parser whose result uses string keys instead of symbol keys" do
      it "still recognizes the records, normalized the same way Source itself does" do
        string_keyed_parser = Class.new do
          def initialize(io)
            @io = io
          end

          def parse
            {"records" => [{"sprig_id" => "1", "post_id" => "<%= sprig_record(Post, 1).id %>"}]}
          end
        end

        directive = {class: Comment, source: StringIO.new("irrelevant"), parser: string_keyed_parser}

        needed = described_class.scan([directive])

        expect(needed).to eq(Set["Post 1"])
      end
    end

    context "with an explicit :parser: override and no custom :source:" do
      around { |example| load_seeds("comments.yml", &example) }

      it "uses the override instead of auto-detecting a parser from the file extension" do
        custom_parser = Class.new do
          def initialize(io)
            @io = io
          end

          def parse
            {records: [{sprig_id: "1", post_id: "<%= sprig_record(Post, 99).id %>"}]}
          end
        end

        needed = described_class.scan([{class: Comment, parser: custom_parser}])

        expect(needed).to eq(Set["Post 99"])
      end
    end
  end
end

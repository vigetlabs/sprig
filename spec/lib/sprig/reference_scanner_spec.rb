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

    context "with a reference split across a chunk boundary" do
      around { |example| load_seeds("posts.yml", "comments.yml", &example) }

      it "still finds it" do
        stub_const("Sprig::ReferenceScanner::CHUNK_SIZE", 5)

        needed = described_class.scan([Post, Comment])

        expect(needed).to eq(Set["Post 1"])
      end
    end
  end
end

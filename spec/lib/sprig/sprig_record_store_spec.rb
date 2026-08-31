require "spec_helper"

RSpec.describe Sprig::SprigRecordStore do
  subject { described_class.instance }

  before { subject.reset }

  describe "#save / #get" do
    it "returns a record with the correct attributes for a saved sprig_id" do
      post = Post.create!(title: "Hello", content: "World")

      subject.save(post, "1")

      fetched = subject.get(Post, "1")
      expect(fetched.title).to eq("Hello")
      expect(fetched.content).to eq("World")
    end

    it "does not retain the record instance itself -- only enough to look it back up" do
      post = Post.create!(title: "Hello", content: "World")

      subject.save(post, "1")

      stored = subject.instance_variable_get(:@records)["posts"]["1"]
      expect(stored).not_to be_a(Post)
      expect(stored).to eq(post.id)
    end

    it "returns a LazyRecord, not a freshly-fetched real record or the original instance" do
      post = Post.create!(title: "Hello", content: "World")
      subject.save(post, "1")

      fetched = subject.get(Post, "1")

      expect(fetched).to be_a(Sprig::SprigRecordStore::LazyRecord)
      expect(fetched).not_to equal(post)
      expect(fetched).to eq(post)
    end

    it "reflects updates made to the database after saving, since it re-fetches on every call" do
      post = Post.create!(title: "Hello", content: "World")
      subject.save(post, "1")

      post.update!(title: "Updated")

      expect(subject.get(Post, "1").title).to eq("Updated")
    end

    it "stores multiple records independently, keyed by class and sprig_id" do
      post = Post.create!(title: "A Post")
      user = User.create!(first_name: "Ada", last_name: "Lovelace")

      subject.save(post, "1")
      subject.save(user, "1")

      expect(subject.get(Post, "1")).to eq(post)
      expect(subject.get(User, "1")).to eq(user)
    end

    it "raises RecordNotFoundError for a sprig_id that was never saved" do
      expect {
        subject.get(Post, "999")
      }.to raise_error(Sprig::SprigRecordStore::RecordNotFoundError)
    end

    it "answers #id directly with no database fetch" do
      post = Post.create!(title: "Hello", content: "World")
      subject.save(post, "1")

      expect(Post).not_to receive(:find)
      expect(subject.get(Post, "1").id).to eq(post.id)
    end

    it "fetches the real record, exactly once, only when something beyond the id is asked for" do
      post = Post.create!(title: "Hello", content: "World")
      subject.save(post, "1")

      expect(Post).to receive(:find).once.and_call_original
      fetched = subject.get(Post, "1")
      fetched.title
      fetched.content
    end
  end

  describe "#preload_referenced_ids" do
    it "keeps an id that was preloaded" do
      post = Post.create!(title: "Hello")
      subject.preload_referenced_ids(Set["Post 1"])

      subject.save(post, "1")

      expect(subject.get(Post, "1")).to eq(post)
    end

    it "discards an id that was not preloaded, without raising" do
      post = Post.create!(title: "Hello")
      subject.preload_referenced_ids(Set["Post 999"])

      expect { subject.save(post, "1") }.not_to raise_error

      stored = subject.instance_variable_get(:@records)["posts"]
      expect(stored).not_to have_key("1")
    end

    it "never stores a preloaded id's placeholder and its real value separately -- the same key just gets overwritten" do
      post = Post.create!(title: "Hello")
      subject.preload_referenced_ids(Set["Post 1"])

      stored = subject.instance_variable_get(:@records)["posts"]
      expect(stored).to eq({"1" => nil})

      subject.save(post, "1")

      expect(stored).to eq({"1" => post.id})
    end

    it "accepts any Enumerable of dependency id strings, not just a Set" do
      post = Post.create!(title: "Hello")
      subject.preload_referenced_ids(["Post 1"])

      subject.save(post, "1")

      expect(subject.get(Post, "1")).to eq(post)
    end

    it "does not affect saves made before it's called (pruning is off by default)" do
      post = Post.create!(title: "Hello")

      subject.save(post, "1")

      expect(subject.get(Post, "1")).to eq(post)
    end
  end

  describe "#reset" do
    it "clears previously saved records" do
      post = Post.create!(title: "Hello")
      subject.save(post, "1")

      subject.reset

      expect {
        subject.get(Post, "1")
      }.to raise_error(Sprig::SprigRecordStore::RecordNotFoundError)
    end

    it "turns pruning back off, so a later run without preloading keeps everything again" do
      subject.preload_referenced_ids(Set["Post 999"])

      subject.reset

      post = Post.create!(title: "Hello")
      subject.save(post, "1")
      expect(subject.get(Post, "1")).to eq(post)
    end
  end
end

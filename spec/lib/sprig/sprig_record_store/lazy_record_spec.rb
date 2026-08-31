require "spec_helper"

RSpec.describe Sprig::SprigRecordStore::LazyRecord do
  describe "#id" do
    it "returns the wrapped id without querying the database" do
      expect(Post).not_to receive(:find)
      expect(Post).not_to receive(:unscoped)

      lazy = described_class.new(Post, 42)

      expect(lazy.id).to eq(42)
    end
  end

  describe "delegation" do
    it "fetches the real record and delegates a method not defined on LazyRecord itself" do
      post = Post.create!(title: "Hello", content: "World")

      lazy = described_class.new(Post, post.id)

      expect(lazy.title).to eq("Hello")
    end

    it "fetches at most once, even if multiple delegated methods are called" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(Post).to receive(:unscoped).once.and_call_original

      lazy.title
      lazy.content
    end

    it "raises whatever the underlying finder raises for an id that doesn't exist" do
      lazy = described_class.new(Post, -1)

      # The specific error class is adapter-dependent (ActiveRecord::RecordNotFound
      # vs. Mongoid::Errors::DocumentNotFound) -- LazyRecord doesn't rescue or
      # translate it, so this only checks that #find's own error propagates.
      expect { lazy.title }.to raise_error(StandardError)
    end
  end

  describe "#==" do
    it "compares equal to the real record it wraps" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy).to eq(post)
    end

    it "does not equal a different record" do
      post = Post.create!(title: "Hello", content: "World")
      other = Post.create!(title: "Other", content: "Content")
      lazy = described_class.new(Post, post.id)

      expect(lazy).not_to eq(other)
    end

    it "is symmetric -- the real record considers itself equal to the proxy too" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(post).to eq(lazy)
    end
  end

  describe "#respond_to?" do
    it "reports true for the wrapped record's own attributes" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy).to respond_to(:title)
    end
  end

  describe "type checks (#is_a?/#kind_of?/#instance_of?/#class)" do
    it "reports the wrapped class, not LazyRecord, without triggering a database fetch" do
      expect(Post).not_to receive(:find)
      expect(Post).not_to receive(:unscoped)

      lazy = described_class.new(Post, 42)

      expect(lazy.is_a?(Post)).to be true
      expect(lazy.kind_of?(Post)).to be true # standard:disable Style/ClassCheck -- explicitly verifying the #kind_of? alias itself
      expect(lazy.instance_of?(Post)).to be true
      expect(lazy.class).to eq(Post)
    end

    it "reports false for an unrelated class" do
      lazy = described_class.new(Post, 42)

      expect(lazy.is_a?(String)).to be false
    end

    it "still reveals its real underlying class via Module#===, which bypasses the override above" do
      lazy = described_class.new(Post, 42)

      expect(described_class === lazy).to be true

      # Under the mongoid appraisal specifically, loading mongoid/bson appears to disable
      # the CRuby fast path that normally lets Module#=== bypass a monkeypatched #kind_of?
      # (confirmed directly: the exact same SimpleDelegator + #kind_of? override, with
      # mongoid required, no longer gets the bypass either) -- an environment quirk
      # unrelated to LazyRecord's own correctness, so only asserted under ActiveRecord.
      expect(Post === lazy).to be false if Sprig.adapter == :active_record
    end

    it "passes a real ActiveRecord association assignment's own type check" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)
      comment = Comment.new(body: "hi")

      expect { comment.post = lazy }.not_to raise_error
      expect(comment.post_id).to eq(post.id)
    end
  end

  describe "methods inherited from Object (to_s, inspect, hash, as_json)" do
    it "delegates #hash to the real record, consistent with #==" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy.hash).to eq(post.hash)
    end

    it "delegates #as_json to the real record rather than serializing its own ivars" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy.as_json).to eq(post.as_json)
    end

    it "delegates #inspect to the real record" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy.inspect).to eq(post.inspect)
    end
  end

  describe "keyword argument forwarding" do
    it "forwards keyword arguments through to a delegated method" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect { lazy.save!(validate: false) }.not_to raise_error
    end
  end

  # default_scope, and this particular way of faking an anonymous named subclass,
  # are ActiveRecord-specific -- Mongoid resolves polymorphic classes by looking
  # up the real constant via the `_type` field, which this Class.new(Post) trick
  # doesn't register anywhere.
  if Sprig.adapter == :active_record
    describe "default_scope" do
      it "can still find a record excluded by the model's own default_scope" do
        scoped_class = Class.new(Post) do
          def self.name
            "LazyRecordDefaultScopeSpecPost"
          end
          default_scope { where(published: true) }
        end
        post = scoped_class.create!(title: "Hello", content: "World", published: false)
        lazy = described_class.new(scoped_class, post.id)

        expect(lazy.title).to eq("Hello")
      end
    end
  end

  describe "#dup / #clone" do
    it "#dup produces a genuinely new, unsaved record -- not a re-fetch of the original" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)
      lazy.to_real_record

      copy = lazy.dup
      expect(copy.new_record?).to be true
      # ActiveRecord ids are DB-assigned, so an unsaved dup's id is nil; Mongoid
      # ids are generated client-side on #new/#dup, so a dup already has a real,
      # distinct BSON::ObjectId before it's ever saved.
      if Sprig.adapter == :active_record
        expect(copy.id).to be_nil
      else
        expect(copy.id).not_to be_nil
        expect(copy.id).not_to eq(post.id)
      end

      copy.title = "Copy"
      expect { copy.save! }.to change(Post, :count).by(1)
      expect(post.reload.title).to eq("Hello")

      expect(Post).not_to receive(:unscoped)
      expect(copy.id).not_to be_nil
      expect(copy.id).to eq(copy.to_real_record.id)
    end

    it "#dup on a not-yet-materialized proxy still duplicates the real record, not the proxy" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id) # never accessed yet -- to_real_record not yet called

      copy = lazy.dup

      expect(copy.new_record?).to be true
      expect(copy.title).to eq("Hello")

      copy.save!

      expect(Post).not_to receive(:unscoped)
      expect(copy.id).not_to be_nil
      expect(copy.id).to eq(copy.to_real_record.id)
    end

    it "#clone matches the real record's own #clone semantics" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      cloned = lazy.clone

      if Sprig.adapter == :active_record
        # ActiveRecord's #clone preserves persisted identity (the primary key),
        # unlike #dup.
        expect(cloned.id).to eq(post.id)
        expect(cloned.new_record?).to be false
      else
        # Mongoid's #clone, unlike ActiveRecord's, does not preserve identity at
        # all -- it behaves like #dup, producing a fresh, unsaved document with
        # its own new id.
        expect(cloned.id).not_to eq(post.id)
        expect(cloned.new_record?).to be true
      end
    end

    it "does not trigger a fetch just to construct the LazyRecord itself" do
      expect(Post).not_to receive(:unscoped)

      described_class.new(Post, 42)
    end
  end
end

require "spec_helper"

RSpec.describe Sprig::SprigRecordStore::LazyRecord do
  describe "#id" do
    it "returns the wrapped id without querying the database" do
      expect(Post).not_to receive(:find)

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

      expect(Post).to receive(:find).once.and_call_original

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
  end

  describe "#respond_to?" do
    it "reports true for the wrapped record's own attributes" do
      post = Post.create!(title: "Hello", content: "World")
      lazy = described_class.new(Post, post.id)

      expect(lazy).to respond_to(:title)
    end
  end
end

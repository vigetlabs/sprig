require "spec_helper"

RSpec.describe Sprig::Seed::Descriptor do
  describe "#dependency_id" do
    it "matches Dependency.for(klass, sprig_id).id for an explicit sprig_id" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.dependency_id).to eq(Sprig::Dependency.for(Post, "1").id)
    end

    it "is memoized" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.dependency_id).to eq(descriptor.dependency_id)
    end

    it "does not raise when sprig_id is absent from the row" do
      descriptor = described_class.new(Post, {"title" => "Hello"}, {})

      expect { descriptor.dependency_id }.not_to raise_error
    end
  end

  describe "#dependencies" do
    it "is empty for plain attributes with no sprig_record references" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      expect(descriptor.dependencies).to eq([])
    end

    it "detects a single ERB-wrapped sprig_record reference" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "user_id" => "<%= sprig_record(Comment, 5) %>"}, {})

      expect(descriptor.dependencies).to eq([Sprig::Dependency.for(Comment, "5")])
    end

    it "detects multiple ERB-wrapped sprig_record references inside an array attribute" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "1",
        "tag_ids" => ["<%= sprig_record(Comment, 1) %>", "<%= sprig_record(Comment, 2) %>"]
      }, {})

      expect(descriptor.dependencies).to contain_exactly(
        Sprig::Dependency.for(Comment, "1"),
        Sprig::Dependency.for(Comment, "2")
      )
    end

    it "does not count a plain-text mention of sprig_record(...) with no ERB wrapper" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "1",
        "content" => "see sprig_record(Comment, 5) for context"
      }, {})

      expect(descriptor.dependencies).to eq([])
    end

    it "uniqs duplicate dependencies referenced from multiple attributes" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "1",
        "title" => "<%= sprig_record(Comment, 1) %>",
        "content" => "<%= sprig_record(Comment, 1) %>"
      }, {})

      expect(descriptor.dependencies).to eq([Sprig::Dependency.for(Comment, "1")])
    end

    it "never scans the sprig_id attribute itself" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "<%= sprig_record(Comment, 1) %>",
        "title" => "Hello"
      }, {})

      expect(descriptor.dependencies).to eq([])
    end

    it "does not eval a fully-dynamic ERB attribute (and so does not raise even if it would blow up)" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "1",
        "title" => "<%= raise \"should never run\" %>"
      }, {})

      expect { descriptor.dependencies }.not_to raise_error
      expect(descriptor.dependencies).to eq([])
    end

    it "resolves a quoted, non-numeric sprig_id the same way Attribute does" do
      descriptor = described_class.new(Post, {
        "sprig_id" => "1",
        "user_id" => "<%= sprig_record(Comment, 'cooldev') %>"
      }, {})

      expect(descriptor.dependencies).to eq([Sprig::Dependency.for(Comment, "cooldev")])
    end
  end

  describe "#to_entry" do
    it "returns a Sprig::Seed::Entry" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      expect(descriptor.to_entry).to be_a(Sprig::Seed::Entry)
    end

    it "produces an Entry with the same dependency_id when sprig_id is explicit" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.to_entry.dependency_id).to eq(descriptor.dependency_id)
    end

    it "produces an Entry with the same dependency_id when sprig_id is auto-generated" do
      descriptor = described_class.new(Post, {"title" => "Hello"}, {})

      expect(descriptor.to_entry.dependency_id).to eq(descriptor.dependency_id)
    end

    it "does not mutate raw_attrs, so plain attribute values still reach the resulting Entry correctly" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      # Force dependency_id/dependencies/sprig_id to memoize before materializing the Entry.
      descriptor.dependency_id
      descriptor.dependencies

      entry = descriptor.to_entry
      entry.save_record

      expect(Post.last.title).to eq("Hello")
      expect(Post.last.content).to eq("World")
    end
  end

  describe "memory characteristics" do
    it "never materializes Attribute/AttributeCollection objects when computing dependency_id/dependencies" do
      GC.start
      attribute_count_before = ObjectSpace.each_object(Sprig::Seed::Attribute).count
      collection_count_before = ObjectSpace.each_object(Sprig::Seed::AttributeCollection).count

      descriptors = Array.new(50) do |i|
        described_class.new(Post, {
          "sprig_id" => i.to_s,
          "title" => "Post #{i}",
          "user_id" => (i > 0) ? "<%= sprig_record(Post, #{i - 1}) %>" : nil
        }, {})
      end
      descriptors.each do |descriptor|
        descriptor.dependency_id
        descriptor.dependencies
      end

      attribute_count_after = ObjectSpace.each_object(Sprig::Seed::Attribute).count
      collection_count_after = ObjectSpace.each_object(Sprig::Seed::AttributeCollection).count

      expect(attribute_count_after).to eq(attribute_count_before)
      expect(collection_count_after).to eq(collection_count_before)
    end
  end
end

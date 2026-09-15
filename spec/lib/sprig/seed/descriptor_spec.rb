require "spec_helper"

RSpec.describe Sprig::Seed::Descriptor do
  describe "#as_dependency" do
    it "matches Dependency.for(klass, sprig_id) for an explicit sprig_id" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.as_dependency).to eq(Sprig::Dependency.for(Post, "1"))
    end

    it "is stable across repeated calls, despite no longer being memoized" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.as_dependency).to eq(descriptor.as_dependency)
    end

    it "does not raise when sprig_id is absent from the row" do
      descriptor = described_class.new(Post, {"title" => "Hello"}, {})

      expect { descriptor.as_dependency }.not_to raise_error
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

  describe "custom parser rows that are to_hash-convertible but not a real Hash" do
    let(:to_hash_only_row) do
      Class.new do
        def initialize(data)
          @data = data
        end

        def to_hash
          @data
        end
      end.new({"sprig_id" => "1", "user_id" => "<%= sprig_record(Comment, 5) %>"})
    end

    it "accepts the row and normalizes it via #to_hash, matching Entry's own leniency" do
      descriptor = described_class.new(Post, to_hash_only_row, {})

      expect(descriptor.sprig_id).to eq("1")
      expect(descriptor.dependencies).to eq([Sprig::Dependency.for(Comment, "5")])
    end
  end

  describe "#to_entry" do
    it "returns a Sprig::Seed::Entry" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      expect(descriptor.to_entry).to be_a(Sprig::Seed::Entry)
    end

    it "produces an Entry with the same as_dependency when sprig_id is explicit" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.to_entry.as_dependency).to eq(descriptor.as_dependency)
    end

    it "produces an Entry with the same as_dependency when sprig_id is auto-generated" do
      descriptor = described_class.new(Post, {"title" => "Hello"}, {})

      expect(descriptor.to_entry.as_dependency).to eq(descriptor.as_dependency)
    end

    it "does not mutate raw_attrs, so plain attribute values still reach the resulting Entry correctly" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      # Force as_dependency/dependencies/sprig_id to memoize before materializing the Entry.
      descriptor.as_dependency
      descriptor.dependencies

      entry = descriptor.to_entry
      entry.save_record

      expect(Post.last.title).to eq("Hello")
      expect(Post.last.content).to eq("World")
    end
  end

  describe "with Sprig.configuration.spill_seed_rows_to_disk enabled" do
    before do
      Sprig.configure { |c| c.spill_seed_rows_to_disk = true }
      Sprig::RawRowStore.instance.reset
    end

    it "holds the raw row in memory until #spill_to_disk! is called -- construction alone never spills" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

      expect(descriptor.instance_variable_get(:@raw_attrs)).to eq({"sprig_id" => "1", "title" => "Hello"})
    end

    it "still produces a correct Entry when never spilled (the common, immediately-planted case)" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

      entry = descriptor.to_entry
      entry.save_record

      expect(Post.last.title).to eq("Hello")
      expect(Post.last.content).to eq("World")
    end

    describe "#spill_to_disk!" do
      it "moves the raw row to RawRowStore and drops the in-memory reference" do
        descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

        descriptor.spill_to_disk!

        expect(descriptor.instance_variable_get(:@raw_attrs)).to be_nil
        expect(Sprig::RawRowStore.instance.fetch(descriptor.as_dependency.klass_and_sprig_id)).to eq({"sprig_id" => "1", "title" => "Hello"})
      end

      it "still produces a correct Entry via the disk-backed store after spilling" do
        descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello", "content" => "World"}, {})

        descriptor.spill_to_disk!
        entry = descriptor.to_entry
        entry.save_record

        expect(Post.last.title).to eq("Hello")
        expect(Post.last.content).to eq("World")
      end

      it "keeps the same as_dependency/sprig_id consistency guarantees as the in-memory path" do
        descriptor = described_class.new(Post, {"title" => "Hello"}, {}) # no explicit sprig_id
        as_dependency_before = descriptor.as_dependency

        descriptor.spill_to_disk!

        expect(descriptor.to_entry.as_dependency).to eq(as_dependency_before)
      end

      it "drops the descriptor to at most 3 ivars, keeping it within CRuby's smallest embedded object size" do
        descriptor = described_class.new(Post, {"sprig_id" => "1", "title" => "Hello"}, {})

        descriptor.spill_to_disk!

        expect(descriptor.instance_variables.size).to be <= 3
      end
    end
  end

  describe "as_dependency / dependencies (not stored as ivars)" do
    it "does not retain as_dependency or dependencies as instance state" do
      descriptor = described_class.new(Post, {"sprig_id" => "1", "user_id" => "<%= sprig_record(Comment, 5) %>"}, {})

      descriptor.as_dependency
      descriptor.dependencies

      expect(descriptor.instance_variables).not_to include(:@as_dependency, :@dependencies)
    end
  end

  describe "memory characteristics" do
    it "never materializes Attribute/AttributeCollection objects when computing as_dependency/dependencies" do
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
        descriptor.as_dependency
        descriptor.dependencies
      end

      attribute_count_after = ObjectSpace.each_object(Sprig::Seed::Attribute).count
      collection_count_after = ObjectSpace.each_object(Sprig::Seed::AttributeCollection).count

      expect(attribute_count_after).to eq(attribute_count_before)
      expect(collection_count_after).to eq(collection_count_before)
    end
  end
end

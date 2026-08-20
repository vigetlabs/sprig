require "spec_helper"

RSpec.describe Sprig::Dependency do
  describe ".for" do
    it "accepts a Class directly" do
      expect(described_class.for(Post, "1")).to be_a(described_class)
    end

    it "accepts a String class name and constantizes it" do
      expect(described_class.for("Post", "1")).to eq(described_class.for(Post, "1"))
    end

    it "raises ArgumentError for anything else" do
      expect {
        described_class.for(5, "1")
      }.to raise_error(ArgumentError, "First argument must be a Class.")
    end
  end

  describe "#id" do
    it "is deterministic: two separate .for calls with the same arguments produce the same id" do
      expect(described_class.for(Post, "1").id).to eq(described_class.for(Post, "1").id)
    end

    it "differs for different sprig_ids" do
      expect(described_class.for(Post, "1").id).not_to eq(described_class.for(Post, "2").id)
    end

    it "differs for different classes" do
      expect(described_class.for(Post, "1").id).not_to eq(described_class.for(Comment, "1").id)
    end

    it "normalizes a non-string sprig_id the same way as its string form" do
      expect(described_class.for(Post, 1).id).to eq(described_class.for(Post, "1").id)
    end
  end

  describe "#==" do
    it "treats two separately-constructed Dependencies for the same (klass, sprig_id) as equal" do
      expect(described_class.for(Post, "1")).to eq(described_class.for(Post, "1"))
    end

    it "treats Dependencies for different sprig_ids as unequal" do
      expect(described_class.for(Post, "1")).not_to eq(described_class.for(Post, "2"))
    end

    it "is not equal to a non-Dependency" do
      expect(described_class.for(Post, "1")).not_to eq("Post 1")
    end
  end

  describe "#hash / #eql?" do
    it "allows equal Dependencies to be used interchangeably as Hash keys" do
      hash = {described_class.for(Post, "1") => "value"}

      expect(hash[described_class.for(Post, "1")]).to eq("value")
    end
  end

  describe "#sprig_record_reference" do
    it "formats the class and sprig_id" do
      expect(described_class.for(Post, "1").sprig_record_reference).to eq("sprig_record(Post, 1)")
    end
  end
end

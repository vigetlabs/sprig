require "spec_helper"

RSpec.describe Sprig::Seed::Record do
  describe ".existing?" do
    let!(:existing) do
      Post.create(
        title: "Existing title",
        content: "Existing content",
        published: false
      )
    end

    it "returns true if the record has already been saved to the database" do
      subject = described_class.new_or_existing(Post, {title: "Existing title"}, {title: "Existing title"})

      expect(subject.existing?).to eq(true)
    end

    it "returns false if the record is new" do
      subject = described_class.new_or_existing(Post, {title: "New title"}, {title: "New title"})

      expect(subject.existing?).to eq(false)
    end
  end

  describe "#save" do
    context "when the record already exists" do
      let!(:existing) do
        Post.create(
          title: "Existing title",
          content: "Existing content",
          published: false,
          readonly_field: "original value"
        )
      end

      it "does not overwrite readonly attributes" do
        attributes = Sprig::Seed::AttributeCollection.new(
          title: "Existing title",
          readonly_field: "changed value"
        )
        subject = described_class.new_or_existing(Post, attributes, {title: "Existing title"})

        expect { subject.save }.not_to raise_error
        expect(subject.orm_record.readonly_field).to eq("original value")
      end
    end

    context "when the record is new" do
      it "sets readonly attributes normally" do
        attributes = Sprig::Seed::AttributeCollection.new(
          title: "New title",
          readonly_field: "initial value"
        )
        subject = described_class.new_or_existing(Post, attributes, {title: "New title"})

        subject.save

        expect(subject.orm_record.readonly_field).to eq("initial value")
      end
    end
  end
end

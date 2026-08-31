require "spec_helper"

RSpec.describe Sprig::Seed::Entry do
  describe ".success_log_text" do
    context "on a new record" do
      it "indicates the record was 'saved'" do
        subject = described_class.new(Post, {title: "Hello World!", content: "Stuff", sprig_id: 1}, {})
        subject.save_record

        expect(subject.success_log_text).to eq("Saved")
      end
    end

    context "on an existing record" do
      let!(:existing) do
        Post.create(
          title: "Existing title",
          content: "Existing content",
          published: false
        )
      end

      it "indicates the record was 'updated'" do
        subject = described_class.new(Post, {title: "Existing title", content: "Existing content", sprig_id: 1}, {find_existing_by: [:title]})
        subject.save_record

        expect(subject.success_log_text).to eq("Updated")
      end
    end
  end

  describe "sprig_id" do
    it "uses the explicit 4th constructor argument over any sprig_id present in attrs" do
      subject = described_class.new(Post, {title: "Hello World!", content: "Stuff", sprig_id: 1}, {}, "explicit-id")

      expect(subject.dependency_id).to eq(Sprig::Dependency.for(Post, "explicit-id").id)
    end

    it "falls back to attrs' sprig_id when no explicit argument is given" do
      subject = described_class.new(Post, {title: "Hello World!", content: "Stuff", sprig_id: 1}, {})

      expect(subject.dependency_id).to eq(Sprig::Dependency.for(Post, "1").id)
    end
  end
end

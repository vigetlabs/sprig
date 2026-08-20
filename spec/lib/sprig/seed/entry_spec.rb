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

  describe "attributes referenced by find_existing_by/delete_existing_by" do
    context "when the attribute isn't defined on the class" do
      it "raises an UnknownAttributeError from find_existing_by" do
        subject = described_class.new(Post, {title: "Hello World!", sprig_id: 1}, {find_existing_by: [:unicorn]})

        expect { subject.save_record }.to raise_error(
          Sprig::Seed::Entry::UnknownAttributeError,
          "'unicorn' is not a valid attribute for Post. find_existing_by/delete_existing_by must reference an attribute defined on the class."
        )
      end

      it "raises an UnknownAttributeError from delete_existing_by" do
        subject = described_class.new(Post, {title: "Hello World!", sprig_id: 1}, {delete_existing_by: :unicorn})

        expect { subject.before_save }.to raise_error(
          Sprig::Seed::Entry::UnknownAttributeError,
          "'unicorn' is not a valid attribute for Post. find_existing_by/delete_existing_by must reference an attribute defined on the class."
        )
      end
    end

    context "when the attribute is defined on the class but absent from this record" do
      let!(:existing) do
        Post.create(title: "Existing title", published: true, content: nil)
      end

      it "treats the missing attribute as nil instead of raising" do
        subject = described_class.new(Post, {title: "Existing title", sprig_id: 1}, {find_existing_by: [:title, :content]})

        subject.save_record

        expect(subject.record.orm_record).to eq(existing)
      end
    end
  end
end

require 'spec_helper'

describe Sprig::Seed::Entry do
  describe ".success_log_text" do
    context "on a new record" do
      it "indicates the record was 'saved'" do
        subject = described_class.new(Post, { title: "Hello World!", content: "Stuff", sprig_id: 1 }, {})
        subject.save_record

        subject.success_log_text.should == "Saved"
      end
    end

    context "on an existing record" do
      let!(:existing) do
        Post.create(
          :title      => "Existing title",
          :content    => "Existing content",
          :published  => false
        )
      end

      it "indicates the record was 'updated'" do
        subject = described_class.new(Post, { title: "Existing title", content: "Existing content", sprig_id: 1 }, { find_existing_by: [:title] })
        subject.save_record

        subject.success_log_text.should == "Updated"
      end
    end
  end
end

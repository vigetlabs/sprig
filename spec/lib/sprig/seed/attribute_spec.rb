require "spec_helper"

RSpec.describe Sprig::Seed::Attribute do
  describe "#dependencies" do
    context "with an integer sprig_id" do
      it "finds the dependency" do
        subject = described_class.new(:post_id, "<%= sprig_record(Post, 1).id %>")

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, 1)])
      end

      it "ignores whitespace around the id" do
        subject = described_class.new(:post_id, "<%= sprig_record(Post,    1    ).id %>")

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, 1)])
      end
    end

    context "with a single-quoted string sprig_id" do
      it "finds the dependency" do
        subject = described_class.new(:post_id, "<%= sprig_record(Post, 'cooldev').id %>")

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, "cooldev")])
      end

      it "ignores whitespace around the id" do
        subject = described_class.new(:post_id, "<%= sprig_record(Post,    'cooldev'    ).id %>")

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, "cooldev")])
      end
    end

    context "with a double-quoted string sprig_id" do
      it "finds the dependency" do
        subject = described_class.new(:post_id, '<%= sprig_record(Post, "cooldev").id %>')

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, "cooldev")])
      end
    end

    context "with a symbol sprig_id" do
      it "finds the dependency" do
        subject = described_class.new(:post_id, "<%= sprig_record(Post, :cooldev).id %>")

        expect(subject.dependencies).to eq([Sprig::Dependency.for(Post, "cooldev")])
      end
    end

    context "with no sprig_record reference" do
      it "returns no dependencies" do
        subject = described_class.new(:title, "Just a plain value")

        expect(subject.dependencies).to eq([])
      end
    end
  end
end

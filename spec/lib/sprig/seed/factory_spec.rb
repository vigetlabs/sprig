require "spec_helper"

RSpec.describe Sprig::Seed::Factory do
  describe "#add_seeds_to_hopper" do
    let(:hopper) { [] }

    it "pushes a Sprig::Seed::Descriptor (not an Entry) for each datasource record" do
      datasource = double("datasource", records: [{"sprig_id" => "1", "title" => "Hello"}], options: {})
      factory = described_class.new(Post, datasource, {})

      factory.add_seeds_to_hopper(hopper)

      expect(hopper.size).to eq(1)
      expect(hopper.first).to be_a(Sprig::Seed::Descriptor)
    end

    it "builds each descriptor with the factory's klass and the record's sprig_id" do
      datasource = double("datasource", records: [{"sprig_id" => "1", "title" => "Hello"}], options: {})
      factory = described_class.new(Post, datasource, {})

      factory.add_seeds_to_hopper(hopper)

      expect(hopper.first.dependency_id).to eq(Sprig::Dependency.for(Post, "1").id)
    end

    it "carries the datasource's merged options through so the materialized Entry respects them" do
      Post.create!(title: "Existing", content: "Content")
      datasource = double(
        "datasource",
        records: [{"sprig_id" => "1", "title" => "Existing", "content" => "Content"}],
        options: {find_existing_by: [:title]}
      )
      factory = described_class.new(Post, datasource, {})

      factory.add_seeds_to_hopper(hopper)
      entry = hopper.first.to_entry
      entry.save_record

      expect(entry.success_log_text).to eq("Updated")
      expect(Post.count).to eq(1)
    end
  end
end

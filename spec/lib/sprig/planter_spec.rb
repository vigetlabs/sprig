require "spec_helper"

RSpec.describe Sprig::Planter do
  describe "#sprig" do
    let(:notifier) { double("notifier", in_progress: nil, finished: nil, errors?: false) }

    before do
      allow(Sprig::ProcessNotifier).to receive(:new).and_return(notifier)
    end

    context "when planting succeeds" do
      let(:entry) { double("entry") }
      let(:seed) { double("seed", dependency_id: "a", dependencies: [], klass: Post, to_entry: entry) }

      it "materializes the entry via to_entry and drives it through the save lifecycle in order" do
        expect(entry).to receive(:before_save).ordered
        expect(entry).to receive(:save_record).ordered.and_return(true)
        expect(entry).to receive(:save_to_store).ordered
        expect(notifier).to receive(:success).with(entry).ordered

        described_class.new([seed]).sprig
      end

      it "notifies in_progress with the un-materialized seed before building the entry" do
        expect(notifier).to receive(:in_progress).with(seed)
        allow(notifier).to receive(:success)
        allow(entry).to receive(:before_save)
        allow(entry).to receive(:save_record).and_return(true)
        allow(entry).to receive(:save_to_store)

        described_class.new([seed]).sprig
      end
    end

    context "when save_record returns false" do
      let(:entry) { double("entry", before_save: nil, save_record: false) }
      let(:seed) { double("seed", dependency_id: "a", dependencies: [], klass: Post, to_entry: entry) }

      it "calls notifier.error with the materialized entry, not the seed" do
        expect(notifier).to receive(:error).with(entry)

        described_class.new([seed]).sprig
      end
    end

    context "when an exception is raised after the entry is materialized" do
      let(:entry) { double("entry") }
      let(:seed) { double("seed", dependency_id: "a", dependencies: [], klass: Post, to_entry: entry) }

      before do
        allow(entry).to receive(:before_save).and_raise(RuntimeError, "boom")
      end

      it "calls notifier.exception with the materialized entry" do
        expect(notifier).to receive(:exception).with(entry, instance_of(RuntimeError))

        described_class.new([seed]).sprig
      end
    end

    context "when to_entry itself raises, before any entry exists" do
      let(:seed) { double("seed", dependency_id: "a", dependencies: [], klass: Post) }

      before do
        allow(seed).to receive(:to_entry).and_raise(RuntimeError, "materialization failed")
      end

      it "calls notifier.exception with the un-materialized seed instead of raising a secondary error" do
        expect(notifier).to receive(:exception).with(seed, instance_of(RuntimeError))

        described_class.new([seed]).sprig
      end
    end
  end
end

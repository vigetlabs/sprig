require "spec_helper"

RSpec.describe Sprig::Planter do
  describe "#<< / #sprig" do
    let(:notifier) { double("notifier", in_progress: nil, finished: nil, errors?: false, warning: nil) }

    before do
      allow(Sprig::ProcessNotifier).to receive(:new).and_return(notifier)
    end

    def descriptor(id, deps = [], entry: double("entry"))
      double("descriptor", dependency_id: id, dependencies: deps, to_entry: entry)
    end

    def dep(id)
      double("dependency", id: id)
    end

    context "when planting succeeds" do
      let(:entry) { double("entry") }
      let(:seed) { descriptor("a", [], entry: entry) }

      it "materializes the entry via to_entry and drives it through the save lifecycle in order" do
        expect(entry).to receive(:before_save).ordered
        expect(entry).to receive(:save_record).ordered.and_return(true)
        expect(entry).to receive(:save_to_store).ordered
        expect(notifier).to receive(:success).with(entry).ordered

        planter = described_class.new
        planter.sprig { planter << seed }
      end

      it "notifies in_progress with the un-materialized seed before building the entry" do
        expect(notifier).to receive(:in_progress).with(seed)
        allow(notifier).to receive(:success)
        allow(entry).to receive(:before_save)
        allow(entry).to receive(:save_record).and_return(true)
        allow(entry).to receive(:save_to_store)

        planter = described_class.new
        planter.sprig { planter << seed }
      end
    end

    context "when save_record returns false" do
      let(:entry) { double("entry", before_save: nil, save_record: false) }
      let(:seed) { descriptor("a", [], entry: entry) }

      it "calls notifier.error with the materialized entry, not the seed" do
        expect(notifier).to receive(:error).with(entry)

        planter = described_class.new
        planter.sprig { planter << seed }
      end
    end

    context "when an exception is raised after the entry is materialized" do
      let(:entry) { double("entry") }
      let(:seed) { descriptor("a", [], entry: entry) }

      before do
        allow(entry).to receive(:before_save).and_raise(RuntimeError, "boom")
      end

      it "calls notifier.exception with the materialized entry" do
        expect(notifier).to receive(:exception).with(entry, instance_of(RuntimeError))

        planter = described_class.new
        planter.sprig { planter << seed }
      end
    end

    context "when to_entry itself raises, before any entry exists" do
      let(:seed) { descriptor("a", []) }

      before do
        allow(seed).to receive(:to_entry).and_raise(RuntimeError, "materialization failed")
      end

      it "calls notifier.exception with the un-materialized seed instead of raising a secondary error" do
        expect(notifier).to receive(:exception).with(seed, instance_of(RuntimeError))

        planter = described_class.new
        planter.sprig { planter << seed }
      end
    end

    context "ordering" do
      before do
        allow(notifier).to receive(:success)
      end

      it "plants a dependency before a dependent offered first" do
        planted = []
        parent_entry = double("parent entry", before_save: nil, save_record: true, save_to_store: nil)
        child_entry = double("child entry", before_save: nil, save_record: true, save_to_store: nil)
        allow(notifier).to receive(:success) { |entry| planted << entry }

        parent = descriptor("parent", [], entry: parent_entry)
        child = descriptor("child", [dep("parent")], entry: child_entry)

        planter = described_class.new
        planter.sprig do
          planter << child
          planter << parent
        end

        expect(planted).to eq([parent_entry, child_entry])
      end

      it "cascades correctly across more than one hop" do
        planted = []
        allow(notifier).to receive(:success) { |entry| planted << entry }

        a_entry = double("a", before_save: nil, save_record: true, save_to_store: nil)
        b_entry = double("b", before_save: nil, save_record: true, save_to_store: nil)
        c_entry = double("c", before_save: nil, save_record: true, save_to_store: nil)

        a = descriptor("a", [], entry: a_entry)
        b = descriptor("b", [dep("a")], entry: b_entry)
        c = descriptor("c", [dep("b")], entry: c_entry)

        planter = described_class.new
        planter.sprig do
          planter << c
          planter << b
          planter << a
        end

        expect(planted).to eq([a_entry, b_entry, c_entry])
      end

      it "still attempts a descriptor whose dependency failed to save, instead of leaving it stuck" do
        failing_entry = double("failing entry", before_save: nil, save_record: false)
        dependent_entry = double("dependent entry", before_save: nil, save_record: true, save_to_store: nil)
        allow(notifier).to receive(:error)
        allow(notifier).to receive(:success)

        failing = descriptor("failing", [], entry: failing_entry)
        dependent = descriptor("dependent", [dep("failing")], entry: dependent_entry)

        planter = described_class.new

        expect {
          planter.sprig do
            planter << dependent
            planter << failing
          end
        }.not_to raise_error
        expect(notifier).to have_received(:error).with(failing_entry)
        expect(notifier).to have_received(:success).with(dependent_entry)
      end
    end

    context "with a genuinely missing dependency" do
      it "raises Planter::MissingDependencyError referencing the sprig_record" do
        missing = dep(Sprig::Dependency.for(Post, "999").id)
        item = descriptor("a", [missing])

        planter = described_class.new

        expect {
          planter.sprig { planter << item }
        }.to raise_error(
          Sprig::Planter::MissingDependencyError,
          "Undefined reference to 'sprig_record(Post, 999)'"
        )
      end
    end

    context "with a circular dependency" do
      it "raises Planter::CircularDependencyError" do
        item_a = descriptor("a", [dep("b")])
        item_b = descriptor("b", [dep("a")])

        planter = described_class.new

        expect {
          planter.sprig do
            planter << item_a
            planter << item_b
          end
        }.to raise_error(Sprig::Planter::CircularDependencyError)
      end
    end

    it "never stores full descriptor references, only dependency id strings, once planted" do
      allow(notifier).to receive(:success)
      entry = double("entry", before_save: nil, save_record: true, save_to_store: nil)
      seed = descriptor("a", [], entry: entry)

      planter = described_class.new
      planter.sprig { planter << seed }

      planted = planter.instance_variable_get(:@planted)
      expect(planted.keys).to all(be_a(String))
      expect(planted.values).not_to include(seed)
    end

    context "with Sprig.configuration.spill_seed_rows_to_disk enabled" do
      before do
        Sprig.configure { |c| c.spill_seed_rows_to_disk = true }
        allow(notifier).to receive(:success)
      end

      def spillable_descriptor(id, deps = [], entry: double("entry", before_save: nil, save_record: true, save_to_store: nil))
        double("descriptor", dependency_id: id, dependencies: deps, to_entry: entry, spill_to_disk!: nil)
      end

      it "never spills a descriptor that's ready the instant it's offered" do
        ready = spillable_descriptor("a")

        planter = described_class.new
        planter.sprig { planter << ready }

        expect(ready).not_to have_received(:spill_to_disk!)
      end

      it "spills a descriptor the moment it's determined to be waiting" do
        blocked = spillable_descriptor("b", [dep("a")])

        planter = described_class.new
        planter << blocked

        expect(blocked).to have_received(:spill_to_disk!)
      end

      it "does not spill a descriptor whose dependency was already planted" do
        parent = spillable_descriptor("a")
        child = spillable_descriptor("b", [dep("a")])

        planter = described_class.new
        planter.sprig do
          planter << parent
          planter << child
        end

        expect(parent).not_to have_received(:spill_to_disk!)
        expect(child).not_to have_received(:spill_to_disk!)
      end
    end
  end
end

require "spec_helper"

RSpec.describe Sprig::RawRowStore do
  subject { described_class.instance }

  after { subject.cleanup }

  describe "#put / #fetch" do
    it "round-trips representative value types" do
      subject.reset

      row = {
        "sprig_id" => "1",
        "name" => "A name",
        "count" => 5,
        "score" => 1.5,
        "active" => true,
        "missing" => nil,
        "tags" => ["a", "b"],
        "computed" => "<%= sprig_record(Foo, 1) %>"
      }
      subject.put("some-id", row)

      expect(subject.fetch("some-id")).to eq(row)
    end

    it "stores multiple rows independently, keyed by id" do
      subject.reset

      subject.put("id-1", {"name" => "First"})
      subject.put("id-2", {"name" => "Second"})

      expect(subject.fetch("id-1")).to eq({"name" => "First"})
      expect(subject.fetch("id-2")).to eq({"name" => "Second"})
    end

    it "raises RecordNotFoundError for an unknown id" do
      subject.reset

      expect {
        subject.fetch("missing-id")
      }.to raise_error(Sprig::RawRowStore::RecordNotFoundError)
    end

    it "deletes the entry once fetched, so a second fetch of the same id raises RecordNotFoundError" do
      subject.reset
      subject.put("some-id", {"name" => "First"})

      subject.fetch("some-id")

      expect {
        subject.fetch("some-id")
      }.to raise_error(Sprig::RawRowStore::RecordNotFoundError)
    end
  end

  describe "#cleanup" do
    it "removes the temp directory" do
      subject.reset
      dir = subject.instance_variable_get(:@dir)

      subject.cleanup

      expect(Dir.exist?(dir)).to eq(false)
    end

    it "is safe to call when nothing has been reset yet" do
      expect { subject.cleanup }.not_to raise_error
    end
  end

  describe "#reset" do
    it "cleans up a previous run's temp directory before starting fresh" do
      subject.reset
      subject.put("id-1", {"name" => "First"})
      old_dir = subject.instance_variable_get(:@dir)

      subject.reset

      expect(Dir.exist?(old_dir)).to eq(false)
      expect {
        subject.fetch("id-1")
      }.to raise_error(Sprig::RawRowStore::RecordNotFoundError)
    end
  end
end

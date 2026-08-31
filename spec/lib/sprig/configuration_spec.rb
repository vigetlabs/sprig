require "spec_helper"

RSpec.describe Sprig::Configuration do
  before do
    stub_rails_root "~"
    stub_rails_env "development"
  end

  describe "#directory" do
    it "returns db/seeds/:env by default" do
      expect(subject.directory.to_path).to eq("~/db/seeds/development")
    end

    it "returns a custom directory" do
      subject.directory = "seed_files"

      expect(subject.directory.to_path).to eq("~/seed_files/development")
    end
  end

  describe "#logger" do
    it "returns an stdout logger by default" do
      logger = double("Logger")
      allow(Logger).to receive(:new).with($stdout).and_return(logger)

      expect(subject.logger).to eq(logger)
    end

    it "returns a custom logger" do
      logger = double("Logger")
      subject.logger = logger

      expect(subject.logger).to eq(logger)
    end
  end

  describe "#wrap_in_transaction" do
    it "returns true by default" do
      expect(subject.wrap_in_transaction).to eq(true)
    end

    it "returns a custom value if provided" do
      custom_value = false
      subject.wrap_in_transaction = custom_value

      expect(subject.wrap_in_transaction).to eq(custom_value)
    end
  end

  describe "#spill_seed_rows_to_disk" do
    it "is false by default" do
      expect(subject.spill_seed_rows_to_disk).to eq(false)
    end

    it "returns a custom value" do
      subject.spill_seed_rows_to_disk = true

      expect(subject.spill_seed_rows_to_disk).to eq(true)
    end
  end
end

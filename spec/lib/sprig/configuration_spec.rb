require 'spec_helper'

RSpec.describe Sprig::Configuration do
  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  describe "#directory" do
    it "returns db/seeds/:env by default" do
      expect(subject.directory.to_path).to eq('~/db/seeds/development')
    end

    it "returns a custom directory" do
      subject.directory = 'seed_files'

      expect(subject.directory.to_path).to eq('~/seed_files/development')
    end
  end

  describe "#logger" do
    it "returns an stdout logger by default" do
      logger = double('Logger')
      allow(Logger).to receive(:new).with($stdout).and_return(logger)

      expect(subject.logger).to eq(logger)
    end

    it "returns a custom logger" do
      logger = double('Logger')
      subject.logger = logger

      expect(subject.logger).to eq(logger)
    end
  end
end

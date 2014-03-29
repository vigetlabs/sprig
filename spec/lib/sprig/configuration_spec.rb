require 'spec_helper'

describe Sprig::Configuration do
  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  describe "#directory" do
    it "returns db/seeds/:env by default" do
      subject.directory.to_path.should == '~/db/seeds/development'
    end

    it "returns a custom directory" do
      subject.directory = 'seed_files'

      subject.directory.to_path.should == '~/seed_files/development'
    end
  end

  describe "#logger" do
    it "returns an stdout logger by default" do
      logger = double('Logger')
      Logger.stub(:new).with($stdout).and_return(logger)

      subject.logger.should == logger
    end

    it "returns a custom logger" do
      logger = double('Logger')
      subject.logger = logger

      subject.logger.should == logger
    end
  end
end

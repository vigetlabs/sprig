require 'spec_helper'

describe Sprig do
  let(:configuration) { double('Configuration') }

  before do
    Sprig::Configuration.stub(:new).and_return(configuration)
  end

  describe ".configuration" do
    context "when there is not yet a Configuration instance" do
      it "returns a new Configuration instance" do
        described_class.configuration.should == configuration
      end
    end

    context "when there is an existing Configuration instance" do
      before do
        described_class.configuration
      end

      it "returns the existing Configuration instance" do
        new_configuration = double('Configuration')
        Sprig::Configuration.stub(:new).and_return(new_configuration)

        described_class.configuration.should == configuration
      end
    end
  end

  describe ".reset_configuration" do
    before do
      described_class.configuration
    end

    it "clears the existing configuration" do
      described_class.reset_configuration
      new_configuration = double('Configuration')
      Sprig::Configuration.stub(:new).and_return(new_configuration)

      described_class.configuration.should == new_configuration
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.should == configuration
      end
    end
  end
end

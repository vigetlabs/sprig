require 'spec_helper'

describe Sprig do
  let(:configuration) { double('Configuration') }

  before do
    Sprig::Configuration.stub(:new).and_return(configuration)
  end

  describe '#adapter' do
    let(:supported_adapters) do
      %i(active_record mongoid)
    end

    it { expect(described_class).to respond_to(:adapter).with(0).arguments }

    it { expect(supported_adapters).to include described_class.adapter }
  end

  describe '#adapter=' do
    let(:value) { :mongo_mapper }

    it { expect(described_class).to respond_to(:adapter=).with(1).argument }

    it 'changes the value' do
      previous_value = described_class.adapter

      expect { described_class.adapter = value }.to change(described_class, :adapter).to(value)

      described_class.adapter = previous_value
    end
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

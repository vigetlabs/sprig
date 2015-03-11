require 'spec_helper'

describe Sprig do
  let(:configuration) { double('Configuration') }

  before do
    Sprig::Configuration.stub(:new).and_return(configuration)
  end

  describe '.adapter' do
    it { expect(described_class).to respond_to(:adapter).with(0).arguments }

    it { expect(described_class.adapter).not_to be nil }
  end

  describe '.adapter=' do
    let(:value) { :mongo_mapper }

    around(:each) do |example|
      previous_value = described_class.adapter

      example.run

      described_class.adapter = previous_value
    end

    it { expect(described_class).to respond_to(:adapter=).with(1).argument }

    it 'changes the value' do
      expect { described_class.adapter = value }.to change(described_class, :adapter).to(value)
    end
  end

  describe '.adapter_model_class' do
    let(:expected_class) do
      case Sprig.adapter
      when :active_record
        ActiveRecord::Base
      when :mongoid
        Mongoid::Document
      end
    end

    before(:each) { described_class.instance_variable_set(:@adapter_model_class, nil) }

    it { expect(described_class).to respond_to(:adapter_model_class).with(0).arguments }

    it { expect(described_class.adapter_model_class).to be expected_class }

    describe 'with an unrecognized adapter' do
      let(:value) { :mongo_mapper }

      it 'raises an error' do
        allow(described_class).to receive(:adapter).and_return(value)

        expect { described_class.adapter_model_class }.to raise_error(/unknown model class/i)
      end
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

require 'spec_helper'

describe Sow::Directive do

  describe "#klass" do
    context "given a class" do
      subject { described_class.new(Post) }

      its(:klass) { should == Post }
    end

    context "given options with a class" do
      subject { described_class.new(:class => Post) }

      its(:klass) { should == Post }
    end

    context "given options without a class" do
      subject { described_class.new(:source => 'source') }

      it "raises and argument error" do
        expect {
          subject.klass
        }.to raise_error(
          ArgumentError,
         'Sow::Directive must provide a class'
        )
      end
    end
  end

  describe "#options" do
    context "given no options" do
      subject { described_class.new(Post) }

      its(:options) { should == {} }
    end

    context "given options" do
      subject { described_class.new(:class => Post, :source => 'source') }

      its(:options) { should == { :source => 'source' } }
    end
  end

  describe "#data" do
    let(:datasource) { double('datasource') }
    let(:data_hash)  { double('data_hash') }

    subject { described_class.new(:class => Post, :source => 'source') }

    before do
      datasource.stub_chain(:to_hash, :with_indifferent_access).and_return(data_hash)

      Sow::Data::Source.stub(:new).with('posts', { :source => 'source' }).and_return(datasource)
    end

    it "returns data from the datasource" do
      subject.data.should == data_hash
    end

  end

  describe "#datasource" do
    let(:datasource) { double('datasource') }

    subject { described_class.new(:class => Post, :source => 'source') }

    before do
      Sow::Data::Source.stub(:new).with('posts', { :source => 'source' }).and_return(datasource)
    end

    it "returns a sow data source" do
      subject.datasource.should == datasource
    end
  end
end

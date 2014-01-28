require 'spec_helper'

describe Sprig::Directive do

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
          'Sprig::Directive must be instantiated with an '\
          'ActiveRecord subclass or a Hash with :class defined'
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

  describe "#datasource" do
    let(:datasource) { double('datasource') }

    subject { described_class.new(:class => Post, :source => 'source') }

    before do
      Sprig::Source.stub(:new).with('posts', { :source => 'source' }).and_return(datasource)
    end

    it "returns a sprig data source" do
      subject.datasource.should == datasource
    end
  end
end

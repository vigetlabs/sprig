require 'spec_helper'

RSpec.describe Sprig::Directive do

  module Users
    class Admin < User
    end
  end

  describe "#klass" do
    context "given a class" do
      subject { described_class.new(Post) }

      it "returns the class" do
        expect(subject.klass).to eq(Post)
      end
    end

    context "given a class within a module" do
      subject { described_class.new(Users::Admin) }

      it "returns the full class" do
        expect(subject.klass).to eq(Users::Admin)
      end
    end

    context "given options with a class" do
      subject { described_class.new(:class => Post) }

      it "returns the class" do
        expect(subject.klass).to eq(Post)
      end
    end

    context "given options without a class" do
      subject { described_class.new(:source => 'source') }

      it "raises and argument error" do
        expect {
          subject.klass
        }.to raise_error(
          ArgumentError,
          'Sprig::Directive must be instantiated with a(n) '\
          "#{Sprig.adapter_model_class} class or a Hash with :class defined"
        )
      end
    end
  end

  describe "#options" do
    context "given no options" do
      subject { described_class.new(Post) }

      it "returns an empty hash" do
        expect(subject.options).to eq({})
      end
    end

    context "given options" do
      subject { described_class.new(:class => Post, :source => 'source') }

      it "returns a the options" do
        expect(subject.options).to eq(:source => 'source')
      end
    end
  end

  describe "#datasource" do
    let(:datasource) { double('datasource') }

    context "with a class" do
      subject { described_class.new(:class => Post, :source => 'source') }

      before do
        allow(Sprig::Source).to receive(:new).with('posts', { :source => 'source' }).and_return(datasource)
      end

      it "returns a sprig data source" do
        expect(subject.datasource).to eq(datasource)
      end
    end

    context "with a class within a module" do
      subject { described_class.new(Users::Admin) }

      it "passes the correct path to Source" do
        expect(Sprig::Source).to receive(:new).with("users_admins", {})

        subject.datasource
      end
    end
  end
end

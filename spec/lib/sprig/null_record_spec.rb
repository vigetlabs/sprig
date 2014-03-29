require 'spec_helper'

describe Sprig::NullRecord do
  let(:error_msg) { 'Something bad happened.' }
  subject { described_class.new(error_msg) }

  describe "#new" do
    it "logs an error upon initialization" do
      Sprig.logger.should_receive(:error).with("\e[31m#{error_msg} (Substituted with NullRecord)\e[0m")

      subject
    end
  end

  describe "#method_missing" do
    it "returns nil for undefined method calls" do
      subject.enhance_your_calm.should == nil
    end
  end

  it_behaves_like "a logging entity" do
    subject! { described_class.new(error_msg) }
  end
end

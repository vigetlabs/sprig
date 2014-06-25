require 'spec_helper'

describe Sprig::Parser::Base do
  describe "#parse" do
    it "enforces implementation in a subclass" do
      expect {
        described_class.new('data').parse
      }.to raise_error(NotImplementedError)
    end
  end
end

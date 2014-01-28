require 'spec_helper'

describe Sprig::DirectiveList do

  describe "#add_seeds_to_hopper" do
    let(:hopper)       { Array.new }
    let(:directive)    { double('directive') }
    let(:seed_factory) { double('seed_factory') }

    subject { described_class.new(Post) }

    before do
      Sprig::Directive.stub(:new).with(Post).and_return(directive)

      Sprig::Seed::Factory.stub(:new_from_directive).with(directive).and_return(seed_factory)
    end

    it "builds seeds from directives and adds to the given array" do
      seed_factory.should_receive(:add_seeds_to_hopper).with(hopper)

      subject.add_seeds_to_hopper(hopper)
    end
  end
end

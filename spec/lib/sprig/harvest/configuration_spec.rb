require 'spec_helper'

describe Sprig::Harvest::Configuration do
  subject { described_class.new }

  before do
    stub_rails_root
  end

  describe "#env" do
    context "from a fresh configuration" do
      its(:env) { should == Rails.env }
    end
  end

  describe "#env=" do
    context "when given nil" do
      it "does not change the env" do
        subject.env = nil

        subject.env.should_not == nil
      end
    end

    context "given a non-nil value" do
      let(:input) { ' ShaBOOSH' }

      it "formats the given value and then sets the environment" do
        subject.env = input

        subject.env.should == 'shaboosh'
      end

      context "and the corresponding seeds folder does not yet exist" do
        after do
          FileUtils.remove_dir('./spec/fixtures/db/seeds/shaboosh')
        end

        it "creates the seeds folder" do
          subject.env = input

          File.directory?('./spec/fixtures/db/seeds/shaboosh').should == true
        end
      end
    end
  end

  describe "#classes" do
    context "from a fresh configuration" do
      its(:classes) { should == ActiveRecord::Base.descendants }
    end
  end

  describe "#classes=" do
    context "when given nil" do
      it "does not set classes to nil" do
        subject.classes = nil

        subject.classes.should_not == nil
      end
    end

    context "when given an array of classes" do
      context "where one or more classes are not subclasses of ActiveRecord::Base" do
        it "raises an error" do
          expect {
            subject.classes = [Comment, Sprig::Harvest::Model]
          }.to raise_error ArgumentError, 'Cannot create a seed file for Sprig::Harvest::Model because it is not an ActiveRecord::Base-descendant.'
        end
      end

      context "where all classes are subclasses of ActiveRecord::Base" do
        it "sets classes to the given input" do
          subject.classes = [Comment, Post]

          subject.classes.should == [Comment, Post]
        end
      end
    end

    context "when given a string" do
      context "where one or more classes are not subclasses of ActiveRecord::Base" do
        it "raises an error" do
          expect {
            subject.classes = 'Sprig::Harvest::Model'
          }.to raise_error ArgumentError, 'Cannot create a seed file for Sprig::Harvest::Model because it is not an ActiveRecord::Base-descendant.'
        end
      end

      context "where all classes are subclasses of ActiveRecord::Base" do
        it "sets classes to the parsed input" do
          subject.classes = ' comment, post'

          subject.classes.should == [Comment, Post]
        end
      end
    end
  end
end

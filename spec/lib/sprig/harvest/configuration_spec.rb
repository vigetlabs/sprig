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
      its(:classes) { should == ActiveRecord::Base.subclasses }
    end
  end

  describe "#classes=" do
    context "when given nil" do
      before { subject.classes = nil }

      its(:classes) { should_not == nil }
    end

    context "when given an array of classes" do
      before { subject.classes = [Comment, Post] }

      its(:classes) { should == [Comment, Post] }
    end

    context "when given a string" do
      before { subject.classes = ' comment, post' }

      its(:classes) {should == [Comment, Post] }
    end
  end

  describe "#limit=" do
    context "given a string" do
      context "that results in a 0" do
        it "raises an error" do
          expect {
            subject.limit = 'wow'
          }.to raise_error ArgumentError, 'Limit can only be set to an integer above 0 (received 0)'
        end
      end

      context "that results in a non-0 integer" do
        before { subject.limit = ' 25' }

        its(:limit) { should == 25 }
      end
    end

    context "given an integer" do
      before { subject.limit = 10 }

      its(:limit) { should == 10 }
    end
  end

  describe "#ignored_attrs=" do
    context "when given nil" do
      before { subject.classes = nil }

      its(:ignored_attrs) { should_not == nil }
    end

    context "when given an array of ignored_attrs" do
      before { subject.ignored_attrs = [:shaka, ' laka '] }

      its(:ignored_attrs) { should == ['shaka', 'laka'] }
    end

    context "when given a string" do
      before { subject.ignored_attrs = ' shaka, laka' }

      its(:ignored_attrs) { should == ['shaka', 'laka'] }
    end
  end

  describe "#ignored_attrs" do
    context "on a fresh configuration" do
      its(:ignored_attrs) { should == [] }
    end
  end

  describe "#models=" do
    context "given an array containing a valid class" do
      let(:config) { double('Sprig::Harvest::ModelConfig') }

      it "creates a new model config and stores it in model configurations" do
        Sprig::Harvest::ModelConfig.stub(:new).with(User).and_return(config)

        subject.models = [User]

        subject.model_configurations.should == [config]
      end
    end
    
    context "given an array containain a hash" do
      let(:config) { double('Sprig::Harvest::ModelConfig') }


      let(:parsed_hash) do
        {
          :limit         => 5,
          :ignored_attrs => [:created_at, :updated_at]
        }
      end

      let(:hash) do
        { :class => User }.merge(parsed_hash)
      end

      it "creates a new model config and stores it in model configurations" do
        Sprig::Harvest::ModelConfig.stub(:new).with(User, parsed_hash).and_return(config)

        subject.models = [hash]

        subject.model_configurations.should == [config]
      end
    end
  end

  describe "#model_configurations" do
    context "on a fresh config" do
      it "contains an array of model configs for each ActiveRecord::Base subclass" do
        configs = subject.model_configurations
        klasses = configs.map(&:klass)

        configs.size.should == ActiveRecord::Base.subclasses.size

        ActiveRecord::Base.subclasses.each { |klass| klasses.include?(klass).should == true }
      end
    end

    context "when classes have been set" do
      before do
        subject.classes = [User, Post]
      end

      it "contains an array of model configs for each of the previous set classes" do
        configs = subject.model_configurations
        klasses = configs.map(&:klass)

        configs.size.should == 2

        [User, Post].each { |klass| klasses.include?(klass).should == true }
      end
    end
  end
end

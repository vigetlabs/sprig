require 'spec_helper'

describe Sprig::Harvest do
  before do
    stub_rails_root
    stub_rails_env('dreamland')
  end

  describe ".reap" do
    let(:seed_file) { double('Sprig::Harvest::SeedFile', :write => 'such seeds') }

    before do
      Sprig::Harvest::SeedFile.stub(:new).and_return(seed_file)
    end

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    it "generates a seed file for each class" do
      seed_file.should_receive(:write).exactly(3).times

      subject.reap
    end

    context "given a reap config file in the options hash" do
      let!(:bo)        { User.create(:first_name => 'Bo',    :last_name => 'Janglez') }
      let!(:billy)     { User.create(:first_name => 'Billy', :last_name => 'Janglez') }
      let!(:butch)     { User.create(:first_name => 'Butch', :last_name => 'Jillio') }
      let(:file)       { './spec/fixtures/db/seeds/reap_config.rb' }

      before { subject.reap(:file => file) }

      its(:env)           { should == 'dreamland' }
      its(:limit)         { should == 30 }
      its(:ignored_attrs) { should == ['created_at', 'updated_at'] }

      it "appropriately sets model-specific configurations" do
        user_config    = subject.model_configurations.find { |config| config.klass == User }
        post_config    = subject.model_configurations.find { |config| config.klass == Post }
        comment_config = subject.model_configurations.find { |config| config.klass == Comment }

        user_config.collection.should    == [bo, billy]
        user_config.limit.should         == 10
        user_config.ignored_attrs.should == ['type'] + ['created_at', 'updated_at']

        post_config.limit.should         == 20
        post_config.ignored_attrs.should == ['created_at', 'updated_at']

        comment_config.limit.should         == 30
        comment_config.ignored_attrs.should == ['created_at', 'updated_at']
      end
    end

    context "when passed an environment in the options hash" do
      context "in :env" do
        it "sets the environment" do
          subject.reap(:env => 'integration')
          subject.env.should == 'integration'
        end
      end

      context "in 'ENV'" do
        it "sets the environment" do
          subject.reap('ENV' => ' Integration')
          subject.env.should == 'integration'
        end
      end
    end

    context "when passed a set of models in the options hash" do
      context "in :models" do
        it "sets classes to the given models" do
          subject.reap(:models => [User, Post])
          subject.classes.should == [User, Post]
        end
      end

      context "in MODELS" do
        it "sets classes to the given models" do
          subject.reap('MODELS' => ' User, Post')
          subject.classes.should == [User, Post]
        end
      end
    end

    context "when passed an limit in the options hash" do
      context "in :limit" do
        it "sets the limit" do
          subject.reap(:limit => 10)
          subject.limit.should == 10
        end
      end

      context "in LIMIT" do
        it "sets the limit" do
          subject.reap('LIMIT' => ' 10')
          subject.limit.should == 10
        end
      end
    end

    context "when passed a list of ignored attributes in the options hash" do
      context "in :ignored_attrs" do
        it "sets ignored attributes" do
          subject.reap(:ignored_attrs => [:willy, :nilly])
          subject.ignored_attrs.should == ['willy', 'nilly']
        end
      end

      context "in IGNORED_ATTRS" do
        it "sets ignored attributes" do
          subject.reap('IGNORED_ATTRS' => ' willy, nilly')
          subject.ignored_attrs.should == ['willy', 'nilly']
        end
      end
    end
  end

  describe ".configure" do
    describe "setting env" do
      before do
        subject.configure do |config|
          config.env = 'dreamland'
        end
      end

      its(:env) { should == 'dreamland' }
    end

    describe "setting classes" do
      before do
        subject.configure do |config|
          config.classes = [User, Post]
        end
      end

      its(:classes) { should == [User, Post] }
    end

    describe "setting limit" do
      before do
        subject.configure do |config|
          config.limit = 25
        end
      end

      its(:limit) { should == 25 }
    end

    describe "setting ignored attributes" do
      before do
        subject.configure do |config|
          config.ignored_attrs = [:boom, :shaka, :laka]
        end
      end

      its(:ignored_attrs) { should == ['boom', 'shaka', 'laka'] }
    end

    describe "setting models" do
      context "with an array of model-specific configurations" do
        let!(:user1) { User.create(:first_name => 'Bo',    :last_name => 'Janglez') }
        let!(:user2) { User.create(:first_name => 'Billy', :last_name => 'Janglez') }

        context "including a class" do
          before do
            subject.configure do |config|
              config.models = [User]
            end
          end

          it "creates the appropriate model configuration" do
            config = subject.model_configurations.first

            config.collection.should    == [user1, user2]
            config.limit.should         == subject.limit
            config.ignored_attrs.should == subject.ignored_attrs
          end
        end

        context "including a hash of configurables" do
          let(:options) do
            {
              :collection    => User.where(:first_name => 'Bo'),
              :limit         => 5,
              :ignored_attrs => [:willy, :nilly]
            }
          end

          let(:model_config_input) do
            { :class => User }.merge(options)
          end

          before do
            subject.configure do |config|
              config.models = [model_config_input]
            end
          end

          it "creates the appropriate model configuration" do
            config = subject.model_configurations.first

            config.collection.should    == [user1]
            config.limit.should         == 5
            config.ignored_attrs.should == ['willy', 'nilly'] + subject.ignored_attrs
          end
        end
      end
    end
  end
end

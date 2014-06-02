require 'spec_helper'

describe Sprig::Harvest do
  describe ".reap" do
    let(:seed_file) { double('Sprig::Harvest::SeedFile', :write => 'such seeds') }

    before do
      stub_rails_root
      stub_rails_env('dreamland')
      Sprig::Harvest::SeedFile.stub(:new).and_return(seed_file)
    end

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    it "generates a seed file for each class" do
      seed_file.should_receive(:write).exactly(3).times

      subject.reap
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

    context "when passed a set of classes in the options hash" do
      context "in :classes" do
        it "sets the classes" do
          subject.reap(:classes => [User, Post])
          subject.classes.should == [User, Post]
        end
      end

      context "sets the classes" do
        it "passes the value to its configuration" do
          subject.reap('CLASSES' => 'User, Post')
          subject.classes.should == [User, Post]
        end
      end
    end
  end
end

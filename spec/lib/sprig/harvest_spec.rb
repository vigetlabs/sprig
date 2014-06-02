require 'spec_helper'

describe Sprig::Harvest do
  describe ".reap" do
    let(:seed_file) { double('Sprig::Harvest::SeedFile', write: 'such seeds') }

    before do
      stub_rails_root
      stub_rails_env('dreamland')

      ActiveRecord::Base.stub(:descendants).and_return([User, Post, Comment])
      Sprig::Harvest::SeedFile.stub(:new).and_return(seed_file)
    end

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    it "generates a seed file for each AR-backed model in the application" do
      seed_file.should_receive(:write).exactly(3).times

      subject.reap
    end

    context "when passed an environment in the options hash" do
      context "and the seeds folder does not exist for the given environment" do
        after do
          FileUtils.remove_dir('./spec/fixtures/db/seeds/integration')
        end

        it "creates the seeds folder" do
          subject.reap(env: 'integration')

          File.directory?('./spec/fixtures/db/seeds/integration').should == true
        end

        it "sets Harvest::Sprig's environment" do
          subject.reap(env: 'integration')

          subject.env.should == 'integration'
        end
      end

      context "and a seeds folder exists for the given environment" do
        around do |example|
          setup_seed_folder('./spec/fixtures/db/seeds/integration', &example)
        end

        it "sets Harvest::Sprig's environment" do
          subject.reap(env: 'integration')

          subject.env.should == 'integration'
        end
      end
    end

    context "when passed a set of classes in the options hash" do
      context "where one or more classes are not subclasses of ActiveRecord::Base" do
        it "raises an error" do
          expect {
            subject.reap(classes: [Comment, Sprig::Harvest::Model])
          }.to raise_error ArgumentError, 'Cannot create a seed file for Sprig::Harvest::Model because it is not an ActiveRecord::Base-descendant.'
        end
      end

      context "where all classes are subclasses of ActiveRecord::Base" do
        before do
          Sprig::Harvest::Model.class_variable_set(:@@all, nil) # Reset cached @@all
        end

        it "generates a seed file for each of the given classes" do
          seed_file.should_receive(:write).exactly(2).times

          subject.reap(classes: [Comment, Post])
        end
      end
    end
  end
end

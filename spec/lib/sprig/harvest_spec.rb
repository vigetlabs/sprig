require 'spec_helper'

describe Sprig::Harvest do
  describe ".reap" do
    let(:seed_file) { double('Sprig::Harvest::SeedFile', write: 'such seeds') }

    before do
      stub_rails_root
      stub_rails_env('dreamland')

      ActiveRecord::Base.stub(:descendants).and_return([User, Post, Comment])
    end

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    it "generates a seed file for each AR-backed model in the application" do
      Sprig::Harvest::SeedFile.stub(:new).and_return(seed_file)

      seed_file.should_receive(:write).exactly(3).times

      subject.reap
    end
  end
end

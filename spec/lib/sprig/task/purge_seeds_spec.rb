require 'spec_helper'

describe Sprig::Task::PurgeSeeds do
  subject { described_class.new }

  before do
    stub_rails_root
  end

  describe "#perform" do
    context "when no seed files are present" do
      it "aborts with an error message" do
        log_should_receive :error, with: 'No seed files to delete. Aborting.'

        expect {
          subject.perform
        }.to raise_error SystemExit
      end
    end

    context "when seed files are present" do
      around do |example|
        load_seeds('posts.yml', &example)
      end

      context "and deletion is not confirmed" do
        it "aborts with an error message" do
          log_should_receive :error, with: 'Purge aborted.'

          expect {
            fake_stdin_gets 'no' do
              subject.perform
            end
          }.to raise_error SystemExit
        end
      end

      context "and deletion is confirmed" do
        it "deletes the seed files" do
          Dir.glob("#{Sprig.configuration.directory}/*").should_not be_empty

          fake_stdin_gets 'yes' do
            subject.perform
          end

          Dir.glob("#{Sprig.configuration.directory}/*").should be_empty
        end
      end
    end
  end
end

require 'spec_helper'

describe "db:seed:purge" do
  include_context "rake"

  let(:task) { double('Sprig::Task::PurgeSeeds') }

  before do
    Sprig::Task::PurgeSeeds.stub(:new).and_return(task)
  end

  it "purges seed files" do
    task.should_receive(:perform)
    subject.invoke
  end
end

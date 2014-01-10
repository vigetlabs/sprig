require 'spec_helper'

describe "Configurating Sow" do
  let(:configuration) { Sow.configuration }

  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  it "can set the directory" do
    configuration.directory.to_path.should == '~/db/seeds/development'

    Sow.configure do |c|
      c.directory = 'seed_files'
    end

    configuration.directory.to_path.should == '~/seed_files/development'
  end
end

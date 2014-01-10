require 'spec_helper'

describe "Configurating Sow" do
  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  it "can set the directory" do
    Sow.configuration.directory.to_path.should == '~/db/seeds/development'

    Sow.configure do |c|
      c.directory = 'seed_files'
    end

    Sow.configuration.directory.to_path.should == '~/seed_files/development'
  end

  it "can reset the configuration" do
    Sow.configure do |c|
      c.directory = 'seed_files'
    end

    Sow.configuration.directory.to_path.should == '~/seed_files/development'

    Sow.reset_configuration

    Sow.configuration.directory.to_path.should == '~/db/seeds/development'
  end
end

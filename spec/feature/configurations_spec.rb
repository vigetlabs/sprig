require 'spec_helper'

describe "Configurating Sprig" do
  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  it "can set the directory" do
    Sprig.configuration.directory.to_path.should == '~/db/seeds/development'

    Sprig.configure do |c|
      c.directory = 'seed_files'
    end

    Sprig.configuration.directory.to_path.should == '~/seed_files/development'
  end

  it "can reset the configuration" do
    Sprig.configure do |c|
      c.directory = 'seed_files'
    end

    Sprig.configuration.directory.to_path.should == '~/seed_files/development'

    Sprig.reset_configuration

    Sprig.configuration.directory.to_path.should == '~/db/seeds/development'
  end
end

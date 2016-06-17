require 'spec_helper'

RSpec.describe "Configurating Sprig" do
  before do
    stub_rails_root '~'
    stub_rails_env 'development'
  end

  it "can set the directory" do
    expect(Sprig.configuration.directory.to_path).to eq('~/db/seeds/development')

    Sprig.configure do |c|
      c.directory = 'seed_files'
    end

    expect(Sprig.configuration.directory.to_path).to eq('~/seed_files/development')
  end

  it "can reset the configuration" do
    Sprig.configure do |c|
      c.directory = 'seed_files'
    end

    expect(Sprig.configuration.directory.to_path).to eq('~/seed_files/development')

    Sprig.reset_configuration

    expect(Sprig.configuration.directory.to_path).to eq('~/db/seeds/development')
  end
end

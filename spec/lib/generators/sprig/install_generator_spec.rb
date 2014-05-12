require 'spec_helper'
require 'generators/sprig/install_generator'

describe Sprig::Generators::InstallGenerator do
  destination File.expand_path("../../tmp", __FILE__)

  before do
    prepare_destination
    run_generator
  end

  it "creates empy db/seeds directory" do
    assert_directory "db/seeds"
  end

  it "creates empty seed environment directories" do
    [
      :development,
      :test,
      :integration,
      :staging,
      :production
    ].each do |env|
      assert_directory "db/seeds/#{env}"
    end
  end
end

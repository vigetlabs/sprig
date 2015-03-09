require 'spec_helper'
require 'generators/sprig/install_generator'

describe Sprig::Generators::InstallGenerator, type: :generator do
  destination File.expand_path("../../tmp", __FILE__)

  before do
    stub_rails_root
    prepare_destination
    run_generator
  end

  it "creates empty db/seeds directory" do
    assert_directory "db/seeds"
  end

  it "creates empty seed environment directories" do
    [
      :development,
      :test,
      :production
    ].each do |env|
      assert_directory "db/seeds/#{env}"
    end
  end
end


# Generator arguments are set on a class basis. We need to open
# a new describe block to make these examples work.

describe Sprig::Generators::InstallGenerator, type: :generator do
  context "with arguments" do
    destination File.expand_path("../../tmp", __FILE__)
    arguments %w(development test integration)

    before do
      stub_rails_root
      prepare_destination
      run_generator
    end

    it "creates empty seed directories from arguments" do
      [
        :development,
        :test,
        :integration
      ].each do |env|
        assert_directory "db/seeds/#{env}"
      end

      [
        :production
      ].each do |env|
        assert_no_directory "db/seeds/#{env}"
      end
    end
  end
end

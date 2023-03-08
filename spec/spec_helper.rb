ENV["RAILS_ENV"] ||= 'test'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start "rails"

require "rails"
require "webmock"
require "vcr"
require "pry"
require "generator_spec"

require "sprig"
include Sprig::Helpers

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|file| require file}

RSpec.configure do |c|
  c.include ColoredText
  c.include LoggerMock

  c.disable_monkey_patching!

  c.order = :random

  c.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  c.after(:each) do
    Sprig.reset_configuration
  end
end

VCR.configure do |c|
  c.configure_rspec_metadata!
  c.cassette_library_dir = 'spec/fixtures/cassettes'
  c.hook_into :webmock
end

# ActiveRecord (via SQlite3)
begin
  require 'active_record'
  require 'sqlite3'

  Sprig.adapter = :active_record
rescue LoadError; end

# Mongoid
begin
  require 'mongoid'

  Sprig.adapter = :mongoid
rescue LoadError; end

# Require model files.
Dir[File.dirname(__FILE__) + "/fixtures/models/#{Sprig.adapter}/*.rb"].each {|file| require file}

require "adapters/#{Sprig.adapter}.rb"

# Helpers
#
# Setup fake `Rails.root`
def stub_rails_root(path='./spec/fixtures')
  allow(Rails).to receive(:root).and_return(Pathname.new(path))
end

# Setup fake `Rails.env`
def stub_rails_env(env='development')
  allow(Rails).to receive(:env).and_return(env)
end

# Copy and Remove Seed files around a spec
def load_seeds(*files, &block)
  env = Rails.env
  prepare_seeds(env, *files, &block)
end

# Copy and Remove shared seed files around a spec
def load_shared_seeds(*files, &block)
  prepare_seeds('shared', *files, &block)
end

def prepare_seeds(directory, *files, &block)
  `cp -R ./spec/fixtures/seeds/#{directory}/files ./spec/fixtures/db/seeds/#{directory}`

  files.each do |file|
    `cp ./spec/fixtures/seeds/#{directory}/#{file} ./spec/fixtures/db/seeds/#{directory}`
  end

  block.call

  `rm -R ./spec/fixtures/db/seeds/#{directory}/files`

  files.each do |file|
    `rm ./spec/fixtures/db/seeds/#{directory}/#{file}`
  end
end

def fake_stdin_gets(input)
  begin
    $stdin = double('STDIN', gets: input)
    yield
  ensure
    $stdin = STDIN
  end
end

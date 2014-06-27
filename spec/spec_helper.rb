ENV["RAILS_ENV"] ||= 'test'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start "rails"

require "rails"
require "active_record"
require "database_cleaner"
require "webmock"
require "vcr"
require "pry"
require "generator_spec"

require "sprig"
include Sprig::Helpers

Dir[File.dirname(__FILE__) + '/fixtures/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|file| require file}

RSpec.configure do |c|
  c.include ColoredText
  c.include LoggerMock

  c.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  c.before(:each) do
    DatabaseCleaner.start
  end

  c.after(:each) do
    DatabaseCleaner.clean

    Sprig.reset_configuration
  end
end

VCR.configure do |c|
  c.configure_rspec_metadata!
  c.cassette_library_dir = 'spec/fixtures/cassettes'
  c.hook_into :webmock
end

# Database
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "spec/db/activerecord.db")

User.connection.execute "DROP TABLE IF EXISTS users;"
User.connection.execute "CREATE TABLE users (id INTEGER PRIMARY KEY , first_name VARCHAR(255), last_name VARCHAR(255), type VARCHAR(255));"

Post.connection.execute "DROP TABLE IF EXISTS posts;"
Post.connection.execute "CREATE TABLE posts (id INTEGER PRIMARY KEY AUTOINCREMENT, title VARCHAR(255), content VARCHAR(255), photo VARCHAR(255), published BOOLEAN , user_id INTEGER);"

Comment.connection.execute "DROP TABLE IF EXISTS comments;"
Comment.connection.execute "CREATE TABLE comments (id INTEGER PRIMARY KEY , post_id INTEGER, body VARCHAR(255));"

Tag.connection.execute "DROP TABLE IF EXISTS tags;"
Tag.connection.execute "CREATE TABLE tags (id INTEGER PRIMARY KEY , name VARCHAR(255));"

Tag.connection.execute "DROP TABLE IF EXISTS posts_tags;"
Tag.connection.execute "CREATE TABLE posts_tags (id INTEGER PRIMARY KEY , post_id INTEGER, tag_id INTEGER);"

# Helpers
#
# Setup fake `Rails.root`
def stub_rails_root(path='./spec/fixtures')
  Rails.stub(:root).and_return(Pathname.new(path))
end

# Setup fake `Rails.env`
def stub_rails_env(env='development')
  Rails.stub(:env).and_return(env)
end

# Copy and Remove Seed files around a spec
def load_seeds(*files)
  env = Rails.env

  `cp -R ./spec/fixtures/seeds/#{env}/files ./spec/fixtures/db/seeds/#{env}`

  files.each do |file|
    `cp ./spec/fixtures/seeds/#{env}/#{file} ./spec/fixtures/db/seeds/#{env}`
  end

  yield

  `rm -R ./spec/fixtures/db/seeds/#{env}/files`

  files.each do |file|
    `rm ./spec/fixtures/db/seeds/#{env}/#{file}`
  end
end

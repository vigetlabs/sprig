require "database_cleaner"

RSpec.configure do |c|
  c.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
    DatabaseCleaner[:mongoid].clean_with(:truncation)
  end

  c.before(:each) do
    DatabaseCleaner[:mongoid].start
  end

  c.after(:each) do
    DatabaseCleaner[:mongoid].clean
  end
end

# Datastore
Mongoid.load!(File.join File.dirname(__FILE__), 'mongoid.yml')

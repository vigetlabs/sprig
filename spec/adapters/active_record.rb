require "database_cleaner"

RSpec.configure do |c|
  c.before(:suite) do
    DatabaseCleaner[:active_record].strategy = :transaction
    DatabaseCleaner[:active_record].clean_with(:truncation)
  end

  c.before(:each) do
    DatabaseCleaner[:active_record].start
  end

  c.after(:each) do
    DatabaseCleaner[:active_record].clean
  end
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

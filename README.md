#Sow

##Seed Files
Seed files are unique to the environment in which your Rails application is running. Within `db/seeds` create an environment-specific directory and seed file (e.g. `development.rb` & `/development` for your 'development' environment). The seed file will be evaluated just like a normal seed file. You're not required to use any Sow fanciness, and Sow directives can be mixed and mashed with plain old Ruby.

##The Sow Directive
Within your seed file, you can use the `sow` directive to initiate Sow's powerful auto-seeding. A simple directive might look like this.
```ruby
sow [User, Post, Comment]
```

This directive tells sow to go find your datafiles for the `User`, `Post`, and `Comment` seed resources, build records from the data entries, and insert them into the database. Sow will automatically detect known datafile types like `.yml`, `.json`, or `.csv` within your environment-specific seed directory. But if all your data is in `.wat` files, fear not. You can tell Sow where to look for your data, and point it toward a custom parser class for turning your data into records. The example below tells Sow to read `User` seed data from a Google Spreadsheet, and parse it accordingly.

```ruby
fanciness = {
  :source  => open('https://spreadsheets.google.com/feeds/list/somerandomtoken/1/public/values?alt=json'),
  :parser => Sow::Data::Parser::GoogleSpreadsheetJson
}

sow [
  [User, { data: fanciness }],
  Post,
  Comment
]
```

This project rocks and uses MIT-LICENSE.
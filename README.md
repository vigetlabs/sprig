![Sprig](http://i.imgur.com/XCu3iVO.png)

[![Code Climate](https://codeclimate.com/github/vigetlabs/sprig.png)](https://codeclimate.com/github/vigetlabs/sprig) [![Build Status](https://travis-ci.org/vigetlabs/sprig.png?branch=master)](https://travis-ci.org/vigetlabs/sprig) [![Gem Version](https://badge.fury.io/rb/sprig.png)](http://badge.fury.io/rb/sprig)

Seed Rails application by convention, not configuration.

Provides support for common files types: *csv*, *yaml*, and *json*.  Extensible for the rest!

Learn more about Sprig and view documentation at [http://vigetlabs.github.io/sprig/](http://vigetlabs.github.io/sprig/).

## Installation

Use `rails generate sprig:install` to create environment-specific seed directories.

##The Sprig Directive

Within your seed file, you can use the `sprig` directive to initiate Sprig's dark magicks. A simple directive might look like this.

```ruby
# seeds.rb

include Sprig::Helpers

sprig [User, Post, Comment]
```

This directive tells Sprig to go find your datafiles for the `User`, `Post`, and `Comment` seed resources, build records from the data entries, and insert them into the database. Sprig will automatically detect known datafile types like `.yml`, `.json`, or `.csv` within your environment-specific seed directory.

##Environment

Seed files are unique to the environment in which your Rails application is running. Within `db/seeds` create an environment-specific directory (i.e. `/development` for your 'development' environment).

Todo: [Support for shared seed files]


##Seed files

Hang your seed definitions on a `records` key for *yaml* and *json* files.

Examples:

```yaml
# users.yml

records:
  - sprig_id: 1
    first_name: 'Lawson'
    last_name: 'Kurtz'
    username: 'lawdawg'
  - sprig_id: 2
    first_name: 'Ryan'
    last_name: 'Foster'
    username: 'mc_rubs'
```

```json
// posts.json

{
  "records":[
    {
      "sprig_id":1,
      "title":"Json title",
      "content":"Json content"
    },
    {
      "sprig_id":2,
      "title":"Headline",
      "content":"Words about things"
    }
  ]
}
```

Each seed record needs a `sprig_id` defined that must be *unique across all seed files per class*.  It can be an integer, string, whatever you prefer; as long as it is unique, Sprig can sort your seeds for insertion and detect any cyclic relationships.

Create relationships between seed records with the `sprig_record` helper:

```yaml
# comments.yml

records:
  - sprig_id: 1
    post_id: "<%= sprig_record(Post, 1).id %>"
    body: "Yaml Comment body"
```

**Note: For namespaced or STI classes, you'll need to include the namespace with the class name in the seed file name. For example `Users::HeadManager` would need to be `users_head_managers.yml`**

### Special Options

These are provided in a `options:` key for *yaml* and *json* files.

#### find_existing_by:

Rather than starting from a blank database, you can optionally choose to find existing records and update them with seed data.

The passed in attribute or array of attributes will be used for finding existing records during the sprigging process.

Example:

```yaml
# posts.yml

options:
  find_existing_by: ['title', 'user_id']
```

### Computed Values

It's common to want seed values that are dynamic.  Sprig supports an ERB style syntax for computing seed attributes.

```yaml
# posts.yml

records:
  - sprig_id: 1
    body: "Yaml Post body"
    published_at: "<%= 1.week.ago %>"
```

##Custom Sources and Parsers

If all your data is in `.wat` files, fear not. You can tell Sprig where to look for your data, and point it toward a custom parser class for turning your data into records. The example below tells Sprig to read `User` seed data from a Google Spreadsheet, and parse it accordingly.

```ruby
fanciness = {
  :class  => User,
  :source => open('https://spreadsheets.google.com/feeds/list/somerandomtoken/1/public/values?alt=json'),
  :parser => Sprig::Data::Parser::GoogleSpreadsheetJson
}

sprig [
  fanciness,
  Post,
  Comment
]
```

##Configuration

When Sprig conventions don't suit, just add a configuration block to your seed file.

```ruby
Sprig.configure do |c|
  c.directory = 'seed_files'
end
```

## Populate Seed Files from Database

Don't want to write Sprig seed files from scratch?  Well, Sprig can create them for you!

Via a rake task:
```
rake db:seed:reap
```
Or from the Rails console:
```
Sprig::Harvest.reap
```

By default, Sprig will create seed files (currently in `.yaml` only) for every model in your Rails
application.  The seed files will be placed in a folder in `db/seeds` named after the current
`Rails.env`.

### Additional Configuration

Don't like the defaults when reaping Sprig records? You may specify the environment (`db/seeds`
target folder) or classes you want seed files for.

Example (rake task):
```
rake db:seed:reap ENV=integration CLASSES=User, Post
```

Example (Rails console):
```
Sprig::Harvest.reap(env: 'integration', classes: [User, Post])
```

### Adding to Existing Seed Files (`.yaml` only)

Already have some seed files set up?  No worries!  Sprig will detect existing seed files and append
to them with the records from your database with no extra work needed.  Sprig will automatically
assign unique `sprig_ids` so you won't have to deal with pesky duplicates.

NOTE: Sprig does not account for your application or database validations.  If you reap seed files
from your database multiple times in a row without deleting the previous seed files or sprig
records, you'll end up with duplicate sprig records (but they'll all have unique `sprig_ids`).  This
may cause validation issues when you seed your database.

## License

This project rocks and uses MIT-LICENSE.

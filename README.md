#Sow

[![Code Climate](https://codeclimate.com/github/vigetlabs/sow.png)](https://codeclimate.com/github/vigetlabs/sow)

Seed Rails application by convention, not configuration.

Provides support for common files types: *csv*, *yaml*, and *json*.  Extensible for the rest!


##The Sow Directive

Within your seed file, you can use the `sow` directive to initiate Sow's dark magicks. A simple directive might look like this.

```ruby
# seeds.rb

include Sow::Helpers

sow [User, Post, Comment]
```

This directive tells sow to go find your datafiles for the `User`, `Post`, and `Comment` seed resources, build records from the data entries, and insert them into the database. Sow will automatically detect known datafile types like `.yml`, `.json`, or `.csv` within your environment-specific seed directory.


##Environment

Seed files are unique to the environment in which your Rails application is running. Within `db/seeds` create an environment-specific directory (i.e. `/development` for your 'development' environment).

Todo: [Support for shared seed files]


##Seed files

Hang your seed definitions on a `records` key for *yaml* and *json* files.

Examples:

```yaml
# users.yml

records:
  - sow_id: 1
    first_name: 'Lawson'
    last_name: 'Kurtz'
    username: 'lawdawg'
  - sow_id: 2
    first_name: 'Ryan'
    last_name: 'Foster'
    username: 'mc_rubs'
```

```json
// posts.json

{
  "records":[
    {
      "sow_id":1,
      "title":"Json title",
      "content":"Json content"
    },
    {
      "sow_id":2,
      "title":"Headline",
      "content":"Words about things"
    }
  ]
}
```

Each seed record needs a `sow_id` defined that must be *unique across all seed files per class*.  It can be an integer, string, whatever you prefer; as long as it is unique, Sow can sort your seeds for insertion and detect any cyclic relationships.

Create relationships between seed records with the `sow_record` helper:

```yaml
# comments.yml

records:
  - sow_id: 1
    post_id: "<%= sow_record(Post, 1).id %>"
    body: "Yaml Comment body"
```

### Special Options

These are provided in a `options:` key for *yaml* and *json* files.

#### `find_existing_by`

Rather than starting from a blank database, you can optionally choose to find existing records and update them with seed data.

The passed in attribute or array of attributes will be used for finding existing records during the sowing process.

Example:

```yaml
# posts.yml

options:
  find_existing_by: ['title', 'user_id']
```

##Custom Sources and Parsers

If all your data is in `.wat` files, fear not. You can tell Sow where to look for your data, and point it toward a custom parser class for turning your data into records. The example below tells Sow to read `User` seed data from a Google Spreadsheet, and parse it accordingly.

```ruby
fanciness = {
  :class  => User,
  :source => open('https://spreadsheets.google.com/feeds/list/somerandomtoken/1/public/values?alt=json'),
  :parser => Sow::Data::Parser::GoogleSpreadsheetJson
}

sow [
  fanciness,
  Post,
  Comment
]
```

This project rocks and uses MIT-LICENSE.

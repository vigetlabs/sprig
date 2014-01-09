require 'spec_helper'
require 'open-uri'

describe "Seeding an application" do
  before do
    stub_rails_root
  end

  context "with a yaml file" do
    around do |example|
      load_seeds('posts.yml', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Yaml title']
    end
  end

  context "with a csv file" do
    around do |example|
      load_seeds('posts.csv', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Csv title']
    end
  end

  context "with a json file" do
    around do |example|
      load_seeds('posts.json', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Json title']
    end
  end

  context "with a google spreadsheet" do
    it "seeds the db", :vcr => { :cassette_name => 'google_spreadsheet_json_posts' } do
      sow [
        {
          :class  => Post,
          :parser => Sow::Data::Parser::GoogleSpreadsheetJson,
          :source => open('https://spreadsheets.google.com/feeds/list/0AjVLPMnHm86rdDVHQ2dCUS03RTN5ZUtVNzVOYVBwT0E/1/public/values?alt=json'),
        }
      ]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Google spreadsheet json title']
    end
  end

  context "with multiple file relationships" do
    around do |example|
      load_seeds('posts.yml', 'comments.yml', &example)
    end

    it "seeds the db" do
      sow [Post, Comment]

      Post.count.should    == 1
      Comment.count.should == 1
      Comment.first.post.should == Post.first
    end
  end

  context "with a relationship to an undefined record" do
    around do |example|
      load_seeds('posts.yml', 'posts_missing_dependency.yml', &example)
    end

    it "raises a helpful error message" do
      expect {
        sow [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/development/posts_missing_dependency.yml')
          }
        ]
      }.to raise_error(
        Sow::DependencySorter::MissingDependencyError,
        "Undefined reference to 'sow_record(Comment, 42)'"
      )
    end
  end

  context "with multiple files for a class" do
    around do |example|
      load_seeds('posts.yml', 'legacy_posts.yml', &example)
    end

    it "seeds the db" do
      sow [
        Post,
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/development/legacy_posts.yml')
        }
      ]

      Post.count.should == 2
      Post.pluck(:title).should=~ ['Yaml title', 'Legacy yaml title']
    end
  end

  context "from a specific environment" do
    around do |example|
      stub_rails_env 'staging'
      load_seeds('posts.yml', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Staging yaml title']
    end
  end
end

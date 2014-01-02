require 'spec_helper'
require 'open-uri'

describe "Seeding an application" do
  before do
    stub_rails_root
  end

  context "with a yaml file" do
    around do |example|
      load_seed('posts.yml', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Yaml title']
    end
  end

  context "with a csv file" do
    around do |example|
      load_seed('posts.csv', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Csv title']
    end
  end

  context "with a json file" do
    around do |example|
      load_seed('posts.json', &example)
    end

    it "seeds the db" do
      sow [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Json title']
    end
  end

  context "with a google spreadsheet" do
    let(:gss_posts) do
      {
        :source => open('https://spreadsheets.google.com/feeds/list/0AjVLPMnHm86rdDVHQ2dCUS03RTN5ZUtVNzVOYVBwT0E/1/public/values?alt=json'),
        :parser => Sow::Data::Parser::GoogleSpreadsheetJson
      }
    end

    it "seeds the db", :vcr => { :cassette_name => 'google_spreadsheet_json_posts' } do
      sow [[Post, :data => gss_posts]]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Google spreadsheet json title']
    end
  end
end

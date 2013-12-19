require 'spec_helper'

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
end

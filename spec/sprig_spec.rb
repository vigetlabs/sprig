require 'spec_helper'
require 'open-uri'

describe "Seeding an application" do
  let(:missing_record_error) do
    if defined?(ActiveRecord) && Post < ActiveRecord::Base
      ActiveRecord::RecordNotFound
    elsif defined?(Mongoid) && Post < Mongoid::Document
      Mongoid::Errors::DocumentNotFound
    end
  end

  before do
    stub_rails_root
  end

  context "with a yaml file" do
    around do |example|
      load_seeds('posts.yml', &example)
    end

    it "seeds the db" do
      sprig [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Yaml title']
    end
  end

  context "with a csv file" do
    around do |example|
      load_seeds('posts.csv', &example)
    end

    it "seeds the db" do
      sprig [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Csv title']
    end
  end

  context "with a json file" do
    around do |example|
      load_seeds('posts.json', &example)
    end

    it "seeds the db" do
      sprig [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Json title']
    end
  end

  context "with a partially-dynamic value" do
    around do |example|
      load_seeds('posts_partially_dynamic_value.yml', &example)
    end

    it "seeds the db with the full value" do
      sprig [
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/posts_partially_dynamic_value.yml')
        }
      ]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Partially Dynamic Title']
    end
  end

  context "with a symlinked file" do
    let(:env) { Rails.env }

    around do |example|
      `ln -s ./spec/fixtures/seeds/#{env}/posts.yml ./spec/fixtures/db/seeds/#{env}`
      example.call
      `rm ./spec/fixtures/db/seeds/#{env}/posts.yml`
    end

    it "seeds the db" do
      sprig [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Yaml title']
    end
  end

  context "with a google spreadsheet" do
    it "seeds the db", :vcr => { :cassette_name => 'google_spreadsheet_json_posts' } do
      sprig [
        {
          :class  => Post,
          :parser => Sprig::Parser::GoogleSpreadsheetJson,
          :source => open('https://spreadsheets.google.com/feeds/list/0AjVLPMnHm86rdDVHQ2dCUS03RTN5ZUtVNzVOYVBwT0E/1/public/values?alt=json'),
        }
      ]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Google spreadsheet json title']
    end
  end

  context "with an invalid custom parser" do
    around do |example|
      load_seeds('posts.yml', &example)
    end

    it "fails with an argument error" do
      expect {
        sprig [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/test/posts.yml'),
            :parser => Object # Not a valid parser
          }
        ]
      }.to raise_error(ArgumentError, 'Parsers must define #parse.')
    end
  end

  context "with a custom source" do
    around do |example|
      load_seeds('legacy_posts.yml', &example)
    end

    it "seeds" do
      sprig [
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/legacy_posts.yml')
        }
      ]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Legacy yaml title']
    end
  end

  context "with a custom source that cannot be parsed by native parsers" do
    around do |example|
      load_seeds('posts.md', &example)
    end

    it "fails with an unparsable file error" do
      expect {
        sprig [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/test/posts.md')
          }
        ]
      }.to raise_error(Sprig::Source::ParserDeterminer::UnparsableFileError)
    end
  end

  context "with an invalid custom source" do
    it "fails with an argument error" do
      expect {
        sprig [ { :class => Post, :source => 42 } ]
      }.to raise_error(ArgumentError, 'Data sources must act like an IO.')
    end
  end

  context "with multiple file relationships" do
    around do |example|
      load_seeds('posts.yml', 'comments.yml', &example)
    end

    it "seeds the db" do
      sprig [Post, Comment]

      Post.count.should    == 1
      Comment.count.should == 1
      Comment.first.post.should == Post.first
    end
  end

  context "with missing seed files" do
    it "raises a missing file error" do
      expect {
        sprig [Post]
      }.to raise_error(Sprig::Source::SourceDeterminer::FileNotFoundError)
    end
  end

  context "with a relationship to an undefined record" do
    around do |example|
      load_seeds('posts.yml', 'posts_missing_dependency.yml', &example)
    end

    it "raises a helpful error message" do
      expect {
        sprig [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/test/posts_missing_dependency.yml')
          }
        ]
      }.to raise_error(
        Sprig::DependencySorter::MissingDependencyError,
        "Undefined reference to 'sprig_record(Comment, 42)'"
      )
    end
  end

  context "with a relationship to a record that didn't save" do
    around do |example|
      load_seeds('invalid_users.yml', 'posts_missing_record.yml', &example)
    end

    it "does not error, but carries on with the seeding" do
      expect {
        sprig [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/test/posts_missing_record.yml')
          },
          {
            :class  => User,
            :source => open('spec/fixtures/seeds/test/invalid_users.yml')
          }
        ]
      }.to_not raise_error
    end
  end

  context "with multiple files for a class" do
    around do |example|
      load_seeds('posts.yml', 'legacy_posts.yml', &example)
    end

    it "seeds the db" do
      sprig [
        Post,
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/legacy_posts.yml')
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
      sprig [Post]

      Post.count.should == 1
      Post.pluck(:title).should =~ ['Staging yaml title']
    end
  end

  context "with files defined as attributes" do
    around do |example|
      load_seeds('posts_with_files.yml', &example)
    end

    it "seeds the db" do
      sprig [
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/posts_with_files.yml')
        }
      ]

      Post.count.should == 1
      Post.pluck(:photo).should =~ ['cat.png']
    end
  end

  context "with has_and_belongs_to_many relationships" do
    around do |example|
      load_seeds('posts_with_habtm.yml', 'tags.yml', &example)
    end

    it "saves the habtm relationships" do
      sprig [
        Tag,
        {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/posts_with_habtm.yml')
        }
      ]

      Post.first.tags.map(&:name).should == ['Botany', 'Biology']
    end
  end

  context "with cyclic dependencies" do
    around do |example|
      load_seeds('comments.yml', 'posts_with_cyclic_dependencies.yml', &example)
    end

    it "raises an cyclic dependency error" do
      expect {
        sprig [
          {
            :class  => Post,
            :source => open('spec/fixtures/seeds/test/posts_with_cyclic_dependencies.yml')
          },
          Comment
        ]
      }.to raise_error(Sprig::DependencySorter::CircularDependencyError)
    end
  end

  context "with a malformed directive" do
    let(:expected_error_message) { "Sprig::Directive must be instantiated with a(n) #{Sprig.adapter_model_class} class or a Hash with :class defined" }

    context "including a class that is not a subclass of AR" do
      it "raises an argument error" do
        expect {
          sprig [
            Object
          ]
        }.to raise_error(ArgumentError, expected_error_message)
      end
    end

    context "including a non-class, non-hash" do
      it "raises an argument error" do
        expect {
          sprig [
            42
          ]
        }.to raise_error(ArgumentError, expected_error_message)
      end
    end
  end


  context "with custom seed options" do
    context "using delete_existing_by" do
      around do |example|
        load_seeds('posts_delete_existing_by.yml', &example)
      end

      context "with an existing record" do
        let!(:existing_match) do
          Post.create(
            :title    => "Such Title",
            :content  => "Old Content")
        end

        let!(:existing_nonmatch) do
          Post.create(
            :title    => "Wow Title",
            :content  => "Much Content")
        end

        it "replaces only the matching existing record" do
          sprig [
            {
              :class  => Post,
              :source => open("spec/fixtures/seeds/test/posts_delete_existing_by.yml")
            }
          ]

          Post.count.should == 2

          expect {
            existing_match.reload
          }.to raise_error(missing_record_error)

          expect {
            existing_nonmatch.reload
          }.to_not raise_error
        end
      end
    end

    context "using find_existing_by" do
      context "with a missing attribute" do
        around do |example|
          load_seeds('posts_find_existing_by_missing.yml', &example)
        end

        it "raises a missing attribute error" do
          expect {
            sprig [
              {
                :class  => Post,
                :source => open("spec/fixtures/seeds/test/posts_find_existing_by_missing.yml")
              }
            ]
          }.to raise_error(Sprig::Seed::AttributeCollection::AttributeNotFoundError, "Attribute 'unicorn' is not present.")
        end
      end

      context "with a single attribute" do
        around do |example|
          load_seeds('posts.yml', 'posts_find_existing_by_single.yml', &example)
        end

        context "with an existing record" do
          let!(:existing) do
            Post.create(
              :title    => "Existing title",
              :content  => "Existing content")
          end

          it "updates the existing record" do
            sprig [
              {
                :class  => Post,
                :source => open("spec/fixtures/seeds/test/posts_find_existing_by_single.yml")
              }
            ]

            Post.count.should == 1
            existing.reload.content.should == "Updated content"
          end
        end
      end

      context "with multiple attributes" do
        around do |example|
          load_seeds('posts.yml', 'posts_find_existing_by_multiple.yml', &example)
        end

        context "with an existing record" do
          let!(:existing) do
            Post.create(
              :title      => "Existing title",
              :content    => "Existing content",
              :published  => false
            )
          end

          it "updates the existing record" do
            sprig [
              {
                :class  => Post,
                :source => open("spec/fixtures/seeds/test/posts_find_existing_by_multiple.yml")
              }
            ]

            Post.count.should == 1
            existing.reload.published.should == true
          end
        end
      end
    end

    context "defined within the directive" do
      let!(:existing) do
        Post.create(
          :title    => "Yaml title",
          :content  => "Existing content")
      end

      around do |example|
        load_seeds('posts.yml', &example)
      end

      it "respects the directive option" do
        sprig [
          {
            :class   => Post,
            :source  => open("spec/fixtures/seeds/test/posts.yml"),
            :delete_existing_by => :title
          }
        ]

        Post.count.should == 1

        expect {
          existing.reload
        }.to raise_error(missing_record_error)
      end
    end
  end
end

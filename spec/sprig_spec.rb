require "spec_helper"
require "open-uri"

RSpec.describe "Seeding an application" do
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
      load_seeds("posts.yml", &example)
    end

    it "seeds the db" do
      sprig [Post]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Yaml title"])
    end
  end

  context "with a csv file" do
    around do |example|
      load_seeds("posts.csv", &example)
    end

    it "seeds the db" do
      sprig [Post]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Csv title"])
    end
  end

  context "with a json file" do
    around do |example|
      load_seeds("posts.json", &example)
    end

    it "seeds the db" do
      sprig [Post]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Json title"])
    end
  end

  context "with a partially-dynamic value" do
    around do |example|
      load_seeds("posts_partially_dynamic_value.yml", &example)
    end

    it "seeds the db with the full value" do
      sprig [
        {
          class: Post,
          source: open("spec/fixtures/seeds/test/posts_partially_dynamic_value.yml")
        }
      ]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Partially Dynamic Title"])
    end
  end

  context "with a relative symlink" do
    let(:env) { Rails.env }

    around do |example|
      symlink_path = "./spec/fixtures/db/seeds/#{env}/posts.yml"

      # mktmpdir guarantees a unique directory name, so this can't collide
      # with another example's fixtures, and it's removed automatically
      # (even on failure) once the block returns.
      Dir.mktmpdir(nil, "./spec/fixtures/db/seeds") do |tmp_dir|
        FileUtils.cp("./spec/fixtures/seeds/#{env}/posts.yml", File.join(tmp_dir, "posts.yml"))
        File.symlink(File.join("..", File.basename(tmp_dir), "posts.yml"), symlink_path)

        begin
          example.call
        ensure
          FileUtils.rm_f(symlink_path)
        end
      end
    end

    it "seeds the db" do
      sprig [Post]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Yaml title"])
    end
  end

  context "with an invalid custom parser" do
    around do |example|
      load_seeds("posts.yml", &example)
    end

    it "fails with an argument error" do
      expect {
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts.yml"),
            parser: Object # Not a valid parser
          }
        ]
      }.to raise_error(ArgumentError, "Parsers must define #parse.")
    end
  end

  context "with a custom source" do
    around do |example|
      load_seeds("legacy_posts.yml", &example)
    end

    it "seeds" do
      sprig [
        {
          class: Post,
          source: open("spec/fixtures/seeds/test/legacy_posts.yml")
        }
      ]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:title)).to eq(["Legacy yaml title"])
    end
  end

  context "with a custom source that cannot be parsed by native parsers" do
    around do |example|
      load_seeds("posts.md", &example)
    end

    it "fails with an unparsable file error" do
      expect {
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts.md")
          }
        ]
      }.to raise_error(Sprig::Source::ParserDeterminer::UnparsableFileError)
    end
  end

  context "with an invalid custom source" do
    it "fails with an argument error" do
      expect {
        sprig [{class: Post, source: 42}]
      }.to raise_error(ArgumentError, "Data sources must act like an IO.")
    end
  end

  context "with multiple file relationships" do
    around do |example|
      load_seeds("posts.yml", "comments.yml", &example)
    end

    it "seeds the db" do
      sprig [Post, Comment]

      expect(Post.count).to eq(1)
      expect(Comment.count).to eq(1)
      expect(Comment.first.post).to eq(Post.first)
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
      load_seeds("posts.yml", "posts_missing_dependency.yml", &example)
    end

    it "raises a helpful error message" do
      expect {
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts_missing_dependency.yml")
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
      load_seeds("invalid_users.yml", "posts_missing_record.yml", &example)
    end

    it "does not raise, but skips the record instead of saving it with a broken reference" do
      expect {
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts_missing_record.yml")
          },
          {
            class: User,
            source: open("spec/fixtures/seeds/test/invalid_users.yml")
          }
        ]
      }.to_not raise_error

      expect(Post.count).to eq(0)
    end
  end

  context "with multiple files for a class" do
    around do |example|
      load_seeds("posts.yml", "legacy_posts.yml", &example)
    end

    it "seeds the db" do
      sprig [
        Post,
        {
          class: Post,
          source: open("spec/fixtures/seeds/test/legacy_posts.yml")
        }
      ]

      expect(Post.count).to eq(2)
      expect(Post.pluck(:title)).to eq(["Yaml title", "Legacy yaml title"])
    end
  end

  context "from a specific environment" do
    it "seeds the db" do
      ex = proc do
        sprig [Post]

        expect(Post.count).to eq(1)
        expect(Post.pluck(:title)).to eq(["Staging yaml title"])
      end

      stub_rails_env "staging"
      load_seeds("posts.yml", &ex)
    end
  end

  context "with files defined as attributes" do
    around do |example|
      load_seeds("posts_with_files.yml", &example)
    end

    it "seeds the db" do
      sprig [
        {
          class: Post,
          source: open("spec/fixtures/seeds/test/posts_with_files.yml")
        }
      ]

      expect(Post.count).to eq(1)
      expect(Post.pluck(:photo)).to eq(["cat.png"])
    end
  end

  context "with has_and_belongs_to_many relationships" do
    around do |example|
      load_seeds("posts_with_habtm.yml", "tags.yml", &example)
    end

    it "saves the habtm relationships" do
      sprig [
        Tag,
        {
          class: Post,
          source: open("spec/fixtures/seeds/test/posts_with_habtm.yml")
        }
      ]

      expect(Post.first.tags.map(&:name)).to eq(["Botany", "Biology"])
    end
  end

  if Sprig.adapter == :active_record
    context "with STI records" do
      around do |example|
        load_seeds("article_pages.yml", "pages.yml", &example)
      end

      it "allows cross-referencing of STI records" do
        sprig [
          ArticlePage,
          Page
        ]

        expect(Page.all.map(&:title)).to eq(
          ["First Title", "First Title", "Second Title", "Second Title"]
        )
      end
    end
  end

  context "with cyclic dependencies" do
    around do |example|
      load_seeds("comments.yml", "posts_with_cyclic_dependencies.yml", &example)
    end

    it "raises an cyclic dependency error" do
      expect {
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts_with_cyclic_dependencies.yml")
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
        load_seeds("posts_delete_existing_by.yml", &example)
      end

      context "with an existing record" do
        let!(:existing_match) do
          Post.create(
            title: "Such Title",
            content: "Old Content"
          )
        end

        let!(:existing_nonmatch) do
          Post.create(
            title: "Wow Title",
            content: "Much Content"
          )
        end

        it "replaces only the matching existing record" do
          sprig [
            {
              class: Post,
              source: open("spec/fixtures/seeds/test/posts_delete_existing_by.yml")
            }
          ]

          expect(Post.count).to eq(2)

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
        let!(:existing_record) do
          Post.create(
            :title     => "Existing title",
            :published => true,
            :content   => nil)
        end

        around do |example|
          load_seeds("posts_find_existing_by_missing.yml", &example)
        end

        it "assumes a nil value for the missing attribute" do
          sprig [
            {
              class: Post,
              source: open("spec/fixtures/seeds/test/posts_find_existing_by_missing.yml")
            }
          ]

          Post.count.should == 1
          Post.first.published.should == false
        end
      end

      context "with a single attribute" do
        around do |example|
          load_seeds("posts.yml", "posts_find_existing_by_single.yml", &example)
        end

        context "with an existing record" do
          let!(:existing) do
            Post.create(
              title: "Existing title",
              content: "Existing content"
            )
          end

          it "updates the existing record" do
            sprig [
              {
                class: Post,
                source: open("spec/fixtures/seeds/test/posts_find_existing_by_single.yml")
              }
            ]

            expect(Post.count).to eq(1)
            expect(existing.reload.content).to eq("Updated content")
          end
        end
      end

      context "with multiple attributes" do
        around do |example|
          load_seeds("posts.yml", "posts_find_existing_by_multiple.yml", &example)
        end

        context "with an existing record" do
          let!(:existing) do
            Post.create(
              title: "Existing title",
              content: "Existing content",
              published: false
            )
          end

          it "updates the existing record" do
            sprig [
              {
                class: Post,
                source: open("spec/fixtures/seeds/test/posts_find_existing_by_multiple.yml")
              }
            ]

            expect(Post.count).to eq(1)
            expect(existing.reload.published).to eq(true)
          end
        end
      end
    end

    context "defined within the directive" do
      let!(:existing) do
        Post.create(
          title: "Yaml title",
          content: "Existing content"
        )
      end

      around do |example|
        load_seeds("posts.yml", &example)
      end

      it "respects the directive option" do
        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts.yml"),
            delete_existing_by: :title
          }
        ]

        expect(Post.count).to eq(1)

        expect {
          existing.reload
        }.to raise_error(missing_record_error)
      end
    end
  end

  context "with Sprig configured to wrap the planting process in a transaction" do
    before do
      Sprig.configure do |c|
        c.wrap_in_transaction = true
      end
    end

    after do
      Sprig.configure do |c|
        c.wrap_in_transaction = false
      end
    end

    context "with no errors" do
      around do |example|
        load_seeds('posts.yml', &example)
      end

      it "adds all the records to the database" do
        sprig [Post]

        expect(Post.count).to eq(1)
        expect(Post.pluck(:title)).to match_array(['Yaml title'])
      end
    end

    context "with some errors" do
      around do |example|
        load_seeds('posts_with_some_errors.yml', &example)
      end

      it "adds no records to the database" do
        sprig [
          {
          :class  => Post,
          :source => open('spec/fixtures/seeds/test/posts_with_some_errors.yml')
          }
        ]

        expect(Post.count).to eq(0)
      end
    end

    context "with an error followed by a seed that would otherwise succeed" do
      around do |example|
        load_seeds("posts_with_some_errors_then_valid.yml", &example)
      end

      it "still attempts the later seed before rolling everything back" do
        allow(Sprig.logger).to receive(:info)
        allow(Sprig.logger).to receive(:error)
        expect(Sprig.logger).to receive(:info).with(log_info_text("Saved")).twice

        sprig [
          {
            class: Post,
            source: open("spec/fixtures/seeds/test/posts_with_some_errors_then_valid.yml")
          }
        ]

        expect(Post.count).to eq(0)
      end
    end

    context "with an exception raised while planting (rather than a failed validation)" do
      around do |example|
        load_seeds("posts.yml", "posts_find_existing_by_missing_other_id.yml", &example)
      end

      it "rolls back records that had already been saved, and explains why in the summary" do
        allow(Sprig.logger).to receive(:error)

        log_should_receive(:error, with: "The seeding transaction was rolled back because 1 seed failed to plant. " \
          "NO records from this run were actually saved to the database.")
        log_should_receive(:error, with: "The following 1 seed would have been planted, but were rolled back " \
          "along with everything else and were NOT saved:")
        log_should_receive(:error, with: "Post with sprig_id 1 (Saved)")

        sprig [
          {class: Post, source: open("spec/fixtures/seeds/test/posts.yml")},
          {class: Post, source: open("spec/fixtures/seeds/test/posts_find_existing_by_missing_other_id.yml")}
        ]

        expect(Post.count).to eq(0)
      end
    end
  end
end

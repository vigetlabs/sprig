require 'spec_helper'

describe Sprig::Harvest::SeedFile do
  let(:config) { Sprig::Harvest::ModelConfig.new(Comment) }
  let(:model)  { Sprig::Harvest::Model.new(config) }

  subject { described_class.new(model) }

  before do
    stub_rails_root
    Sprig::Harvest.stub(:env).and_return('dreamland')
  end

  describe "#initialize" do
    context "given a non-Sprig::Harvest::Model" do
      it "raises an error" do
        expect {
          described_class.new(User)
        }.to raise_error ArgumentError, 'Must initialize with a Sprig::Harvest::Model'
      end
    end
  end

  describe "#path" do
    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    its(:path) { should == Rails.root.join('db', 'seeds', 'dreamland', 'comments.yml') }
  end

  describe "#exists?" do
    subject { described_class.new(model) }

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    context "when the seed file already exists" do
      before do
        File.stub(:exists?).with(subject.path).and_return(true)
      end

      its(:exists?) { should == true }
    end

    context "when the seed file does not exist" do
      its(:exists?) { should == false }
    end
  end

  describe "#write" do
    let!(:user)      { User.create(:first_name => 'Bo', :last_name => 'Janglez') }
    let!(:post1)     { Post.create }
    let!(:post2)     { Post.create }
    let!(:comment1)  { Comment.create(:post => post1) }
    let!(:comment2)  { Comment.create(:post => post2) }

    around do |example|
      setup_seed_folder('./spec/fixtures/db/seeds/dreamland', &example)
    end

    context "when the seed file already exists" do
      before do
        yaml = File.read('./spec/fixtures/yaml/comment_seeds.yml')
        File.open(subject.path, 'w') { |file| file.write(yaml) }
      end

      it "pulls out the existing sprig ids and stores them on the given model" do
        model.should_receive(:existing_sprig_ids=).with([10, 20])

        subject.write
      end

      it "grabs the yaml for the given model without a namespace" do
        model.should_receive(:to_yaml).with(:namespace => nil)

        subject.write
      end

      it "populates the file" do
        starting_size = File.size(subject.path)

        subject.write

        File.size?(subject.path).should > starting_size
      end
    end

    context "when the seed file does not yet exist" do
      it "does not pass any existing sprig ids to the given model" do
        model.should_not_receive(:existing_sprig_ids=)

        subject.write
      end

      it "grabs the yaml for the given model with the 'records' namespace" do
        model.should_receive(:to_yaml).with(:namespace => 'records')

        subject.write
      end

      it "populates the file" do
        subject.write

        File.size?(subject.path).should > 0
      end
    end
  end
end

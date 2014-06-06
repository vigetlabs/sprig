require 'spec_helper'

describe Sprig::Harvest::Model do
  describe ".all" do
    let(:all_models) do
      [
        described_class.new(config_for(Post)),
        described_class.new(config_for(Comment)),
        described_class.new(config_for(User))
      ]
    end

    it "returns an dependency-sorted array of Sprig::Harvest::Models" do
      described_class.all.all? { |model| model.is_a? Sprig::Harvest::Model }.should == true
      described_class.all.map(&:klass).should =~ all_models.map(&:klass)
    end
  end

  describe ".find" do
    let!(:user)      { User.create(:first_name => 'Bo', :last_name => 'Janglez') }
    let!(:post1)     { Post.create }
    let!(:post2)     { Post.create }
    let!(:comment1)  { Comment.create(:post => post1) }
    let!(:comment2)  { Comment.create(:post => post2) }

    subject { described_class }

    it "returns the Sprig::Harvest::Record for the given class and id" do
      subject.find(User, 1).record.should == user
      subject.find(Post, 1).record.should == post1
      subject.find(Post, 2).record.should == post2
      subject.find(Comment, 1).record.should == comment1
      subject.find(Comment, 2).record.should == comment2
    end
  end

  describe "#find" do
    let!(:post1) { Post.create }
    let!(:post2) { Post.create }

    subject { described_class.new(config_for(Post)) }

    it "returns the Sprig::Harvest::Record with the given id" do
      harvest_record = subject.find(2)
      harvest_record.should be_an_instance_of Sprig::Harvest::Record
      harvest_record.record.should == post2
    end
  end

  describe "#generate_sprig_id" do
    subject { described_class.new(config_for(Comment)) }

    context "when the existing sprig_ids are all integers" do
      before do
        subject.existing_sprig_ids = [5, 20, 8]
      end

      it "returns an integer-type sprig_id that is not taken" do
        subject.generate_sprig_id.should == 21
      end
    end

    context "when the existing sprig ids contain non-integer values" do
      before do
        subject.existing_sprig_ids = [1, 5, 'l_2', 'l_10', 'such_sprigs', 10.9]
      end
      it "returns an integer-type sprig_id that is not taken" do
        subject.generate_sprig_id.should == 6
      end
    end
  end

  describe "#to_s" do
    subject { described_class.new(config_for(Comment)) }

    its(:to_s) { should == "Comment" }
  end

  describe "#to_yaml" do
    let!(:user)      { User.create(:first_name => 'Bo', :last_name => 'Janglez') }
    let!(:post1)     { Post.create }
    let!(:post2)     { Post.create }
    let!(:comment1)  { Comment.create(:post => post1) }
    let!(:comment2)  { Comment.create(:post => post2) }

    subject { described_class.new(config_for(Comment)) }

    context "when passed a value for the namespace" do
      it "returns the correct yaml" do
        subject.to_yaml(:namespace => 'records').should == yaml_from_file('records_with_namespace.yml')
      end
    end

    context "when no namespace is given" do
      it "returns the correct yaml" do
        subject.to_yaml.should == yaml_from_file('records_without_namespace.yml')
      end
    end
  end

  describe "#records" do
    subject { described_class.new(config_for(Comment)) }

    before do
      subject.config.stub(:collection).and_return([*1..10])
    end

    context "when limit is configured" do
      it "returns the appropriate number of records" do
        subject.config.stub(:limit).and_return(5)

        Sprig::Harvest::Record.should_receive(:new).exactly(5).times

        subject.records
      end
    end

    context "when there is no limit configured" do
      it "returns all the records" do
        Sprig::Harvest::Record.should_receive(:new).exactly(10).times

        subject.records
      end
    end
  end

  def yaml_from_file(basename)
    File.read('spec/fixtures/yaml/' + basename)
  end

  def config_for(klass)
    Sprig::Harvest::ModelConfig.new(klass)
  end
end

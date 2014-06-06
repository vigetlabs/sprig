require 'spec_helper'

describe Sprig::Harvest::ModelConfig do
  describe "#initialize" do
    context "with a klass that is not a sublcass of ActiveRecord::Base" do
      it "raises an error" do
        expect {
          described_class.new(Sprig::Directive)
        }.to raise_error ArgumentError, 'Cannot create a seed file for Sprig::Directive because it is not a subclass of ActiveRecord::Base.'
      end
    end

    context "with a subclass of ActiveRecord::Base" do
      subject { described_class.new(User) }

      its(:klass) { should == User }
    end
  end

  describe "#collection" do
    let!(:user1) { User.create(:first_name => 'Bo', last_name: 'Janglez') }
    let!(:user2) { User.create(:first_name => 'Bo', last_name: 'Jinglez') }
    let!(:user3) { User.create(:first_name => 'Bi', last_name: 'Jonglez') }

    context "when no collection was given" do
      subject { described_class.new(User) }

      its(:collection) { should =~ [user1, user2, user3] }
    end

    context "when a collection was given" do
      subject { described_class.new(User, :collection => [user1, user3]) }

      its(:collection) { should == [user1, user3] }
    end
  end

  describe "#limit" do
    context "when no limit was given" do
      subject { described_class.new(User) }

      context "and there is no limit for all classes" do
        before { Sprig::Harvest.stub(:limit) }
        
        its(:limit) { should == nil }
      end

      context "and there is a limit for all classes" do
        before { Sprig::Harvest.stub(:limit).and_return(10) }

        its(:limit) { should == 10 }
      end
    end

    context "when a limit was given" do
      subject do
        described_class.new(User,
          :limit => 25
        )
      end

      context "and there is no limit for all classes" do
        before { Sprig::Harvest.stub(:limit) }
        
        its(:limit) { should == 25 }
      end

      context "and there is a limit for all classes" do
        before { Sprig::Harvest.stub(:limit).and_return(10) }

        its(:limit) { should == 25 }
      end
    end
  end

  describe "#ignored_attrs" do
    context "when no ignored attributes were given" do
      subject { described_class.new(User) }

      context "and there are no ignored attributes for all classes" do
        before { Sprig::Harvest.stub(:ignored_attrs).and_return([]) }

        its(:ignored_attrs) { should == [] }
      end

      context "but there are ignored attributes for all classes" do
        before { Sprig::Harvest.stub(:ignored_attrs).and_return(['first_name']) }

        its(:ignored_attrs) { should == ['first_name'] }
      end
    end

    context "when ignored attributes were given" do
      subject do
        described_class.new(User,
          :ignored_attrs => [:last_name]
        )
      end

      its(:ignored_attrs) { should == ['last_name'] }

      context "and there are ignored attributes for all classes" do
        before { Sprig::Harvest.stub(:ignored_attrs).and_return(['first_name']) }

        its(:ignored_attrs) { should =~ ['first_name', 'last_name'] }
      end
    end
  end

  describe "#attributes" do
    context "when there are class-specific ignored attributes" do
      subject do
        described_class.new(User,
          :ignored_attrs => [:last_name]
        )
      end

      its(:attributes) { should == User.column_names - ['last_name'] }

      context "as well as for all classes" do
        before { Sprig::Harvest.stub(:ignored_attrs).and_return(['first_name']) }

        its(:attributes) { should == User.column_names - ['first_name', 'last_name'] }
      end
    end

    context "when there are no ignored attributes" do
      subject { described_class.new(User) }

      its(:attributes) { should == User.column_names }
    end
  end

  describe "#dependencies" do
    subject { described_class.new(Comment) }

    its(:dependencies) { should == [Post] }
  end
end

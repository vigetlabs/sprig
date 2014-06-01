require 'spec_helper'

class Very; end

describe Sprig::Harvest::Record do
  let(:record)         { double('ActiveRecord::Base Instance') }
  let(:model)          { double('Sprig::Harvest::Model') }
  let(:harvest_record) { double('Sprig::Harvest::Record for class Very', sprig_id: 5) }
  let(:sprig_record)   { "<%= sprig_record(Very, 5).id %>" }

  subject { described_class.new(record, model) }

  before do
    attrs = { 
      'id'      => 0,
      'such'    => 1,
      'wow'     => 2,
      'very_id' => 3
    }

    attrs.each_pair do |attr, val|
      record.stub(attr).and_return(val)
    end

    model.stub(:attributes).and_return(attrs.keys)
    model.stub(:existing_sprig_ids).and_return([])

    Sprig::Harvest::Model.stub(:find).and_return(harvest_record)
  end

  describe ".initialize" do
    it "adds a reader-type instance method for each attribute on the given model" do
      subject.id.should       == 0
      subject.such.should     == 1
      subject.wow.should      == 2
      subject.very_id.should  == sprig_record
    end
  end

  describe "#attributes" do
    it "returns an array of attributes from the given model with sprig_id swapped out for id" do
      subject.attributes.should == %w(
        sprig_id
        such
        wow 
        very_id
      )
    end
  end

  describe "#to_hash" do
    it "returns its attributes and their values in a hash" do
      subject.to_hash.should == {
        'sprig_id' => 0,
        'such'     => 1,
        'wow'      => 2,
        'very_id'  => sprig_record
      }
    end
  end

  describe "#sprig_id" do
    its(:sprig_id) { should == record.id }

    context "when an existing seed record has a sprig_id equal to the record's id" do
      before do
        model.stub(:existing_sprig_ids).and_return([record.id])
        model.stub(:generate_sprig_id).and_return(25)
      end

      its(:sprig_id) { should == 25 }
    end
  end
end

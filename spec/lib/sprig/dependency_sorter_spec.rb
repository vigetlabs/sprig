require 'spec_helper'

RSpec.describe Sprig::DependencySorter do
  describe "#sorted_items" do
    it "returns the items ordered so dependencies come before dependents" do
      item_a = double('item_a', :dependency_id => 'a', :dependencies => [])
      item_b = double('item_b', :dependency_id => 'b', :dependencies => [double('dep', :id => 'a')])

      sorted = described_class.new([item_b, item_a]).sorted_items

      expect(sorted).to eq([item_a, item_b])
    end

    it "raises a CircularDependencyError when items depend on each other" do
      item_a = double('item_a', :dependency_id => 'a', :dependencies => [double('dep', :id => 'b')])
      item_b = double('item_b', :dependency_id => 'b', :dependencies => [double('dep', :id => 'a')])

      expect {
        described_class.new([item_a, item_b]).sorted_items
      }.to raise_error(Sprig::DependencySorter::CircularDependencyError)
    end

    it "raises a MissingDependencyError referencing the sprig_record when the missing dependency is a Dependency" do
      missing_dependency = Sprig::Dependency.for(Post, '999')
      item_a = double('item_a', :dependency_id => 'a', :dependencies => [missing_dependency])

      expect {
        described_class.new([item_a]).sorted_items
      }.to raise_error(
        Sprig::DependencySorter::MissingDependencyError,
        "Undefined reference to 'sprig_record(Post, 999)'"
      )
    end

    it "raises a generic MissingDependencyError when the missing dependency isn't a Dependency" do
      item_a = double('item_a', :dependency_id => 'a', :dependencies => [double('dep', :id => 'missing')])

      expect {
        described_class.new([item_a]).sorted_items
      }.to raise_error(
        Sprig::DependencySorter::MissingDependencyError,
        "Referenced 'sprig_record' does not have a correlating record."
      )
    end
  end
end

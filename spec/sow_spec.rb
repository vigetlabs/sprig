require 'spec_helper'

describe "Seeding an application" do
  before do
    stub_rails_root
  end

  it "can seed a yaml file" do
    sow [Post]

    Post.count.should == 1
    Post.pluck(:title) =~ ['The McRib is back']
  end
end

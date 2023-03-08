require 'spec_helper'

describe Sprig::Railtie do
  subject { described_class.instance }

  its(:railtie_name) { should == 'sprig_railtie'}
end

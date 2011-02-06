require 'spec_helper'

describe Pathname do
  it "can match against regular expressions" do
    Pathname.new('/etc').should =~ /#{File::SEPARATOR}/
  end

  it "can gsub" do
    Pathname.new('/etc').gsub('etc', 'tmp').should == '/tmp'
  end
end

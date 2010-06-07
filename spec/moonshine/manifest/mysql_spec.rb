require 'spec_helper'

describe Moonshine::Manifest::Rails::Mysql do
  before do
    @manifest = Moonshine::Manifest::Rails.new
  end

  context "Ubuntu Lucid (10.04)" do
    before do
      Facter.stub!(:lsbdistrelease => '10.04')
      Facter.stub!(:lsbdistid => 'Ubuntu')
    end

    specify "MySQL version should be 5.1" do
      @manifest.mysql_server

      @manifest.configuration[:mysql][:version].should_not be_nil
      @manifest.configuration[:mysql][:version].should == 5.1
    end
  end

  context "Ubuntu Intrepid (8.10)" do
    before do
      Facter.stub!(:lsbdistrelease => '8.10')
      Facter.stub!(:lsbdistid => 'Ubuntu')
    end

    specify "MySQL version should be 5" do
      @manifest.mysql_server

      @manifest.configuration[:mysql][:version].should_not be_nil
      @manifest.configuration[:mysql][:version].should == 5
    end

  end
end
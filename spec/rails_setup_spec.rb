require 'spec_helper'

describe "MoonshineSetupManifest" do
  before do
    @user = 'user_from_capistrano'
    @application = 'app_from_capistrano'

    config = {:user => @user, :application => @application, :deploy_to => '/svr/application'}
    File.open( '/tmp/moonshine.yml', 'w' ) do |out|
      YAML.dump(config, out)
    end
    #hax: create the config file before we require the manifest
    require File.dirname(__FILE__) + '/../lib/moonshine_setup_manifest.rb'
    @manifest = MoonshineSetupManifest.new
  end

  after do
    FileUtils.rm_r("/tmp/moonshine.yml") rescue true
  end

  it "creates deploy_to directory" do
    @manifest.should use_recipe(:directories)
    
    @manifest.directories

    deploy_to = @manifest.files["#{@manifest.configuration[:deploy_to]}"]

    deploy_to.should_not == nil
    deploy_to.ensure.should == :directory
    deploy_to.owner.should == @user
    deploy_to.group.should == @user
  end

end

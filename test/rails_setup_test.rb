require 'test_helper'

class MoonshineSetupManifestTest < Test::Unit::TestCase

  def setup
    config = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'generators', 'moonshine', 'templates', 'moonshine.yml'))
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

  def teardown
    FileUtils.rm_r("/tmp/moonshine.yml") rescue true
  end

  def test_creates_directories
    assert @manifest.class.recipes.map(&:first).include?(:directories)
    @manifest.directories
    assert_not_nil deploy_to = @manifest.files["#{@manifest.configuration[:deploy_to]}"]
    assert_equal :directory, deploy_to.ensure
    assert_equal @user, deploy_to.owner
    assert_equal @user, deploy_to.group
  end

end
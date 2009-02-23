require File.dirname(__FILE__) + '/../../test_helper.rb'

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase

  def setup
    @manifest = Moonshine::Manifest::Rails.new
  end

  def test_loads_database_config
    assert_not_nil Moonshine::Manifest::Rails.configuration['database']['production']['encoding']
  end

  def test_loads_capistrano_config
    assert_not_nil Moonshine::Manifest::Rails.configuration['capistrano'].scm
  end

  def test_loads_gems_from_environment
    assert @manifest.class.recipes.map(&:first).include?(:gems_from_environment)
    @manifest.gems_from_environment
    assert_not_nil Moonshine::Manifest::Rails.configuration['rails'].gems
    assert_not_nil RAILS_GEM_VERSION
    Moonshine::Manifest::Rails.configuration['rails'].gems.each do |gem_dependency|
      assert_not_nil gem_resource = @manifest.puppet_resources[Puppet::Type::Package][gem_dependency.name]
      assert_equal gem_dependency.source, gem_resource.params[:source].value
      assert_equal :gem, gem_resource.params[:provider].value
    end
  end

  def test_creates_directories
    assert @manifest.class.recipes.map(&:first).include?(:directories)
    config = {
      :application => 'foo',
      :capistrano => @manifest.configuration['capistrano'],
      :user => 'foo',
      :deploy_to => '/srv/foo'
    }
    @manifest.expects(:configuration).at_least_once.returns(config)
    @manifest.directories
    assert_not_nil shared_dir = @manifest.puppet_resources[Puppet::Type::File]["/srv/foo/shared"]
    assert_equal :directory, shared_dir.params[:ensure].value
    assert_equal 'foo', shared_dir.params[:owner].value
    assert_equal 'foo', shared_dir.params[:group].value
  end
end
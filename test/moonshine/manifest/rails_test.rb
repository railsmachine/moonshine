require File.dirname(__FILE__) + '/../../test_helper.rb'

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase

  def setup
    @manifest = Moonshine::Manifest::Rails.new
  end

  def test_loads_database_config
    assert_equal 'utf8', Moonshine::Manifest::Rails.configuration['database']['production']['encoding']
  end

  def test_loads_capistrano_config
    assert_equal :git, Moonshine::Manifest::Rails.configuration['capistrano'].scm
  end

  def test_loads_gems_from_environment
    assert @manifest.class.recipes.map(&:first).include?(:gems_from_environment)
    @manifest.gems_from_environment
    assert_not_nil Moonshine::Manifest::Rails.configuration['rails'].gems
    assert_equal '2.2.2', RAILS_GEM_VERSION
    Moonshine::Manifest::Rails.configuration['rails'].gems.each do |gem_dependency|
      assert_not_nil gem_resource = @manifest.puppet_resources[Puppet::Type::Package][gem_dependency.name]
      assert_equal gem_dependency.requirement.to_s, gem_resource.params[:version].value
      assert_equal gem_dependency.source, gem_resource.params[:source].value
      assert_equal :gem, gem_resource.params[:provider].value
    end
  end

  def test_creates_directories
    assert @manifest.class.recipes.map(&:first).include?(:directories)
    @manifest.directories
    cap_config = @manifest.configuration['capistrano']
    assert_not_nil srv = @manifest.puppet_resources[Puppet::Type::File]["/srv"]
    assert_equal :directory, srv.params[:ensure].value
    assert_equal cap_config.user, srv.params[:owner].value
    assert_equal cap_config.user, srv.params[:group].value
    assert_not_nil srv_application = @manifest.puppet_resources[Puppet::Type::File]["/srv/#{cap_config.application}"]
    assert_equal :directory, srv_application.params[:ensure].value
    assert_equal cap_config.user, srv_application.params[:owner].value
    assert_equal cap_config.user, srv_application.params[:group].value
  end
end
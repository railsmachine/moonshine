require File.dirname(__FILE__) + '/../../test_helper.rb'

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase
  def test_loads_database_config
    assert_equal 'utf8', Moonshine::Manifest::Rails.configuration['database']['production']['encoding']
  end

  def test_loads_capistrano_config
    assert_equal :git, Moonshine::Manifest::Rails.configuration['capistrano'].scm
  end

  def test_loads_gems_from_environment
    @manifest = Moonshine::Manifest::Rails.new
    assert @manifest.class.recipes.map(&:first).include?(:gems_from_environment)
    @manifest.gems_from_environment
    assert_not_nil Moonshine::Manifest::Rails.configuration['rails'].gems
    assert_equal '2.2.2', RAILS_GEM_VERSION
    Moonshine::Manifest::Rails.configuration['rails'].gems.each do |gem_dependency|
      assert_equal gem_dependency.requirement.to_s, @manifest.puppet_resources[Puppet::Type::Package][gem_dependency.name].params[:version].value
      assert_equal gem_dependency.source, @manifest.puppet_resources[Puppet::Type::Package][gem_dependency.name].params[:source].value
      assert_equal :gem, @manifest.puppet_resources[Puppet::Type::Package][gem_dependency.name].params[:provider].value
    end
  end
end
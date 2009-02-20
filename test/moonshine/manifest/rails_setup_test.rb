require File.dirname(__FILE__) + '/../../test_helper.rb'
#this one isn't required anywhere else
require File.dirname(__FILE__) + '/../../../lib/moonshine/manifest/rails_setup.rb'

class Moonshine::Manifest::RailsSetupTest < Test::Unit::TestCase

  def setup
    @manifest = Moonshine::Manifest::RailsSetup.new
  end

  def test_has_gems_recipe
    assert @manifest.class.recipes.map(&:first).include?(:gems)
  end

  def test_installs_gems
    @manifest.gems
    assert_equal :gem, @manifest.puppet_resources[Puppet::Type::Package]["shadow_puppet"].params[:provider].value
    assert_equal :gem, @manifest.puppet_resources[Puppet::Type::Package]["shadow_facter"].params[:provider].value
    assert_equal :gem, @manifest.puppet_resources[Puppet::Type::Package]["capistrano"].params[:provider].value
  end
end
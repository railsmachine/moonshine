require File.dirname(__FILE__) + '/test_helper.rb'

class MooneshineRailsTest < Test::Unit::TestCase
  def test_includes_test_recipe
    assert Moonshine::Manifest::Rails.recipes.map(&:first).include?(:test)
  end
end

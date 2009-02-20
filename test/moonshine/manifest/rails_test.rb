require File.dirname(__FILE__) + '/../../test_helper.rb'

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase
  def test_loads_database_config
    assert_equal 'utf8', Moonshine::Manifest::Rails.configuration['database']['production']['encoding']
  end

  def test_loads_capistrano_config
    assert_equal :git, Moonshine::Manifest::Rails.configuration['capistrano'].scm
  end
end
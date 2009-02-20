require File.dirname(__FILE__) + '/../test_helper.rb'

class ManifestTest < Test::Unit::TestCase
  def test_loads_configuration
    assert Moonshine::Manifest::Rails.configuration.keys.include?('name')
  end

  def test_loads_database_config
    assert_equal 'utf8', Moonshine::Manifest::Rails.configuration['database']['production']['encoding']
  end
end
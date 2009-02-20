require File.dirname(__FILE__) + '/../test_helper.rb'

class Moonshine::ManifestTest < Test::Unit::TestCase
  def test_loads_configuration
    assert Moonshine::Manifest::Rails.configuration.keys.include?('application')
  end
end
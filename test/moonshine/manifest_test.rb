require File.dirname(__FILE__) + '/../test_helper.rb'

class Moonshine::ManifestTest < Test::Unit::TestCase
  def test_loads_configuration
    assert Moonshine::Manifest.configuration.keys.include?('application')
  end

  def test_provides_template_helper
    @manifest = Moonshine::Manifest.new
    config = '<%= configuration[:application] %>'
    @manifest.expects(:configuration).returns(:application => 'bar')
    File.expects(:read).with(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'templates', 'passenger.conf.erb'))).returns(config)
    assert_equal 'bar', @manifest.template('passenger.conf.erb')
  end

end
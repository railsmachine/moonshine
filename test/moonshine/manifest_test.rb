require File.dirname(__FILE__) + '/../test_helper.rb'

module Moonshine::Iptables
end

class Moonshine::ManifestTest < Test::Unit::TestCase
  def test_loads_configuration
    assert_not_nil Moonshine::Manifest.configuration[:application]
  end

  def test_provides_template_helper
    @manifest = Moonshine::Manifest.new
    config = '<%= configuration[:application] %>'
    @manifest.expects(:configuration).returns(:application => 'bar')
    path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'moonshine', 'templates', 'passenger.conf.erb'))
    File.expects(:exist?).with(File.expand_path(File.join(@manifest.rails_root, 'app', 'manifest', 'templates', 'passenger.conf.erb'))).returns(false)
    File.expects(:exist?).with(path).returns(true)
    File.expects(:read).with(path).returns(config)
    assert_equal 'bar', @manifest.template(path)
  end

  def test_app_templates_override_moonshine_templates
    @manifest = Moonshine::Manifest.new
    config = '<%= configuration[:application] %>'
    @manifest.expects(:configuration).returns(:application => 'bar')
    path = File.expand_path(File.join(@manifest.rails_root, 'app', 'manifest', 'templates', 'passenger.conf.erb'))
    File.expects(:exist?).with(path).returns(true)
    File.expects(:read).with(path).returns(config)
    assert_equal 'bar', @manifest.template(path)
  end

  def test_loads_plugins
    File.expects(:read).returns("""
configure(:eval => true)

module EvalTest
  def foo

  end
end

include EvalTest
recipe :foo
""")
    assert Moonshine::Manifest.plugin(:iptables)
    assert Moonshine::Manifest.configuration[:eval]
    @manifest = Moonshine::Manifest.new
    assert @manifest.respond_to?(:foo)
    assert @manifest.class.recipes.map(&:first).include?(:foo)
  end

  def test_loads_database_config
    assert_equal 'utf8', Moonshine::Manifest.configuration[:database][:production][:encoding]
  end

end
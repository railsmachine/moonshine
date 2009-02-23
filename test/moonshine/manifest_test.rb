require File.dirname(__FILE__) + '/../test_helper.rb'

module Moonshine::Iptables
end

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

  def test_loads_plugins
    Kernel.expects(:require).with(File.expand_path(File.join(Moonshine::Manifest.working_directory, 'vendor', 'plugins', 'moonshine_iptables', 'lib', 'moonshine', 'iptables.rb'))).returns(true)
    Module.expects(:include).with(Moonshine::Iptables)
    begin
      assert Moonshine::Manifest.plugin('iptables')
    rescue MissingSourceFile
    end
  end

  def test_loads_database_config
    assert_not_nil Moonshine::Manifest.configuration['database']['production']['encoding']
  end

  def test_loads_capistrano_config
    assert_not_nil Moonshine::Manifest.configuration['capistrano'].scm
  end

end
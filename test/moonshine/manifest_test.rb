require File.dirname(__FILE__) + '/../test_helper.rb'

module Moonshine::Iptables
end

class Moonshine::ManifestTest < Test::Unit::TestCase

  def test_loads_configuration
    assert_not_nil Moonshine::Manifest.configuration[:application]
  end

  def test_provides_template_helper
    @manifest = Moonshine::Manifest.new
    @manifest.configure(:application => 'bar')
    template = 'template: <%= configuration[:application] %>'
    plugin_template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'moonshine', 'templates', 'passenger.conf.erb'))
    app_template_path = File.expand_path(File.join(@manifest.rails_root, 'app', 'manifests', 'templates', 'passenger.conf.erb'))
    File.expects(:exist?).with(app_template_path).returns(false)
    File.expects(:exist?).with(plugin_template_path).returns(true)
    File.expects(:read).with(plugin_template_path).returns(template)
    assert_equal 'template: bar', @manifest.template(plugin_template_path)
  end

  def test_app_templates_override_moonshine_templates
    @manifest = Moonshine::Manifest.new
    @manifest.configure(:application => 'bar')
    template = 'app_template: <%= configuration[:application] %>'
    app_template_path = File.expand_path(File.join(@manifest.rails_root, 'app', 'manifests', 'templates', 'passenger.conf.erb'))
    File.expects(:exist?).with(app_template_path).returns(true)
    File.expects(:read).with(app_template_path).returns(template)
    assert_equal 'app_template: bar', @manifest.template(app_template_path)
  end

  def test_loads_plugins
    @manifest = Moonshine::Manifest.new
    File.expects(:read).with(File.expand_path(File.join(@manifest.rails_root, 'vendor', 'plugins', 'moonshine_iptables', 'moonshine','init.rb'))).returns("""
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
    assert_not_nil 'utf8', Moonshine::Manifest.configuration[:database][:production]
  end

  def test_on_stage_runs_when_string_stage_matches
    @manifest = Moonshine::Manifest.new
    @manifest.expects(:deploy_stage).returns("my_stage")

    assert_equal 'on my_stage', @manifest.on_stage("my_stage") { "on my_stage" }
  end

  def test_on_stage_runs_when_symbol_stage_matches
    @manifest = Moonshine::Manifest.new
    @manifest.expects(:deploy_stage).returns("my_stage")
    assert_equal 'on my_stage', @manifest.on_stage(:my_stage) { "on my_stage" }
  end

  def test_on_stage_does_not_run_when_string_stage_does_not_match
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_nil @manifest.on_stage("my_stage") { "on my_stage" }
  end

  def test_on_stage_does_not_run_when_symbol_stage_does_not_match
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_nil @manifest.on_stage(:my_stage) { "on my_stage" }
  end

  def test_on_stage_runs_when_stage_included_in_string_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_equal 'on one of my stages', @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }
    @manifest.expects(:deploy_stage).returns("my_other_stage")
    assert_equal 'on one of my stages', @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }
  end

  def test_on_stage_runs_when_stage_included_in_symbol_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_equal 'on one of my stages', @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }
    @manifest.expects(:deploy_stage).returns("my_other_stage")
    assert_equal 'on one of my stages', @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }
  end

  def test_on_stage_does_not_run_when_stage_not_in_string_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_nil @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }
  end

  def test_on_stage_does_not_run_when_stage_not_in_symbol_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_nil @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }
  end

  def test_on_stage_unless_does_not_run_when_string_stage_matches
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_nil @manifest.on_stage(:unless => "my_stage") { "not on one of my stages" }
  end

  def test_on_stage_unless_does_not_run_when_symbol_stage_matches
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_nil @manifest.on_stage(:unless => :my_stage) { "not on one of my stages" }
  end

  def test_on_stage_unless_runs_when_string_stage_does_not_match
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_equal 'not on one of my stages', @manifest.on_stage(:unless => "not_my_stage") { "not on one of my stages" }
  end

  def test_on_stage_unless_runs_when_symbol_stage_does_not_match
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_equal 'not on one of my stages', @manifest.on_stage(:unless => :not_my_stage) { "not on one of my stages" }
  end

  def test_on_stage_unless_does_not_runs_when_stage_in_string_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_nil @manifest.on_stage(:unless => ["my_stage", "my_other_stage"]) { "not on one of my stages" }
  end

  def test_on_stage_unless_does_not_runs_when_stage_in_symbol_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("my_stage")
    assert_nil @manifest.on_stage(:unless => [:my_stage, :my_other_stage]) { "not on one of my stages" }
  end

  def test_on_stage_unless_runs_when_stage_not_in_string_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_equal "not on one of my stages", @manifest.on_stage(:unless => ["my_stage", "my_other_stage"]) { "not on one of my stages" }
  end

  def test_on_stage_unless_runs_when_stage_not_in_symbol_array
    @manifest = Moonshine::Manifest.new
    @manifest.stubs(:deploy_stage).returns("not_my_stage")
    assert_equal "not on one of my stages", @manifest.on_stage(:unless => [:my_stage, :my_other_stage]) { "not on one of my stages" }
  end
end
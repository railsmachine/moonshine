require 'test_helper'

module Moonshine::Iptables
end

class Moonshine::ManifestTest < Test::Unit::TestCase

  def test_loads_configuration
    assert_not_nil Moonshine::Manifest.configuration
    assert_not_nil Moonshine::Manifest.configuration[:application]
  end

  def test_loads_environment_specific_configuration
    assert_equal 'what what what', Moonshine::Manifest.configuration[:test_yaml]
  end

  def test_moonshine_templates
    @manifest = Moonshine::Manifest.new
    @manifest.configure(:application => 'bar')

    moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'templates', 'passenger.conf.erb')
    template_contents = 'moonshine template: <%= configuration[:application] %>'
    moonshine_template.expects(:exist?).returns(true)
    moonshine_template.expects(:read).returns(template_contents)

    application_template = @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
    application_template.expects(:exist?).returns(false)

    @manifest.stubs(:local_template).returns(application_template)

    assert_equal 'moonshine template: bar', @manifest.template(moonshine_template)
  end

  def test_app_templates_override_moonshine_templates
    @manifest = Moonshine::Manifest.new
    @manifest.configure(:application => 'bar')

    moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'templates', 'passenger.conf.erb')

    application_template = @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
    template_contents = 'application template: <%= configuration[:application] %>'
    application_template.expects(:exist?).returns(true)
    application_template.expects(:read).returns(template_contents)

    @manifest.stubs(:local_template).returns(application_template)

    assert_equal 'application template: bar', @manifest.template(moonshine_template)
  end

  def test_loads_plugins
    @manifest = Moonshine::Manifest.new
    assert Moonshine::Manifest.plugin(:iptables)
    # eval is configured in test/rails_root/vendor/plugins/moonshine_eval_test/moonshine/init.rb
    assert Moonshine::Manifest.configuration[:eval]
    @manifest = Moonshine::Manifest.new
    assert @manifest.respond_to?(:foo)
    assert @manifest.class.recipes.map(&:first).include?(:foo)
  end

  def test_loads_database_config
    assert_not_equal nil, Moonshine::Manifest.configuration[:database]
    assert_equal 'production', Moonshine::Manifest.configuration[:database][:production]
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

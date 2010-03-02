require 'test_helper'

module Moonshine::Iptables
end

class Moonshine::ManifestTest < Test::Unit::TestCase

  def teardown
    if @manifest && application_template && application_template.exist?
      application_template.delete
    end
  end

  def test_loads_configuration
    assert_not_nil Moonshine::Manifest.configuration
    assert_not_nil Moonshine::Manifest.configuration[:application]
  end

  def test_loads_environment_specific_configuration
    assert_equal 'what what what', Moonshine::Manifest.configuration[:test_yaml]
  end

  def test_moonshine_templates
    @manifest = Moonshine::Manifest::Rails.new
    @manifest.configure(:application => 'bar')

    moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'manifest', 'rails', 'templates', 'passenger.vhost.erb')
    template_contents = 'moonshine template: <%= configuration[:application] %>'
    @manifest.stubs(:local_template).returns(application_template)

    assert_match 'ServerName yourapp.com', @manifest.template(moonshine_template)
  end

  def application_template
    @application_template ||= @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
  end

  def test_app_templates_override_moonshine_templates
    @manifest = Moonshine::Manifest.new
    @manifest.configure(:application => 'bar')

    application_template.open('w') {|f| f.write "application template: <%= configuration[:application] %>" }

    moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'manifest', 'rails', 'templates', 'passenger.conf.erb')
    application_template = @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
    assert application_template.exist?, "#{application_template} should exist, but didn't"
    assert moonshine_template.exist?, "#{moonshine_template} should exist, but didn't"

    # should return the output from that existing thing
    assert_match 'application template: bar', @manifest.template(moonshine_template)
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

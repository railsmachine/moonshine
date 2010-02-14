require 'test_helper'
class MoonshinePluginGeneratorTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(generator_rails_root)
    Rails::Generator::Scripts::Generate.new.run(["moonshine_plugin","iptables"], :destination => generator_rails_root)
  end

  def teardown
    FileUtils.rm_r(generator_rails_root)
  end

  def test_generates_correct_files
    assert readme_path.exist?
    assert init_path.exist?
    assert module_path.exist?
    assert spec_path.exist?
  end

  def test_generates_plugin_module
    assert_match /module Iptables/, module_path.read
  end
  
  def test_includes_plugin_module
    assert_match /require ".*iptables\.rb"/, init_path.read
    assert_match /include Iptables/, init_path.read
  end

  private

    def plugin_path
      generator_rails_root + 'vendor/plugins/moonshine_iptables'
    end

    def module_path
      plugin_path + 'lib/iptables.rb'
    end

    def init_path
      plugin_path + 'moonshine/init.rb'
    end

    def readme_path
      plugin_path + 'README.rdoc'
    end

    def spec_path
      plugin_path + 'spec/iptables_spec.rb'
    end

    def spec_helper_path
      plugin_path + 'spec/spec_helper.rb'
    end

end

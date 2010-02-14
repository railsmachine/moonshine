require 'test_helper'
class MoonshinePluginGeneratorTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(generator_rails_root)
    @original_files = file_list
    Rails::Generator::Scripts::Generate.new.run(["moonshine_plugin","iptables"], :destination => generator_rails_root)
    @new_files = (file_list - @original_files)
  end

  def teardown
    FileUtils.rm_r(generator_rails_root)
  end

  def test_generates_correct_files
    assert File.exist?(init_path)
    assert File.exist?(module_path)
  end

  def test_generates_plugin_module
    assert_match /module Iptables/, File.read(module_path)
  end
  
  def test_includes_plugin_module
    assert_match /require ".*iptables\.rb"/,File.read(init_path)
    assert_match /include Iptables/, File.read(init_path)
  end

  private

    def module_path
      "#{generator_rails_root}/vendor/plugins/moonshine_iptables/lib/iptables.rb"
    end

    def init_path
      "#{generator_rails_root}/vendor/plugins/moonshine_iptables/moonshine/init.rb"
    end

    def file_list
      Dir.glob("#{generator_rails_root}/*")
    end

end

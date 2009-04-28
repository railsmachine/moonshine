require File.dirname(__FILE__) + '/test_helper.rb'
require 'rails_generator'
require 'rails_generator/scripts/generate'

class MoonshinePluginGeneratorTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(fake_rails_root)
    @original_files = file_list
    Rails::Generator::Scripts::Generate.new.run(["moonshine_plugin","iptables"], :destination => fake_rails_root)
    @new_files = (file_list - @original_files)
  end

  def teardown
    FileUtils.rm_r(fake_rails_root)
  end

  def test_generates_correct_files
    assert @new_files.include?(init_path)
    assert @new_files.include?(module_path)
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
      './test/rails_root/vendor/plugins/moonshine_iptables/lib/iptables.rb'
    end

    def init_path
      './test/rails_root/vendor/plugins/moonshine_iptables/moonshine/init.rb'
    end

    def fake_rails_root
      File.join(File.dirname(__FILE__), 'rails_root')
    end

    def file_list
      Dir.glob(File.join(fake_rails_root, "vendor/plugins/moonshine_iptables/*")) + 
      Dir.glob(File.join(fake_rails_root, "vendor/plugins/moonshine_iptables/moonshine/*")) + 
      Dir.glob(File.join(fake_rails_root, "vendor/plugins/moonshine_iptables/lib/*"))
    end

end

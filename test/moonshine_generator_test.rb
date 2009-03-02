require File.dirname(__FILE__) + '/test_helper.rb'
require 'rails_generator'
require 'rails_generator/scripts/generate'
require 'yaml'

class MoonshineGeneratorTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(fake_rails_root)
    @original_files = file_list
    Rails::Generator::Scripts::Generate.new.run(["moonshine"], :destination => fake_rails_root)
    @new_files = (file_list - @original_files)
  end

  def teardown
    FileUtils.rm_r(fake_rails_root)
  end

  def test_generates_correct_files
    assert @new_files.include?(config_path)
    assert @new_files.include?(manifest_path)
    assert @new_files.include?(templates_path)
    assert @new_files.include?(gems_path)
  end

  def test_generates_valid_config_file
    assert_instance_of Hash, YAML.load_file(config_path)
  end

  def test_generates_application_manifest
    assert_match /class ApplicationManifest < Moonshine::Manifest::Rails/, File.read(manifest_path)
  end

  def test_generates_gem_dependencies
    assert_not_nil YAML.load_file(gems_path).first
  end

  private

    def manifest_path
      './test/rails_root/app/manifests/application_manifest.rb'
    end

    def gems_path
      './test/rails_root/config/gems.yml'
    end

    def config_path
      './test/rails_root/config/moonshine.yml'
    end

    def templates_path
      './test/rails_root/app/manifests/templates'
    end

    def fake_rails_root
      File.join(File.dirname(__FILE__), 'rails_root')
    end

    def file_list
      Dir.glob(File.join(fake_rails_root, "/app/manifests/*")) + Dir.glob(File.join(fake_rails_root, "/config/*"))
    end

end

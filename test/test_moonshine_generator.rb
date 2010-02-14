require 'test_helper'

class MoonshineGeneratorTest < Test::Unit::TestCase
  if Rails::VERSION::MAJOR < 3
    require 'yaml'

    def setup
      FileUtils.mkdir_p(generator_rails_root)

      @original_files = file_list

      Rails::Generator::Scripts::Generate.new.run(["moonshine"], :destination => generator_rails_root)
      @new_files = (file_list - @original_files)
    end

    def teardown
      FileUtils.rm_r(generator_rails_root)
    end

    def test_generates_correct_files
      assert File.exist?(capfile_path)
      assert File.exist?(manifest_path)
      assert File.exist?(templates_path)
      assert File.exist?(config_path)
      assert File.exist?(gems_path)
      assert File.exist?(deploy_path)
    end

    def test_generates_valid_config_file
      assert_instance_of Hash, configuration
    end

    def test_generates_application_manifest_class
      assert_match /class ApplicationManifest < Moonshine::Manifest::Rails/, File.read(manifest_path)
    end

    def test_generates_gem_dependencies
      assert_not_nil YAML.load_file(gems_path).first
    end

    def test_application_is_rails_root_basename
      assert_equal File.basename(RAILS_ROOT), configuration[:application]
    end

    def test_user_is_rails
      assert_equal 'rails', configuration[:user]
    end

    def test_ruby_is_ree
      assert_equal 'ree', configuration[:ruby]
    end

    def test_domain_is_yourapp_dot_com
      assert_equal 'yourapp.com', configuration[:domain]
    end

    def test_deploy_rb_has_simple_configuration
      assert_equal "server 'yourapp.com', :app, :web, :db, :primary => true\n", deploy_path.read
    end
    
    def test_deploy_to_uses_application_name
      assert_equal "/srv/#{configuration[:application]}", configuration[:deploy_to]
    end

    def test_detects_repository_from_git
      assert_equal configuration[:repository], `git config remote.origin.url`.chomp
    end

    private

    def configuration
      YAML.load_file(config_path)
    end

    def manifest_path
      "#{generator_rails_root}/app/manifests/application_manifest.rb"
    end

    def gems_path
      "#{generator_rails_root}/config/gems.yml"
    end

    def config_path
      "#{generator_rails_root}/config/moonshine.yml"
    end

    def templates_path
      "#{generator_rails_root}/app/manifests/templates"
    end

    def capfile_path
      generator_rails_root + 'Capfile'
    end

    def deploy_path
      generator_rails_root + 'config' + 'deploy.rb'
    end

    def file_list
      Dir.glob("#{generator_rails_root}/*")
    end

  end
end

require 'spec_helper'
require 'yaml'

describe "MoonshineGenerator" do
  if Rails::VERSION::MAJOR < 3

    def run(*args)
      lambda {
        Dir.chdir generator_rails_root do
          Rails::Generator::Scripts::Generate.new.run(["moonshine"] + args.flatten, :destination => generator_rails_root)
        end
      }.should_not raise_error
    end

    before do
      FileUtils.mkdir_p(generator_rails_root)
    end

    after do
      FileUtils.rm_rf(generator_rails_root)
    end

    context "run with no args" do
      before do
        run
      end

      it "generates Capfile" do
        capfile_path.should exist
      end

      it "generates valid config/moonshine.yml" do
        moonshine_yml_path.should exist
        configuration.should be_kind_of(Hash)
      end

      it "generates app/manifests/templates" do
        templates_path.should exist
      end

      it "generates app/manifets/templates/README" do
        templates_readme_path.should exist
      end

      it "generates ApplicationManifest in app/manifests/application_manifest.rb as a subclass of Moonshine::Manifest::Rails" do
        manifest_path.should exist
        manifest_path.read.should match(/class ApplicationManifest < Moonshine::Manifest::Rails/)
      end

      it "generates an initial config/gems.yml" do
        gems_path.should exist
        YAML.load_file(gems_path).first.should_not == nil
      end

      it "generates config/deploy.rb" do
        deploy_path.should exist
      end

      it "configures Capistrano to deploy to the default domain in all roles" do
        deploy_path.read.should include("server 'yourapp.com', :app, :web, :db, :primary => true")
      end

      it "configures application as rails_root's basename" do
        configuration[:application].should == File.basename(RAILS_ROOT)
      end

      it "configures user as 'rails'" do
        configuration[:user].should == 'rails'
      end

      it "configures ree as the ruby vm" do
        configuration[:ruby].should == 'ree187'
      end

      it "configures a default value for domain" do
        configuration[:domain].should == 'yourapp.com'
      end

      it "configures a default value for repository" do
        configuration[:repository].should == 'git@github.com:username/your_app_name.git'
      end

      it "creates a simple config/deploy.rb" do
        deploy_path.read.should == "server 'yourapp.com', :app, :web, :db, :primary => true\n"
      end

      it "configures deploy_to to be under /srv under application" do
        configuration[:deploy_to].should == "/srv/#{configuration[:application]}"
      end

      it "configures passenger with 3 workers" do
        configuration[:passenger][:max_pool_size].should == 3
      end

      it "configures mysql with 128M innodb buffer pool size" do
        configuration[:mysql][:innodb_buffer_pool_size].should == "128M"
      end

    end

    context "run in a git repository with an origin" do
      before do
        Dir.chdir generator_rails_root do
          `git init`
          `git remote add origin git@github.com:zombo/zombo.com.git`
        end

        run
      end

      it "detects repository from `git config remote.origin.url`" do
        configuration[:repository].should == "git@github.com:zombo/zombo.com.git"
      end
    end

    context "run with --user foo" do
      before do
        run %w(--user foo)
      end

      it "configures user as 'foo'" do
        configuration[:user].should == 'foo'
      end
    end

    context "run with --domain zombo.com" do
      before do
        run %w(--domain zombo.com)
      end

      it "configures zombo.dom for domain" do
        configuration[:domain].should == 'zombo.com'
      end
    end

    context "run with --ruby ree187" do
      before do
        run %w(--ruby ree)
      end

      it "configures ree187 as the ruby vm" do
        configuration[:ruby].should == 'ree'
      end
    end

    context "run with --ruby ree187" do
      before do
        run %w(--ruby ree187)
      end

      it "configures ree187 as the ruby vm" do
        configuration[:ruby].should == 'ree187'
      end
    end
  end

  private

  def configuration
    YAML.load_file(moonshine_yml_path)
  end

  def manifest_path
    generator_rails_root + 'app/manifests/application_manifest.rb'
  end

  def gems_path
    generator_rails_root + 'config/gems.yml'
  end

  def moonshine_yml_path
    generator_rails_root + 'config/moonshine.yml'
  end

  def templates_path
    generator_rails_root + 'app/manifests/templates'
  end

  def templates_readme_path
    templates_path + 'README'
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

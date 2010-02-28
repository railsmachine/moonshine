require 'spec_helper'

describe MoonshineGenerator do
  if Rails::VERSION::MAJOR < 3
    require 'yaml'

    before do
      FileUtils.mkdir_p(generator_rails_root)

      Rails::Generator::Scripts::Generate.new.run(["moonshine"], :destination => generator_rails_root)
    end

    after do
      FileUtils.rm_r(generator_rails_root)
    end

    it "generates correct files" do
      capfile_path.should exist
      manifest_path.should exist
      templates_path.should exist
      config_path.should exist
      gems_path.should exist
      deploy_path.should exist
    end

    it "generates valid config" do
      configuration.should be_kind_of(Hash)
    end

    it "generates ApplicationManifest as a subclass of Moonshine::Manifest::Rails" do
      manifest_path.read.should match(/class ApplicationManifest < Moonshine::Manifest::Rails/)
    end

    it "generates gem dependencies" do
      YAML.load_file(gems_path).first.should_not == nil
    end

    it "configures application as rails_root's basename" do
      configuration[:application].should == File.basename(RAILS_ROOT)
    end

    it "configures user as 'rails'" do
      configuration[:user].should == 'rails'
    end

    it "configures ree as the ruby vm" do
      configuration[:ruby].should == 'ree'
    end

    it "configures a default value for domain" do
      configuration[:domain].should == 'yourapp.com'
    end

    it "creates a simple config/deploy.rb" do
      deploy_path.read.should == "server 'yourapp.com', :app, :web, :db, :primary => true\n"
    end
    
    it "configures deploy_to to be under /srv under application" do
      configuration[:deploy_to].should == "/srv/#{configuration[:application]}"
    end

    it "detects repository from `git config remote.origin.url`" do
      configuration[:repository].should == `git config remote.origin.url`.chomp
    end

    private

    def configuration
      YAML.load_file(config_path)
    end

    def manifest_path
      generator_rails_root + 'app/manifests/application_manifest.rb'
    end

    def gems_path
      generator_rails_root + 'config/gems.yml'
    end

    def config_path
      generator_rails_root + 'config/moonshine.yml'
    end

    def templates_path
      generator_rails_root + 'app/manifests/templates'
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

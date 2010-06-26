require 'spec_helper'

require 'moonshine/capistrano_integration'

describe Moonshine::CapistranoIntegration, "loaded into a configuration" do
  before do
    ENV['RAILS_ROOT'] = fake_rails_root
    @configuration = Capistrano::Configuration.new
    Moonshine::CapistranoIntegration.load_into(@configuration)
  end

  subject { @configuration }

  context "default configuration" do
    its(:repository) { should == "" }
    its(:application) { should == "" }
    its(:rails_env) { should == 'production' }
    its(:stage) { should be_nil }

  end

  it "keeps 5 releases" do
    @configuration.keep_releases.should == 5
  end

  it "sets rails_root from ENV['RAILS_ROOT']" do
    @configuration.rails_root.should == fake_rails_root
  end

  it "does moonshine:configure on start" do
    @configuration.should callback('moonshine:configure').on(:start)
  end

  it "performs deploy:cleanup after deploy:restart" do
    @configuration.should callback('deploy:cleanup').after('deploy:restart')
  end

  it "performs moonshine:apply before deploy:symlink" do
    callbacks = find_callback(@configuration, :before, 'deploy:symlink')
    callbacks.should_not be_nil

    callback = callbacks.first
    callback.should_not be_nil
    
    @configuration.namespace :moonshine do
      should_receive(:apply)
    end

    callback.call
  end

  context "on default stage" do
    it "sets rails_env to production" do
      @configuration.rails_env.should == 'production'
    end
  end

  context "on staging stage" do
    before do
      @configuration.set(:stage, 'staging')
    end
    it "sets rails_env to staging" do
      @configuration.rails_env.should == 'staging'
    end
  end

  context "on production stage" do
    before do
      @configuration.set(:stage, 'production')
    end
    it "sets rails_env to staging" do
      @configuration.rails_env.should == 'production'
    end
  end

  context "scm" do
    it "defaults to git" do
      @configuration.scm.should == :git
    end

    it "enables git submodules" do
      @configuration.git_enable_submodules.should == 1
    end
  end

  context "ssh options" do
    it "is made unparanoid" do
      @configuration.ssh_options[:paranoid].should == false
    end

    it "forwards key agents" do
      @configuration.ssh_options[:forward_agent].should == true
    end
  end

  context "moonshine:configure" do
    before do
      @configuration.find_and_execute_task("moonshine:configure")
    end

    it "loads moonshine.yml into configuration" do
      @configuration.application.should == 'zomg'
    end

    context "shared_config" do
      before do
        @shared_config = @configuration.shared_config.moonshine_yml[:shared_config]
        @configuration.set :shared_path, '/srv/app/shared'
        @configuration.set :latest_release, '/srv/app/releases/20100601'
      end

      it "has some items in shared_config" do
        @shared_config.should have(2).items
        @shared_config.should include("config/database.yml")
      end

      it "uploads files from fake rails root to the server" do
        @configuration.should_receive(:run).with("mkdir -p '/srv/app/shared/config/sample'")
        @configuration.should_receive(:upload).with("config/sample/foo", "/srv/app/shared/config/sample/foo")

        @configuration.should_receive(:run).with("mkdir -p '/srv/app/shared/config'")
        @configuration.should_receive(:upload).with("config/database.yml", "/srv/app/shared/config/database.yml")

        @configuration.find_and_execute_task('shared_config:upload')
      end

      it "downloads files from the server to the fake rails root" do
        @configuration.should_receive(:get).with("/srv/app/shared/config/sample/foo", "config/sample/foo")
        @configuration.should_receive(:get).with("/srv/app/shared/config/database.yml", "config/database.yml")

        @configuration.find_and_execute_task('shared_config:download')
      end

      it "symlinks files on the server" do
        @configuration.should_receive(:run).with("mkdir -p '/srv/app/releases/20100601/config/sample'")

        @configuration.should_receive(:run).with("ls /srv/app/releases/20100601/config/sample/foo 2> /dev/null || ln -nfs /srv/app/shared/config/sample/foo /srv/app/releases/20100601/config/sample/foo")

        @configuration.should_receive(:run).with("mkdir -p '/srv/app/releases/20100601/config'")
        @configuration.should_receive(:run).with("ls /srv/app/releases/20100601/config/database.yml 2> /dev/null || ln -nfs /srv/app/shared/config/database.yml /srv/app/releases/20100601/config/database.yml")

        @configuration.find_and_execute_task('shared_config:symlink')
      end

      def full_path(path)
        @configuration.rails_root.join(path)
      end
    end
  end
end

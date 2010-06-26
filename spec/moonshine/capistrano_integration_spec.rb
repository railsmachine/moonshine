require 'spec_helper'

require 'moonshine/capistrano_integration'

describe Moonshine::CapistranoIntegration, "loaded into a configuration" do
  before do
    ENV['RAILS_ROOT'] = fake_rails_root
    @configuration = Capistrano::Configuration.new
    Moonshine::CapistranoIntegration.load_into(@configuration)
  end

  it "defaults :repository to blank" do
    @configuration.repository.should == ""
  end

  it "defaults :application to blank" do
    @configuration.application.should == ""
  end

  it "defaults :rails_env to production" do
    @configuration.rails_env.should == "production"
  end

  it "sets no stage" do
    @configuration[:stage].should be_nil
  end

  it "defaults :keep_releases to 2" do
    @configuration.keep_releases.should == 2
  end

  it "sets rails_root from ENV['RAILS_ROOT]'" do
    @configuration.rails_root.should == fake_rails_root
  end

  it "does moonshine:configure on start" do
    @configuration.callbacks[:start].should_not be_nil

    moonshine_configure = @configuration.callbacks[:start].select do |task_callback|
      task_callback.source == 'moonshine:configure'
    end

    moonshine_configure.should_not be_nil
  end

  it "performs deploy:cleanup after deploy:restart" do
    @configuration.callbacks[:after].should_not be_nil

    moonshine_configure = @configuration.callbacks[:after].select do |task_callback|
      task_callback.source == 'deploy:cleanup'
    end

    moonshine_configure.should_not be_nil
  end

  it "performs moonshine:apply before deploy:symlink" do
    @configuration.callbacks[:before].should_not be_nil

    moonshine_configure = @configuration.callbacks[:before].select do |task_callback|
      task_callback.source == 'deploy:cleanup'
    end

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
      end

      it "has some items in shared_config" do
        @shared_config.should have(2).items
        @shared_config.should include "config/database.yml"
      end

      it "uploads files to the fake rails root" do
        pending
      end

      it "downloads files from the fake rails root" do
        pending
      end

      it "symlinks files to the fake rails root" do
        pending
      end

      def full_path(path)
        @configuration.rails_root.join(path)
      end
    end
  end
end

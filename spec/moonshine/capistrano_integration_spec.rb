require 'spec_helper'

require 'moonshine/capistrano_integration'

describe Moonshine::CapistranoIntegration, "loaded into a configuration" do
  before do
    ENV['RAILS_ROOT'] = fake_rails_root
    @configuration = Capistrano::Configuration.new
    @configuration.extend(Capistrano::Spec::ConfigurationExtension)
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

  it "does moonshine:configure_stage after multistage:ensure" do
    @configuration.should callback('moonshine:configure_stage').after('multistage:ensure')
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

  it "performs moonshine:noop_apply before deploy:symlink" do
    @configuration.set :noop, true
    @configuration.set :shared_path, '/srv/app/shared'
    @configuration.set :latest_release, '/srv/app/releases/20100601'
    callbacks = find_callback(@configuration, :before, 'deploy:symlink')
    callbacks.should_not be_nil

    callback = callbacks.first
    callback.should_not be_nil
    
    @configuration.namespace :moonshine do
      should_receive(:noop_apply)
    end

    callback.call
  end

  context "noop deploy" do
    before do
      @configuration.set :noop, true
      @configuration.set :shared_path, '/srv/app/shared'
      @configuration.set :latest_release, '/srv/app/releases/20100601'
      @configuration.set :rails_env, :staging
      @configuration.set :stage, :staging
      @configuration.set :moonshine_manifest, 'application_manifest'
    end

    it "should execute noop_apply" do
      pending "Needs some tweaks to cap integration handling"
      apply_cmd = "sudo sh -c 'RAILS_ROOT=#{latest_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE'] || fetch(:stage)} RAILS_ENV=#{fetch(:rails_env)} shadow_puppet #{'--noop' if noop} #{latest_release}/app/manifests/#{fetch(:moonshine_manifest)}.rb'"
      # should run noop
      noop = true
      @configuration.should have_run(apply_cmd)
      # should not run go-op
      noop = false
      @configuration.should_not have_run(apply_cmd)
    end

    it "should rollback the release" do
      pending "Needs some tweaks to cap integration handling"
    end

    it "rolling back the noop release should not restart passenger" do
      pending "Needs some tweaks to cap integration handling"
      @configuration.should_not have_run("touch tmp/restart.txt")
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

    it "does not load rails environment specific configuration" do
      @configuration[:test_yaml].should be_nil
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
        @configuration.find_and_execute_task('shared_config:upload')

        @configuration.should have_run("mkdir -p '/srv/app/shared/config/sample'")
        @configuration.should have_uploaded("config/sample/foo").to("/srv/app/shared/config/sample/foo")

        @configuration.should have_run("mkdir -p '/srv/app/shared/config'")
        @configuration.should have_uploaded("config/database.yml").to("/srv/app/shared/config/database.yml")

      end

      it "downloads files from the server to the fake rails root" do
        @configuration.find_and_execute_task('shared_config:download')

        @configuration.should have_gotten("/srv/app/shared/config/sample/foo").to("config/sample/foo")
        @configuration.should have_gotten("/srv/app/shared/config/database.yml").to("config/database.yml")
      end

      it "symlinks files on the server" do
        @configuration.find_and_execute_task('shared_config:symlink')

        @configuration.should have_run("mkdir -p '/srv/app/releases/20100601/config/sample'")

        @configuration.should have_run("ls /srv/app/releases/20100601/config/sample/foo 2> /dev/null || ln -nfs /srv/app/shared/config/sample/foo /srv/app/releases/20100601/config/sample/foo")

        @configuration.should have_run("mkdir -p '/srv/app/releases/20100601/config'")
        @configuration.should have_run("ls /srv/app/releases/20100601/config/database.yml 2> /dev/null || ln -nfs /srv/app/shared/config/database.yml /srv/app/releases/20100601/config/database.yml")
      end

      def full_path(path)
        @configuration.rails_root.join(path)
      end
    end

  end

  context "moonshine:configure_multistage" do
    context "when a environment specific yaml exists" do
      before do
        # TODO have need a way to have a more realistic multistage env going
        @configuration.set(:stage, 'test')
        @configuration.find_and_execute_task("moonshine:configure_stage")
      end

      it "loads rails environment specific configuration" do
        @configuration[:test_yaml].should == 'what what what'
      end
    end

    context "when a environment specific yaml does not exist" do
      before do
        # TODO have need a way to have a more realistic multistage env going
        @configuration.set(:stage, 'staging')
        @configuration.find_and_execute_task("moonshine:configure_stage")
      end

      it "doesn't loads rails environment specific configuration" do
        @configuration[:test_yaml].should == nil
      end
    end
  end

end

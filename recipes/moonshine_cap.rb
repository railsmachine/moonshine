set :branch, 'master'
set :scm, :git
set :git_shallow_clone, 1
set :git_enable_submodules, 1
ssh_options[:paranoid] = false
ssh_options[:forward_agent] = true
default_run_options[:pty] = true

#load the moonshine configuration into
require 'yaml'
begin
  hash = YAML.load_file(File.join((ENV['RAILS_ROOT'] || Dir.pwd), 'config', 'moonshine.yml'))
  hash.each do |key, value|
    set(key.to_sym, value)
  end
rescue Exception
  puts "To use Capistrano with Moonshine, please run 'ruby script/generate moonshine',"
  puts "edit config/moonshine.yml, then re-run capistrano."
  exit(1)
end

namespace :moonshine do

  desc <<-DESC
  Bootstrap a barebones Ubuntu system with Git, Ruby, RubyGems, and Moonshine
  dependencies. Called by deploy:setup.
  DESC
  task :bootstrap do
    #copy the bootstrap script to the server to install Ruby, RubyGems, ShadowPuppet
    put(File.read(File.join(File.dirname(__FILE__), '..', 'bin', 'bootstrap.sh')),"/tmp/bootstrap.sh")
    sudo 'chmod a+x /tmp/bootstrap.sh'
    sudo '/tmp/bootstrap.sh'
    sudo 'rm /tmp/bootstrap.sh'
    # copy moonshine_setup_manifest.rb to the server
    put(File.read(File.join(File.dirname(__FILE__), '..', 'lib', 'moonshine_setup_manifest.rb')),"/tmp/moonshine_setup_manifest.rb")
    begin
      config = YAML.load_file(File.join(Dir.pwd, 'config', 'moonshine.yml'))
      put(YAML.dump(config),"/tmp/moonshine.yml")
    rescue
      puts "Please run 'ruby script/generate moonshine' and configure config/moonshine.yml first"
      exit(0)
    end
    sudo "shadow_puppet /tmp/moonshine_setup_manifest.rb"
    sudo 'rm /tmp/moonshine_setup_manifest.rb'
    sudo 'rm /tmp/moonshine.yml'
  end

  desc 'Apply the Moonshine manifest for this application'
  task :apply do
    case fetch(:moonshine_config, 'from_repo')
    when 'local'
      upload.moonshine_config
      symlink.moonshine_config
    end
    sudo "RAILS_ROOT=#{current_release} RAILS_ENV=#{fetch(:rails_env, 'production')} shadow_puppet #{current_release}/app/manifests/#{fetch(:moonshine_manifest, 'application_manifest')}.rb"
  end

  after 'deploy:update_code' do
    symlink.db_config
    apply
  end

  namespace :upload do
    desc <<-DESC
    Uploads your config/moonshine.yml to the application's shared directory for
    later symlinking (if necessary). Called if moonshine_config=local
    DESC
    task :moonshine_config do
      if File.exist?('config/moonshine.yml')
        put(File.read('config/moonshine.yml'),"#{shared_path}/moonshine.yml")
      end
    end

    desc <<-DESC
    Uploads your config/database.yml to the application's shared directory for
    later symlinking (if necessary). Called by deploy:setup
    DESC
    task :db_config do
      if File.exist?('config/database.yml')
        put(File.read('config/database.yml'),"#{shared_path}/database.yml")
      end
    end
  end

  namespace :symlink do
    desc "Ensure that database.yml is in place"
    task :db_config do
      run "ls #{current_release}/config/database.yml 2> /dev/null || ln -nfs #{shared_path}/database.yml #{current_release}/config/database.yml"
    end

    desc <<-DESC
    Symlinks just-uploaded shared/moonshine.yml into the release directory.
    Called if moonshine_config=local.
    DESC
    task :moonshine_config do
      run "ls #{shared_path}/moonshine.yml && ln -nfs #{shared_path}/moonshine.yml #{current_release}/config/moonshine.yml"
    end
  end

end
namespace :deploy do
  desc "Restart the Passenger processes on the app server by touching tmp/restart.txt."
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_path}/tmp/restart.txt"
  end

  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with Passenger"
    task t, :roles => :app do ; end
  end

  desc <<-DESC
    Prepares one or more servers for deployment. Before you can use any \
    of the Capistrano deployment tasks with your project, you will need to \
    make sure all of your servers have been prepared with `cap deploy:setup'. When \
    you add a new server to your cluster, you can easily run the setup task \
    on just that server by specifying the HOSTS environment variable:
 
      $ cap HOSTS=new.server.com deploy:setup
 
    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :setup, :except => { :no_release => true } do
    moonshine.bootstrap
    moonshine.upload.db_config
  end
end
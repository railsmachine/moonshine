require 'yaml'
set :branch, fetch(:branch, 'master')
namespace :moonshine do
  desc 'Bootstrap a barebones Ubuntu system with Git, Ruby, RubyGems, and Moonshine dependencies.'
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
      config = config.merge({:user => user, :application => application, :deploy_to => deploy_to})
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
    sudo "RAILS_ROOT=#{latest_release} RAILS_ENV=#{fetch(:rails_env, 'production')} shadow_puppet #{latest_release}/app/manifests/#{fetch(:moonshine_manifest, 'application_manifest')}.rb"
  end

  after 'deploy:update_code' do
    apply
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
  end
end
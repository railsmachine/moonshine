require 'yaml'
set :branch, fetch(:branch, 'master')
namespace :moonshine do
  desc 'Bootstrap a barebones Ubuntu system with Git, Ruby, RubyGems, and Moonshine.'
  task :bootstrap do
    put(File.read(File.join(File.dirname(__FILE__), '..', 'bin', 'bootstrap.sh')),"/tmp/bootstrap.sh")
    sudo 'chown root:root /tmp/bootstrap.sh'
    sudo 'chmod 700 /tmp/bootstrap.sh'
    sudo '/tmp/bootstrap.sh'
    sudo 'rm /tmp/bootstrap.sh'
  end

  desc 'Initialize and configure Moonshine for this application'
  task :configure do
    sudo 'moonshine init'
    config = {
      :name => application,
      :uri => repository,
      :branch => branch,
      :manifest_glob => 'app/manifests/*.rb',
      :user => user
    }
    put(YAML.dump(config),"/tmp/#{application}_moonshine.conf")
    sudo "mv /tmp/#{application}_moonshine.conf /etc/moonshine/#{application}.conf"
    sudo "chown root:root /etc/moonshine/#{application}.conf"
    sudo "chmod 700 /etc/moonshine/#{application}.conf"
  end

  before 'deploy:setup' do
    bootstrap
    # configure
  end

  desc 'Apply the Moonshine manifest for this application'
  task :apply do
    sudo "moonshine #{application}"
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
end
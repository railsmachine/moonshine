Capistrano::Configuration.instance(:must_exist).load do
  namespace :moonshine do
    desc <<-DESC
    Bootstrap a barebones Ubuntu system with Git, Ruby, Gems, and Moonshine.
    DESC
    task :bootstrap do
      sudo "apt-get install -q -y git-core"
      put(File.join(File.dirname(__FILE__), '..', 'bin', 'bootstrap.sh'),"/tmp/bootstrap.sh")
      sudo 'chown root:root /tmp/bootstrap.sh'
      sudo 'chmod 700 /tmp/bootstrap.sh'
      sudo '/tmp/bootstrap.sh'
      sudo 'rm /tmp/bootstrap.sh'
      #TODO add application to moonshine
    end

    before 'deploy:setup' do
      bootstrap
    end

    desc <<-DESC
    Apply the Moonshine manifest
    DESC
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
end
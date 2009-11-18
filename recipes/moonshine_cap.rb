set :branch, 'master'
set :scm, :git
set :git_enable_submodules, 1
ssh_options[:paranoid] = false
ssh_options[:forward_agent] = true
default_run_options[:pty] = true
set :keep_releases, 2

after 'deploy:restart', 'deploy:cleanup'

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

set :scm, :svn if !! repository =~ /^svn/

namespace :moonshine do

  desc <<-DESC
  Bootstrap a barebones Ubuntu system with Git, Ruby, RubyGems, and Moonshine
  dependencies. Called by deploy:setup.
  DESC
  task :bootstrap do
    ruby.install
    vcs.install
    moonshine.setup_directories
    shared_config.upload
  end

  desc <<-DESC
  Applies the lib/moonshine_setup_manifest.rb manifest, which replicates the old
  capistrano deploy:setup behavior.
  DESC
  task :setup_directories do
    begin
      config = YAML.load_file(File.join(Dir.pwd, 'config', 'moonshine.yml'))
      put(YAML.dump(config),"/tmp/moonshine.yml")
    rescue Exception => e
      puts e
      puts "Please make sure the settings in moonshine.yml are valid and that the target hostname is correct."
      exit(0)
    end
    upload(File.join(File.dirname(__FILE__), '..', 'lib', 'moonshine_setup_manifest.rb'), "/tmp/moonshine_setup_manifest.rb")
    sudo "shadow_puppet /tmp/moonshine_setup_manifest.rb"
    sudo 'rm /tmp/moonshine_setup_manifest.rb'
    sudo 'rm /tmp/moonshine.yml'
  end

  desc 'Apply the Moonshine manifest for this application'
  task :apply do
    sudo "RAILS_ROOT=#{latest_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE']||fetch(:stage,'undefined')} RAILS_ENV=#{fetch(:rails_env, 'production')} shadow_puppet #{latest_release}/app/manifests/#{fetch(:moonshine_manifest, 'application_manifest')}.rb"
  end

  desc "Update code and then run a console. Useful for debugging deployment."
  task :update_and_console do
    set :moonshine_apply, false
    deploy.update_code
    app.console
  end

  desc "Update code and then run 'rake environment'. Useful for debugging deployment."
  task :update_and_rake do
    set :moonshine_apply, false
    deploy.update_code
    run "cd #{latest_release} && RAILS_ENV=#{fetch(:rails_env, 'production')} rake --trace environment"
  end

  after 'deploy:finalize_update' do
    local_config.upload
    local_config.symlink
    shared_config.symlink
    app.symlinks.update
  end

  before 'deploy:symlink' do
    apply if fetch(:moonshine_apply, true) == true
  end

end

namespace :app do

  namespace :symlinks do

    desc <<-DESC
    Link public directories to shared location.
    DESC
    task :update, :roles => [:app, :web] do
      fetch(:app_symlinks, []).each { |link| run "ln -nfs #{shared_path}/public/#{link} #{latest_release}/public/#{link}" }
    end

  end

  desc "remotely console"
  task :console, :roles => :app, :except => {:no_symlink => true} do
    input = ''
    run "cd #{current_path} && ./script/console #{fetch(:rails_env, "production")}" do |channel, stream, data|
      next if data.chomp == input.chomp || data.chomp == ''
      print data
      channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
    end
  end

  desc "Show requests per second"
  task :rps, :roles => :app, :except => {:no_symlink => true} do
    count = 0
    last = Time.now
    run "tail -f #{shared_path}/log/#{fetch(:rails_env, "production")}.log" do |ch, stream, out|
      break if stream == :err
      count += 1 if out =~ /^Completed in/
      if Time.now - last >= 1
        puts "#{ch[:host]}: %2d Requests / Second" % count
        count = 0
        last = Time.now
      end
    end
  end

  desc "tail application log file"
  task :log, :roles => :app, :except => {:no_symlink => true} do
    run "tail -f #{shared_path}/log/#{fetch(:rails_env, "production")}.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end

  desc "tail vmstat"
  task :vmstat, :roles => [:web, :db] do
    run "vmstat 5" do |channel, stream, data|
      puts "[#{channel[:host]}]"
      puts data.gsub(/\s+/, "\t")
      break if stream == :err
    end
  end

end

namespace :local_config do

  desc <<-DESC
  Uploads local configuration files to the application's shared directory for
  later symlinking (if necessary). Called if local_config is set.
  DESC
  task :upload do
    fetch(:local_config,[]).each do |file|
      filename = File.split(file).last
      if File.exist?( file )
        parent.upload(file, "#{shared_path}/config/#{filename}")
      end
    end
  end
  
  desc <<-DESC
  Symlinks uploaded local configurations into the release directory.
  DESC
  task :symlink do
    fetch(:local_config,[]).each do |file|
      filename = File.split(file).last
      run "ls #{latest_release}/#{file} 2> /dev/null || ln -nfs #{shared_path}/config/#{filename} #{latest_release}/#{file}"
    end
  end
  
end

namespace :shared_config do
  desc <<-DESC
  Uploads local configuration files to the application's shared directory for
  later symlinking (if necessary). Called if shared_config is set.
  DESC
  task :upload do
    fetch(:shared_config, []).each do |file|
      filename = File.split(file).last
      if File.exist?(file)
        put File.read(file), "#{ shared_path }/config/#{ filename }"
      end
    end
  end

  desc <<-DESC
  Downloads remote configuration from the application's shared directory for
  local use.
  DESC
  task :download do
    fetch(:shared_config, []).each do |file|
      filename = File.split(file).last
      if File.exist?(file)
        get "#{ shared_path }/config/#{ filename }", file
      end
    end
  end

  desc <<-DESC
  Symlinks uploaded local configurations into the release directory.
  DESC
  task :symlink do
    fetch(:shared_config, []).each do |file|
      filename = File.split(file).last
      run "ls #{ latest_release }/#{ file } 2> /dev/null || ln -nfs #{ shared_path }/config/#{ filename } #{ latest_release }/#{ file }"
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
  end
end

namespace :ruby do

  desc "Forces a reinstall of Ruby and restarts Apache/Passenger"
  task :upgrade do
    install
    apache.restart
  end

  desc "Install Ruby + Rubygems"
  task :install do
    install_deps
    send fetch(:ruby, 'ree').intern
    install_rubygems
    install_moonshine_deps
  end

  task :mri do
    apt
  end

  task :apt do
    sudo "apt-get install -q -y ruby-full"
  end

  task :remove_ruby_from_apt do
    sudo "apt-get remove -q -y ^.*ruby.* || true"
    #TODO apt-pinning to ensure ruby is never installed via apt
  end

  task :ree do
    remove_ruby_from_apt
    run [
      'cd /tmp',
      'rm -rf ruby-enterprise-1.8.6-20090610* || true',
      'wget -q http://assets.railsmachine.com/other/ruby-enterprise-1.8.6-20090610.tar.gz',
      'tar xzf ruby-enterprise-1.8.6-20090610.tar.gz',
      'sudo /tmp/ruby-enterprise-1.8.6-20090610/installer --dont-install-useful-gems -a /usr'
    ].join(" && ")
  end

  task :ree187 do
    remove_ruby_from_apt
    run [
      'cd /tmp',
      'rm -rf ruby-enterprise-1.8.7-2009.10.tar.gz* || true',
      'wget -q http://rubyforge.org/frs/download.php/66162/ruby-enterprise-1.8.7-2009.10.tar.gz',
      'tar xzf ruby-enterprise-1.8.7-2009.10.tar.gz',
      'sudo /tmp/ruby-enterprise-1.8.7-2009.10/installer --dont-install-useful-gems -a /usr'
    ].join(" && ")
  end

  task :src187 do
    remove_ruby_from_apt
    run [
      'cd /tmp',
      'rm -rf ruby-1.8.7-p174* || true',
      'wget -q ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p174.tar.bz2',
      'tar xjf ruby-1.8.7-p174.tar.bz2',
      'cd /tmp/ruby-1.8.7-p174',
      './configure --prefix=/usr',
      'make',
      'sudo make install'
    ].join(" && ")
  end

  task :install_rubygems do
    run [
      'cd /tmp',
      'rm -rf rubygems-1.3.5* || true',
      'wget -q http://rubyforge.org/frs/download.php/60718/rubygems-1.3.5.tgz',
      'tar xfz rubygems-1.3.5.tgz',
      'cd /tmp/rubygems-1.3.5',
      'sudo ruby setup.rb',
      'sudo ln -s /usr/bin/gem1.8 /usr/bin/gem || true',
      'gem update --system'
    ].join(" && ")
  end

  task :install_deps do
    sudo "apt-get update"
    sudo "apt-get install -q -y build-essential zlib1g-dev libssl-dev libreadline5-dev wget"
  end

  task :install_moonshine_deps do
    sudo "gem install rake --no-rdoc --no-ri"
    sudo "gem install puppet -v 0.24.8 --no-rdoc --no-ri"
    sudo "gem install shadow_puppet --no-rdoc --no-ri"
  end
end

namespace :apache do
  desc "Restarts the Apache web server"
  task :restart do
    sudo 'service apache2 restart'
  end
end

namespace :vcs do
  desc "Installs the scm"
  task :install do
    package = case fetch(:scm).to_s
      when 'svn' then 'subversion'
      when 'git' then 'git-core'
      else scm.to_s
    end
    sudo "apt-get -qq -y install #{package}" unless package == 'none'
  end
end

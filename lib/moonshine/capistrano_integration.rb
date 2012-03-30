require 'pathname'
require 'fileutils'

module Moonshine
  class CapistranoIntegration
    def self.load_defaults_info(capistrano_config)
      capistrano_config.load do
        # these are required at load time by capistrano, we'll set them later
        set :application, ''
        set :repository, ''

        # sane defaults
        set :branch, 'master'
        set :scm, :git
        set :git_enable_submodules, 1
        set :keep_releases, 5
        ssh_options[:paranoid] = false
        ssh_options[:forward_agent] = true
        default_run_options[:pty] = true
        set :noop, false

        # fix common svn error
        set :scm, :subversion if !! repository =~ /^svn/

        # set some default values, so we don't have to fetch(:var, :some_default) in multiple places
        set :local_config, []
        set :shared_config, []
        set :stage, nil
        set :rails_env do
          self[:stage] || 'production'
        end
        set :moonshine_manifest, 'application_manifest'
        set :app_symlinks, []
        set :ruby, :ree

        # know the path to rails logs
        set :rails_log do
          "#{shared_path}/log/#{fetch(:rails_env)}.log"
        end

        set :rails_root, Pathname.new(ENV['RAILS_ROOT'] || Dir.pwd)
        set :moonshine_yml_path, rails_root.join('config', 'moonshine.yml')

        set :moonshine_yml do
          if moonshine_yml_path.exist?
            require 'yaml'
            YAML::load(ERB.new(moonshine_yml_path.read).result)
          else
            puts "Missing #{moonshine_yml_path}"
            puts "You can generate one using the moonshine generator. See `ruby script/generate moonshine --help` for details"
            exit(1)
          end
        end
      end
    end

    def self.load_callbacks_into(capistrano_config)
      capistrano_config.load do
        on :start, 'moonshine:configure'
        unless fetch(:noop)
          after 'deploy:restart', 'deploy:cleanup'
        end
        after 'multistage:ensure', 'moonshine:configure_stage'
      end
    end

    def self.load_into(capistrano_config)
      load_defaults_info(capistrano_config)
      load_callbacks_into(capistrano_config)

      capistrano_config.load do
        namespace :moonshine do
          desc "[internal]: populate capistrano with settings from moonshine.yml"
          task :configure do
            moonshine_yml.each do |key, value|
              set key.to_sym, value
            end
          end

          desc "[internal]: populate capistrano with settings from moonshine/<rails_env>.yml"
          task :configure_stage do
            set :moonshine_rails_env_yml_path, rails_root.join('config', 'moonshine', "#{rails_env}.yml")
            set :moonshine_rails_env_yml do
              if moonshine_rails_env_yml_path.exist?
                require 'yaml'
                YAML::load(ERB.new(moonshine_rails_env_yml_path.read).result)
              else
                {}
              end
            end

            moonshine_rails_env_yml.each do |k,v|
              set k.to_sym, v
            end
          end

          desc <<-DESC
  Bootstrap a barebones Ubuntu system with Git/Subversion, Ruby, RubyGems, and \
  Moonshine dependencies. Called by deploy:setup.
          DESC
          task :bootstrap do
            ruby.install
            vcs.install
            moonshine.setup_directories
            shared_config.upload
          end

          desc <<-DESC
  Applies the lib/moonshine_setup_manifest.rb manifest, which replicates the old \
  capistrano deploy:setup behavior.
          DESC
          task :setup_directories do
            set :moonshine_rails_env_yml_path, rails_root.join('config', 'moonshine', "#{rails_env}.yml")
            if moonshine_rails_env_yml_path.exist?
              run 'mkdir -p /tmp/moonshine'
              upload moonshine_rails_env_yml_path.to_s, "/tmp/moonshine/#{rails_env}.yml"
            end
            upload moonshine_yml_path.to_s, '/tmp/moonshine.yml'
            upload File.join(File.dirname(__FILE__), '..', 'moonshine_setup_manifest.rb'), '/tmp/moonshine_setup_manifest.rb'

            sudo 'shadow_puppet /tmp/moonshine_setup_manifest.rb'
            sudo 'rm /tmp/moonshine_setup_manifest.rb'
            sudo 'rm /tmp/moonshine.yml'
          end

          desc 'Apply the Moonshine manifest for this application'
          task :apply, :except => { :no_release => true } do
            sudo "RAILS_ROOT=#{latest_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE'] || fetch(:stage)} RAILS_ENV=#{fetch(:rails_env)} shadow_puppet #{latest_release}/app/manifests/#{fetch(:moonshine_manifest)}.rb"
          end

          desc 'No-op apply the Moonshine manifest for this application'
          task :noop_apply, :except => { :no_release => true } do
            sudo "RAILS_ROOT=#{latest_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE'] || fetch(:stage)} RAILS_ENV=#{fetch(:rails_env)} shadow_puppet --noop #{latest_release}/app/manifests/#{fetch(:moonshine_manifest)}.rb"
          end

          desc 'Update code and then run a console. Useful for debugging deployment.'
          task :update_and_console do
            set :moonshine_apply, false
            deploy.update_code
            app.console
          end

          desc "Update code and then run 'rake environment'. Useful for debugging deployment."
          task :update_and_rake do
            set :moonshine_apply, false
            deploy.update_code
            run "cd #{latest_release} && RAILS_ENV=#{fetch(:rails_env)} rake --trace environment"
          end

          after 'deploy:finalize_update' do
            local_config.upload
            local_config.symlink
            shared_config.symlink
            app.symlinks.update
          end

          before 'deploy:symlink' do
            if fetch(:noop)
              noop_apply
            else
              apply if fetch(:moonshine_apply, true) == true
            end
          end

          after 'deploy' do
            deploy.rollback.default if fetch(:noop)
          end

        end

        namespace :app do

          namespace :symlinks do

            desc <<-DESC
    Link public directories to shared location.
            DESC
            task :update, :roles => [:app, :web] do
              fetch(:app_symlinks).each do |link|
                run "ln -nfs #{shared_path}/public/#{link} #{latest_release}/public/#{link}"
              end
            end
          end

          desc 'Run script/console on the first application server'
          task :console, :roles => :app, :except => {:no_symlink => true} do
            input = ''
            if capture("test -f #{current_path}/script/console; echo $?").strip == "0"
              command = "cd #{current_path} && ./script/console #{fetch(:rails_env)}"
              prompt = /^(>|\?)>/
            else
              command = "cd #{current_path} && ./script/rails console #{fetch(:rails_env)}"
              prompt = /:\d{3}:\d+(\*|>)/
            end
            run command do |channel, stream, data|
              next if data.chomp == input.chomp || data.chomp == ''
              print data
              channel.send_data(input = $stdin.gets) if data =~ prompt
            end
          end

          desc 'Show requests per second'
          task :rps, :roles => :app, :except => {:no_symlink => true} do
            count = 0
            last = Time.now
            run "tail -f #{rails_log}" do |ch, stream, out|
              break if stream == :err
              count += 1 if out =~ /^Completed in/
                if Time.now - last >= 1
                  puts "#{ch[:host]}: %2d Requests / Second" % count
                  count = 0
                  last = Time.now
                end
            end
          end

          desc 'Tail the application log file of the first app server '
          task :log, :roles => :app, :except => {:no_symlink => true} do
            run "tail -f #{rails_log}" do |channel, stream, data|
              puts "#{data}"
              break if stream == :err
            end
          end

          desc 'Tail vmstat'
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
  Uploads local configuration files to the application's shared directory for \
  later symlinking (if necessary). Called if local_config is set.
          DESC
          task :upload do
            fetch(:local_config).each do |file|
              filename = File.basename(file)
              path = File.dirname(file)
              if File.exist?(file)
                run "mkdir -p '#{shared_path}/#{path}'" unless path.empty?
                parent.upload(file, "#{shared_path}/#{path}/#{filename}")
              end
            end
          end

          desc <<-DESC
  Symlinks uploaded local configurations into the release directory.
          DESC
          task :symlink do
            fetch(:local_config).each do |file|
              filename = File.basename(file)
              path = File.dirname(file)
              run "mkdir -p '#{latest_release}/#{path}'" unless path.empty?
              run "ls #{latest_release}/#{file} 2> /dev/null || ln -nfs #{shared_path}/#{path}/#{filename} #{latest_release}/#{file}"
            end
          end

        end

        namespace :shared_config do

          desc <<-DESC
  Uploads local configuration files to the application's shared directory for \
  later symlinking (if necessary). Called if shared_config is set.
          DESC
          task :upload do
            fetch(:shared_config).each do |file|
              file = Pathname.new(file)

              filename = file.basename
              directory = file.dirname

              run "mkdir -p '#{shared_path}/#{directory}'"
              parent.upload(file.to_s, "#{shared_path}/#{directory}/#{filename}")
            end
          end

          desc <<-DESC
  Downloads remote configuration from the application's shared directory for \
  local use.
          DESC
          task :download do
            fetch(:shared_config).each do |file|
              file = Pathname.new(file)

              filename = file.basename
              directory = file.dirname

              FileUtils.mkdir_p(directory)

              get "#{shared_path}/#{directory}/#{filename}", file.to_s
            end
          end

          desc <<-DESC
  Symlinks uploaded local configurations into the release directory.
          DESC
          task :symlink do
            dirs, links = [], []
            fetch(:shared_config).each do |file|
              file = Pathname.new(file)

              filename = file.basename
              directory = file.dirname
              dirs << directory

              links << "ls #{latest_release}/#{file} 2> /dev/null || ln -nfs #{shared_path}/#{directory}/#{filename} #{latest_release}/#{file}"
            end
            
            mkdir_command = "mkdir -p " + dirs.uniq.map {|dir| "'#{latest_release}/#{dir}'"}.join(" ")
            ln_commands = links.map {|l| "(#{l})"}.join(" && ")
            
            run "#{mkdir_command} && #{ln_commands}"
          end
        end

        namespace :deploy do
          desc 'Restart the Passenger processes on the app server by touching tmp/restart.txt.'
          task :restart, :roles => :app, :except => { :no_release => true } do
            unless fetch(:noop)
              run "touch #{current_path}/tmp/restart.txt"
            end
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

        desc "does a no-op deploy. great for testing a potential deploy before running it!"
        task :noop do
          set :noop, true
        end

        namespace :ruby do

          desc 'Forces a reinstall of Ruby and restarts Apache/Passenger'
          task :upgrade do
            install
            sudo 'gem pristine --all'
            passenger.compile
            apache.restart
          end

          desc 'Install Ruby + Rubygems'
          task :install do
            install_deps
            send fetch(:ruby)
            install_rubygems
            install_moonshine_deps
          end

          task :mri do
            apt
          end

          task :apt do
            sudo 'apt-get install -q -y ruby-full'
          end

          task :remove_ruby_from_apt do
            sudo 'apt-get remove -q -y ^.*ruby.* || true'
            #TODO apt-pinning to ensure ruby is never installed via apt
          end

          task :ree do
            remove_ruby_from_apt
            run [
              'cd /tmp',
              'sudo rm -rf ruby-enterprise-1.8.6-20090610* || true',
              'sudo mkdir -p /usr/lib/ruby/gems/1.8/gems || true',
              'wget -q http://assets.railsmachine.com/other/ruby-enterprise-1.8.6-20090610.tar.gz',
              'tar xzf ruby-enterprise-1.8.6-20090610.tar.gz',
              'sudo /tmp/ruby-enterprise-1.8.6-20090610/installer --dont-install-useful-gems -a /usr'
            ].join(' && ')
          end

          task :ree187 do
            remove_ruby_from_apt
            run [
              'cd /tmp',
              'sudo rm -rf ruby-enterprise-1.8.7-2011.12* || true',
              'sudo mkdir -p /usr/lib/ruby/gems/1.8/gems || true',
              'wget -q http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise-1.8.7-2011.12.tar.gz',
              'tar xzf ruby-enterprise-1.8.7-2011.12.tar.gz',
              'sudo /tmp/ruby-enterprise-1.8.7-2011.12/installer --dont-install-useful-gems --no-dev-docs -a /usr'
            ].join(' && ')
          end

          task :src187 do
            remove_ruby_from_apt
            run [
              'cd /tmp',
              'sudo rm -rf ruby-1.8.7-p249* || true',
              'sudo mkdir -p /usr/lib/ruby/gems/1.8/gems || true',
              'wget -q ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p249.tar.bz2',
              'tar xjf ruby-1.8.7-p249.tar.bz2',
              'cd /tmp/ruby-1.8.7-p249',
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
          end

          task :src192 do
            remove_ruby_from_apt
            pv = '1.9.2-p290'
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              "sudo mkdir -p /usr/lib/ruby/gems/1.9/gems || true",
              "wget -q http://ftp.ruby-lang.org/pub/ruby/1.9/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
          end

          task :src193 do
            remove_ruby_from_apt
            pv = "1.9.3-p125"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo mkdir -p /usr/lib/ruby/gems/1.9/gems || true',
              "wget -q http://ftp.ruby-lang.org/pub/ruby/1.9/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
          end

          task :install_rubygems do
            default_rubygems_version = (fetch(:ruby) =~ /^src19/ ? '1.8.7' : '1.4.2')
            version = fetch(:rubygems_version, default_rubygems_version)
            run [
              'cd /tmp',
              "sudo rm -rf rubygems-#{version}* || true",
              "wget -q http://production.cf.rubygems.org/rubygems/rubygems-#{version}.tgz",
              "tar xfz rubygems-#{version}.tgz",
              "cd /tmp/rubygems-#{version}",
              'sudo ruby setup.rb',
              'sudo ln -s /usr/bin/gem1.8 /usr/bin/gem || true',
            ].join(' && ')
          end

          task :install_deps do
            aptget.update
            sudo 'apt-get install -q -y build-essential zlib1g-dev libssl-dev libreadline5-dev wget'
            if fetch(:ruby) ==  'src193'
              sudo 'apt-get install -q -y libyaml-dev'
            end
          end

          task :install_moonshine_deps do
            sudo 'gem install rake --no-rdoc --no-ri'
            sudo 'gem install i18n --no-rdoc --no-ri' # workaround for missing activesupport-3.0.2 dep on i18n

            shadow_puppet_version = fetch(:shadow_puppet_version, '~> 0.6.1')
            sudo "gem install shadow_puppet --no-rdoc --no-ri --version '#{shadow_puppet_version}'"
            if rails_root.join('Gemfile').exist?
              bundler_version = fetch(:bundler_version, '1.0.21')
              sudo "gem install bundler --no-rdoc --no-ri --version='#{bundler_version}'"
            end
          end
        end

        namespace :apache do
          desc 'Restarts the Apache web server'
          task :restart do
            sudo 'service apache2 restart'
          end
        end

        namespace :passenger do
          task :compile do
            run 'gem list -i passenger && cd /usr/local/src/passenger && sudo /usr/bin/ruby -S rake clean apache2 || true'
          end
        end

        namespace :vcs do
          desc "Installs the scm"
          task :install do
            package = case fetch(:scm).to_s
                      when 'svn' then 'subversion'
                      when 'git' then 'git-core'
                      else nil
                      end
            sudo "apt-get -qq -y install #{package}" if package
          end
        end

        namespace :aptget do
          task :update do
            sudo 'apt-get update'
          end
        end
      end
    end
  end
end

require 'capistrano'
if Capistrano::Configuration.instance
  Moonshine::CapistranoIntegration.load_into(Capistrano::Configuration.instance)
end

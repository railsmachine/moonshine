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
        set :nopuppetrollback, false

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

        set :asset_env, "RAILS_GROUPS=assets"
        set :assets_prefix, "assets"
        set :assets_role, [:app]

        set :bundle_roles, [:app, :resque, :dj, :db, :sidekiq]

        if File.exist?('app/assets')
          set :normalize_asset_timestamps, false
        end

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
          desc "Enable moonshine for this deploy"
          task :default do
            set :moonshine_apply, true
          end

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
            aptget.update
            aptget.upgrade
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

            if fetch(:stage)
              shadow_puppet_line = "DEPLOY_STAGE=#{fetch(:stage)} "
            else
              shadow_puppet_line = ""
            end

            shadow_puppet_line << "shadow_puppet /tmp/moonshine_setup_manifest.rb"


            sudo shadow_puppet_line
            sudo 'rm /tmp/moonshine_setup_manifest.rb'
            sudo 'rm /tmp/moonshine.yml'
          end

          desc 'Apply the Moonshine manifest for this application'
          task :apply, :except => { :no_release => true } do
            sudo "RAILS_ROOT=#{latest_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE'] || fetch(:stage)} RAILS_ENV=#{fetch(:rails_env)} shadow_puppet #{'--noop' if fetch(:noop)} #{'--ignore' if fetch(:nopuppetrollback)} #{latest_release}/app/manifests/#{fetch(:moonshine_manifest)}.rb"
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

          # FIXME hackish way to workaround capistrano API change
          # see https://github.com/capistrano/capistrano/issues/157 for some details
          require 'capistrano/version'
          if Capistrano::Version::MAJOR > 2 || (Capistrano::Version::MAJOR == 2 && Capistrano::Version::MINOR > 9)
            before 'deploy:create_symlink' do
              apply if fetch(:moonshine_apply, true) == true
            end
          else
            before 'deploy:symlink' do
              apply if fetch(:moonshine_apply, true) == true
            end
          end

          before 'deploy' do
            if ! fetch(:moonshine_apply, true)
              if File.exist?('Gemfile')
                capistrano_config.require 'bundler/capistrano'

                if File.exist?('app/assets')
                  capistrano_config.load 'deploy/assets'
                end
              end
            end
          end

          before 'deploy:migrations' do
            if File.exist?('Gemfile')
              capistrano_config.require 'bundler/capistrano'
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
            # Rails 2
            if capture("test -f #{current_path}/script/console; echo $?").strip == "0"
              command = "cd #{current_path} && ./script/console #{fetch(:rails_env)}"
              prompt = /^(>|\?)>/
            # Rails 3
            elsif capture("test -f #{current_path}/script/rails; echo $?").strip == "0"
              command = "cd #{current_path} && ./script/rails console #{fetch(:rails_env)}"
              prompt = /:\d{3}:\d+(\*|>)/
            # Rails 4
            else
              command = "cd #{current_path} && ./bin/rails console #{fetch(:rails_env)}"
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

            if (dirs + links).any?
              mkdir_command = "mkdir -p " + dirs.uniq.map {|dir| "'#{latest_release}/#{dir}'"}.join(" ")
              ln_commands = links.map {|l| "(#{l})"}.join(" && ")

              run "#{mkdir_command} && #{ln_commands}"
            end
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

          # copy-pasta from https://github.com/capistrano/capistrano/blob/master/lib/capistrano/recipes/deploy/assets.rb
          namespace :assets do
            desc <<-DESC
      [internal] This task will set up a symlink to the shared directory \
      for the assets directory. Assets are shared across deploys to avoid \
      mid-deploy mismatches between old application html asking for assets \
      and getting a 404 file not found error. The assets cache is shared \
      for efficiency. If you customize the assets path prefix, override the \
      :assets_prefix variable to match.
    DESC
            task :symlink, :roles => assets_role, :except => { :no_release => true } do
              run <<-CMD
        rm -rf #{latest_release}/public/#{assets_prefix} &&
        mkdir -p #{latest_release}/public &&
        mkdir -p #{shared_path}/assets &&
        ln -s #{shared_path}/assets #{latest_release}/public/#{assets_prefix}
      CMD
            end

            desc <<-DESC
      Run the asset precompilation rake task. You can specify the full path \
      to the rake executable by setting the rake variable. You can also \
      specify additional environment variables to pass to rake via the \
      asset_env variable. The defaults are:

        set :rake,      "rake"
        set :rails_env, "production"
        set :asset_env, "RAILS_GROUPS=assets"
    DESC
            task :precompile, :roles => assets_role, :except => { :no_release => true } do
              run "cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile"
            end

            desc <<-DESC
      Run the asset clean rake task. Use with caution, this will delete \
      all of your compiled assets. You can specify the full path \
      to the rake executable by setting the rake variable. You can also \
      specify additional environment variables to pass to rake via the \
      asset_env variable. The defaults are:

        set :rake,      "rake"
        set :rails_env, "production"
        set :asset_env, "RAILS_GROUPS=assets"
    DESC
            task :clean, :roles => assets_role, :except => { :no_release => true } do
              run "cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:clean"
            end
          end

          namespace :apache do
            desc "Start Apache on the specified app server: cap STAGE deploy:apache:start -s host=app1"
            task :start, :roles => :app do
              servers = find_servers_for_task(current_task)
              servers.each do |server|
                if not respond_to?(:host) or server.host.include?(host)
                  teardown_connections_to([server])
                  sudo 'service apache2 start', :hosts => server.host
                end
              end
            end

            desc "Stop Apache on the specified app server: cap STAGE deploy:apache:stop -s host=app1"
            task :stop, :roles => :app do
              servers = find_servers_for_task(current_task)
              servers.each do |server|
                if not respond_to?(:host) or server.host.include?(host)
                  teardown_connections_to([server])
                  sudo 'service apache2 stop', :hosts => server.host
                end
              end
            end

            desc "Restart Apache on the specified app server: cap STAGE deploy:apache:restart -s host=app1"
            task :restart, :roles => :app do
              servers = find_servers_for_task(current_task)
              servers.each do |server|
                if not respond_to?(:host) or server.host.include?(host)
                  teardown_connections_to([server])
                  sudo 'service apache2 restart', :hosts => server.host
                end
              end
            end

            desc "Gets Apache running status on the specified app server: cap STAGE deploy:apache:status -s host=app1"
            task :status, :roles => :app do
              servers = find_servers_for_task(current_task)
              servers.each do |server|
                if not respond_to?(:host) or server.host.include?(host)
                  teardown_connections_to([server])
                  sudo 'service apache2 status', :hosts => server.host
                end
              end
            end
          end
        end

        desc "does a no-op deploy. great for testing a potential deploy before running it!"
        task :noop do
          set :noop, true
        end

        desc "tells shadow_puppet to ignore failed Puppet tasks so that a failed Puppet task won't cause a rollback"
        task :nopuppetrollback do
          set :nopuppetrollback, true
        end

        namespace :libyaml do
          desc "Install libyaml from source."
          task :install do
            remove_libyaml_from_apt
            pv = "0.1.6"
            p = "yaml-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              "wget -q http://assets.railsmachine.com/libs/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
          end

          task :remove_libyaml_from_apt do
            sudo 'apt-get remove -q -y ^.*libyaml.* || true'
          end
        end

        namespace :ruby do

          desc <<-DESC
      Forces a reinstall of Ruby and restarts Apache/Passenger'
      The gems installed with bundler have been removed.
      You must perform a deploy to reinstall these gems with 'bundle install'.
    DESC
          task :upgrade do
            install
            sudo 'gem pristine --all'
            sudo "rm -rf #{shared_path}/bundle/*"
            puts "The gems installed with bundler have been removed."
            puts "You must perform a deploy to reinstall these gems with 'bundle install'."
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

          task :brightbox21 do
            remove_ruby_from_apt
            run [
              'sudo rm -f /usr/bin/ruby',
              'sudo rm -f /usr/bin/gem',
              'sudo rm -f /usr/bin/rake',
              'sudo rm -f /usr/bin/rdoc',
              'sudo rm -f /usr/bin/irb',
              'sudo rm -f /usr/bin/erb',
              'sudo rm -f /usr/bin/ri',
              'sudo rm -f /usr/bin/testrb',
              'sudo apt-get install python-software-properties software-properties-common -y',
              'sudo apt-add-repository ppa:brightbox/ruby-ng -y',
              'sudo apt-get update',
              'sudo apt-get install ruby2.1 ruby2.1-dev -y'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.2.2')
            set :bundler_version, fetch(:bundler_version, '1.6.2')
          end

          task :brightbox193 do
            remove_ruby_from_apt

            version = capture("lsb_release -r").split(":").last.to_f

            repo_flag = ""
            software_properties = "python-software-properties"

            if version >= 12
              repo_flag = "-y"
              software_properties << " software-properties-common"
            end

            run [
              'sudo rm -f /usr/bin/ruby',
              'sudo rm -f /usr/bin/gem',
              'sudo rm -f /usr/bin/rake',
              'sudo rm -f /usr/bin/rdoc',
              'sudo rm -f /usr/bin/irb',
              'sudo rm -f /usr/bin/erb',
              'sudo rm -f /usr/bin/ri',
              'sudo rm -f /usr/bin/testrb',
              "sudo apt-get install #{software_properties} -y",
              "sudo apt-add-repository ppa:brightbox/ruby-ng #{repo_flag}",
              'sudo apt-get update',
              'sudo apt-get install build-essential ruby1.9.1 ruby1.9.1-dev -y'
            ].join(' && ')
          end

          task :src192 do
            remove_ruby_from_apt
            pv = '1.9.2-p290'
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              "sudo mkdir -p /usr/lib/ruby/gems/1.9.1/gems || true",
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
            libyaml.install
            pv = "1.9.3-p551"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/1.9.1/gems || true',
              "wget -q http://ftp.ruby-lang.org/pub/ruby/1.9/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
          end

          task :src193falcon do
            src193railsexpress
          end

          task :src193railsexpress do
            set :ruby_patches_path, rails_root.join('vendor', 'plugins', 'moonshine', 'patches')
            if ruby_patches_path.exist?
              run 'mkdir -p /tmp/moonshine'
              upload ruby_patches_path.to_s, "/tmp/moonshine/", :via => :scp, :recursive => true
            end
            remove_ruby_from_apt
            libyaml.install
            pv = "1.9.3-p551"
            p = "ruby-#{pv}"
            run [
              'sudo apt-get install autoconf -y || true',
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/1.9.1/gems || true',
              "wget -q http://ftp.ruby-lang.org/pub/ruby/1.9/#{p}.tar.gz",
              "tar zxvf #{p}.tar.gz",
              "cd /tmp/#{p}",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/01-fix-make-clean.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/02-zero-broken-tests.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/03-railsbench-gc.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/04-display-more-detailed-stack-trace.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/05-fork-support-for-gc-logging.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/06-track-live-dataset-size.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/07-webrick_204_304_keep_alive_fix.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/08-export-a-few-more-symbols-for-ruby-prof.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/09-thread-variables.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/10-faster-loading.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/11-falcon-st-opt.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/12-falcon-sparse-array.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/13-falcon-array-queue.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/14-railsbench-gc-fixes.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/15-show-full-backtrace-on-stack-overflow.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/16-configurable-fiber-stack-sizes.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/17-backport-psych-20.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/18-fix-missing-c-return-event.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/1.9.3/p551/railsexpress/19-fix-process-daemon-call.patch",
              'export CFLAGS="-march=core2 -O2 -pipe -fomit-frame-pointer"',
              'autoreconf -vf',
              "./configure --prefix=/usr",
              "make",
              "sudo make install"
            ].join(' && ')
          end

          task :src200 do
            remove_ruby_from_apt
            pv = "2.0.0-p648"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.0.0/gems || true',
              "wget -q http://ftp.ruby-lang.org/pub/ruby/2.0/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.4.8')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

          task :src200railsexpress do
            set :ruby_patches_path, rails_root.join('vendor', 'plugins', 'moonshine', 'patches')
            if ruby_patches_path.exist?
              run 'mkdir -p /tmp/moonshine'
              upload ruby_patches_path.to_s, "/tmp/moonshine/", :via => :scp, :recursive => true
            end
            remove_ruby_from_apt
            pv = "2.0.0-p648"
            p = "ruby-#{pv}"
            run [
              'sudo apt-get install autoconf -y || true',
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.0.0/gems || true',
              "wget -q http://ftp.ruby-lang.org/pub/ruby/2.0/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              "patch -p1 </tmp/moonshine/patches/ruby/2.0.0/p648/railsexpress/01-zero-broken-tests.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.0.0/p648/railsexpress/02-railsexpress-gc.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.0.0/p648/railsexpress/03-display-more-detailed-stack-trace.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.0.0/p648/railsexpress/04-show-full-backtrace-on-stack-overflow.patch",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.1.11')
            set :bundler_version, fetch(:bundler_version, '1.3.5')
          end

          task :src21 do
            remove_ruby_from_apt
            pv = "2.1.10"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.0.0 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.1.0/gems || true',
              "wget -q http://cache.ruby-lang.org/pub/ruby/2.1/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.6.11')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

          task :src21railsexpress do
            set :ruby_patches_path, rails_root.join('vendor', 'plugins', 'moonshine', 'patches')
            if ruby_patches_path.exist?
              run 'mkdir -p /tmp/moonshine'
              upload ruby_patches_path.to_s, "/tmp/moonshine/", :via => :scp, :recursive => true
            end
            remove_ruby_from_apt
            sudo 'apt-get install autoconf -y || true',
            pv = "2.1.8"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.0.0 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.1.0/gems || true',
              "wget -q http://cache.ruby-lang.org/pub/ruby/2.1/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/01-zero-broken-tests.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/02-improve-gc-stats.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/03-display-more-detailed-stack-trace.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/04-show-full-backtrace-on-stack-overflow.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/05-funny-falcon-stc-density.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/06-funny-falcon-stc-pool-allocation.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/07-aman-opt-aset-aref-str.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/08-funny-falcon-method-cache.patch",
              "patch -p1 </tmp/moonshine/patches/ruby/2.1.8/railsexpress/09-heap-dump-support.patch",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.6.11')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

          task :src22 do
            remove_ruby_from_apt
            pv = "2.2.7"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.0.0 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.1.0 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.2.0/gems || true',
              "wget -q http://cache.ruby-lang.org/pub/ruby/2.2/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.6.11')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

          task :src23 do
            remove_ruby_from_apt
            pv = "2.3.4"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm /usr/bin/rake || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.0.0 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.1.0 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.2.0/gems || true',
              "wget -q http://cache.ruby-lang.org/pub/ruby/2.3/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.6.11')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

          task :src24 do
            remove_ruby_from_apt
            pv = "2.4.1"
            p = "ruby-#{pv}"
            run [
              'cd /tmp',
              "sudo rm -rf #{p}* || true",
              'sudo rm /usr/bin/rake || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.8 || true',
              'sudo rm -rf /usr/lib/ruby/gems/1.9.1 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.0.0 || true',
              'sudo rm -rf /usr/lib/ruby/gems/2.1.0 || true',
              'sudo mkdir -p /usr/lib/ruby/gems/2.2.0/gems || true',
              "wget -q http://cache.ruby-lang.org/pub/ruby/2.4/#{p}.tar.gz",
              "tar xzf #{p}.tar.gz",
              "cd /tmp/#{p}",
              './configure --prefix=/usr',
              'make',
              'sudo make install'
            ].join(' && ')
            set :rubygems_version, fetch(:rubygems_version, '2.6.11')
            set :bundler_version, fetch(:bundler_version, '1.14.6')
          end

         task :install_rubygems do
            version = fetch(:rubygems_version, '1.8.21')
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
            sudo 'apt-get install -q -y build-essential zlib1g-dev libssl-dev libreadline-dev wget'
          end

          task :install_moonshine_deps do
            sudo 'gem install rake --no-rdoc --no-ri' unless fetch(:ruby).start_with?('src2')
            sudo 'gem install i18n --no-rdoc --no-ri' # workaround for missing activesupport-3.0.2 dep on i18n

            shadow_puppet_version = fetch(:shadow_puppet_version, '~> 0.10.3')
            sudo "gem install shadow_puppet --no-rdoc --no-ri --version '#{shadow_puppet_version}'"
            if rails_root.join('Gemfile').exist?
              bundler_version = fetch(:bundler_version, '1.1.3')
              sudo "gem install bundler --no-rdoc --no-ri --version='#{bundler_version}'"
            end
          end
        end

        namespace :apache do
          desc 'Restarts the Apache web server'
          task :restart, :roles => [:app, :web] do
            sudo 'service apache2 restart'
          end
        end

        namespace :passenger do
          task :compile, :roles => :app do
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

          task :upgrade do
            sudo 'apt-get upgrade -q -y'
          end
        end

        namespace :ssl do
          task :create do
            csr = (moonshine_yml[:ssl] && moonshine_yml[:ssl][:csr]) || {}


            enough_csr_details = true

            csr[:length] ||= 2048
            enough_csr_details &= csr[:country] && !csr[:country].empty?
            enough_csr_details &= csr[:state] && !csr[:state].empty?
            enough_csr_details &= csr[:locality] && !csr[:locality].empty?
            enough_csr_details &= csr[:organization] && !csr[:organization].empty?
            enough_csr_details &= csr[:domain] && !csr[:domain].empty?

            if enough_csr_details
              puts "We have all the details we need! Generating private key and csr now..."

              run_locally "mkdir -p config/ssl"

              filesystem_safe_domain = csr[:domain].gsub('*', 'star')

              run_locally "cd config/ssl && openssl req -new -nodes -days 365 -newkey rsa:#{csr[:length]} -subj '/C=#{csr[:country]}/ST=#{csr[:state]}/L=#{csr[:locality]}/O=#{csr[:organization]}/CN=#{csr[:domain]}' -keyout #{filesystem_safe_domain}.key -out #{filesystem_safe_domain}.csr"


              puts <<-MESSAGE

Your csr & key have been generated and saved in config/ssl:

 * config/ssl/#{filesystem_safe_domain}.csr
 * config/ssl/#{filesystem_safe_domain}.key

Once you've chosen a certificate authority, they will ask for the contents of the csr, included below:

#{File.read("config/ssl/#{filesystem_safe_domain}.csr")}

IMPORTANT: keep these files in a safe place (ie check into version control)

 * the csr is needed to re-issue the certificate when it expires
 * the key is needed at deploy time to use the purchased certificate
              MESSAGE
            else
              already_has_ssl_configuration = moonshine_yml[:ssl]

              where_to_paste = if already_has_ssl_configuration
                                 "the :ssl section of config/moonshine.yml"
                               else
                                 "config/moonshine.yml"
                               end


              domain_template = if csr[:domain]
                                  csr[:domain]
                                else
                                  domain = moonshine_yml[:domain] || 'yourdomain.com'
                                  "#{domain} # FIXME update with correct domain. Do not include www at beginning. Add `*.` at the beginning for wildcard}"
                                end
              puts <<-ERROR
Not enough details to generate a CSR! Copy & paste the following into #{where_to_paste}, and rerun `cap ssl:create`:

#{':ssl:' unless already_has_ssl_configuration}
  :csr:
    :length: #{csr[:length] || 2048}
    :country: #{csr[:country] || 'US # FIXME update with correct country'}
    :state: #{csr[:state] || 'Your State # FIXME update with correct state, no abbreivations'}
    :locality: #{csr[:locality] || 'Your City # FIXME update with correct city/locality, no abbreivations'}
    :organization: #{csr[:organization] || 'Your Organization # FIXME update with correct company name, ie your registered company name. Some certificate authorities are more strict about the correctness of this than others'}
    :domain: #{domain_template}
ERROR
              exit 1

            end
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

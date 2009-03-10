module Moonshine::Manifest::Rails::Rails

  # Attempt to bootstrap your application. Calls <tt>rake moonshine:bootstrap</tt>
  # which runs:
  #
  #   rake db:schema:load (if db/schema.rb exists)
  #   rake db:migrate (if db/migrate exists)
  #
  # We then run a task to load bootstrap fixtures from <tt>db/bootstrap</tt>
  # (if it exists). These fixtures may be created with the included
  # <tt>moonshine:db:bootstrap:dump</tt> rake task.
  #
  #   rake moonshine:db:bootstrap
  #
  # We then run the following task:
  #
  #   rake moonshine:app:bootstrap
  #
  # The <tt>moonshine:app:bootstrap</tt> task does nothing by default. If
  # you'd like to have your application preform any logic on it's first deploy,
  # overwrite this task in your <tt>Rakefile</tt>:
  #
  #   namespace :moonshine do
  #     namespace :app do
  #       desc "Overwrite this task in your app if you have any bootstrap tasks that need to be run"
  #       task :bootstrap do
  #         #
  #       end
  #     end
  #   end
  #
  # All of this assumes one things. That your application can run 'rake
  # environment' with an empty database. Please ensure your application can do
  # so!
  def rails_bootstrap
    rake 'moonshine:bootstrap',
      :alias => 'rails_bootstrap',
      :refreshonly => true,
      :before => exec('rake db:migrate')
  end

  # Runs Rails migrations. These are run on each deploy to ensure consistency!
  # No more 500s when you forget to <tt>cap deploy:migrations</tt>
  def rails_migrations
    rake 'db:migrate'
  end

  # This task ensures Rake is installed and that <tt>rake environment</tt>
  # executes without error in your <tt>rails_root</tt>.
  def rails_rake_environment
    package 'rake', :provider => :gem, :ensure => :installed
    exec 'rake tasks',
      :command => 'rake -T > /dev/null',
      :cwd => rails_root,
      :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}",
      :require => [
        exec('rails_gems'),
        package('rake')
      ]
  end

  # Automatically install all gems needed specified in the array at
  # <tt>configatron.gems</tt>. This loads gems from <tt>config/gems.yml</tt>,
  # which can be generated from by running <tt>rake moonshine:gems</tt>
  # locally.
  def rails_gems
    #stub for dependencies
    exec 'rails_gems', :command => 'true'
    return if configatron.gems.nil?
    configatron.gems.each do |gem|
      hash = {
        :provider => :gem,
        :before   => exec('rails_gems')
      }
      hash.merge!(:source => gem[:source]) if gem[:source]
      exact_dep = gem[:version] ? Gem::Dependency.new(gem[:name], gem[:version]) : Gem::Dependency.new(gem[:name], '>0')
      matches = Gem.source_index.search(exact_dep)
      installed_spec = matches.first
      if installed_spec
        #it's already loaded, let's just specify that we want it installed
        hash.merge!(:ensure => :installed)
      elsif gem[:version]
        #if it's not installed and version specified, we require that version
        hash.merge!(:ensure => gem[:version])
      else
        #otherwise we don't care
        hash.merge!(:ensure => :installed)
      end
      #finally create the dependency
      package(gem[:name], hash)
    end
  end

  # Essentially replicates the deploy:setup command from capistrano, but sets
  # up permissions correctly.
  def rails_directories
    deploy_to_array = configatron.deploy_to.split('/').split('/')
    deploy_to_array.each_with_index do |dir, index|
      next if index == 0 || index >= (deploy_to_array.size-1)
      file '/'+deploy_to_array[1..index].join('/'), :ensure => :directory
    end
    dirs = [
      "#{configatron.deploy_to}",
      "#{configatron.deploy_to}/shared",
      "#{configatron.deploy_to}/releases"
    ]
    if configatron.shared_children.is_a?(Array)
      shared_dirs = configatron.shared_children.map { |d| "#{configatron.deploy_to}/shared/#{d}" }
      dirs += shared_dirs
    end
    if configatron.app_symlinks.is_a?(Array)
      dirs += ["#{configatron.deploy_to}/shared/public"]
      symlink_dirs = configatron.app_symlinks.map { |d| "#{configatron.deploy_to}/shared/public/#{d}" }
      dirs += symlink_dirs
    end
    dirs.each do |dir|
      file dir,
      :ensure => :directory,
      :owner => configatron.user,
      :group => configatron.retrieve('group', configatron.user),
      :mode => '775'
    end
  end

private

  # Creates exec('rake #name') that runs in <tt>rails root</tt> of the rails
  # app, with RAILS_ENV properly set
  def rake(name, options = {})
    exec("rake #{name}", {
      :command => "rake #{name}",
      :cwd => rails_root,
      :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}",
      :require => exec('rake tasks')
    }.merge(options)
  )
  end

end
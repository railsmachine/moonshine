module Moonshine::Plugin::Rails

  def rails_bootstrap
    #stub for dependencies
    exec 'rails_bootstrap',
      :command => 'true',
      :refreshonly => true,
      :notify => [
        exec('rake db:schema:load'),
        exec('rake moonshine:db:bootstrap'),
        exec('rake moonshine:app:bootstrap'),
      ],
      :before => exec('rake db:migrate')

    rake 'db:schema:load',
      :refreshonly => true,
      :notify => exec('rails_bootstrap'),
      :unless => mysql_query("select * from #{mysql_config_from_environment[:database]}.schema_migrations;"),
      :before => exec('rake db:migrate')

    rake 'moonshine:db:bootstrap',
      :require => exec('rake db:schema:load'),
      :onlyif => 'test -d db/bootstrap',
      :refreshonly => true,
      :require => exec('rake db:schema:load'),
      :environment => [ "RAILS_ENV=production" ],
      :before => exec('rake db:migrate')

    rake 'moonshine:app:bootstrap',
      :require => exec('rake db:schema:load'),
      :refreshonly => true,
      :require => exec('rake moonshine:db:bootstrap'),
      :environment => [ "RAILS_ENV=production" ],
      :before => exec('rake db:migrate')
  end

  def rails_migrations
    rake 'db:migrate'
  end

  def rails_gems
    #stub for dependencies
    exec 'rails_gems', :command => 'true'
    return unless configuration[:gems]
    configuration[:gems].each do |gem|
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
        hash.merge!(:ensure => gem_dependency.requirement.to_s)
      else
        #otherwise we don't care
        hash.merge!(:ensure => :installed)
      end
      #finally create the dependency
      package(gem[:name], hash)
    end
  end

  #Essentially replicates the deploy:setup command from capistrano. Includes
  #shared_children and app_symlinks arrays from capistrano.
  def rails_directories
    deploy_to_array = configuration[:deploy_to].split('/').split('/')
    deploy_to_array.each_with_index do |dir, index|
      next if index == 0 || index >= (deploy_to_array.size-1)
      file '/'+deploy_to_array[1..index].join('/'), :ensure => :directory
    end
    dirs = [
      "#{configuration[:deploy_to]}",
      "#{configuration[:deploy_to]}/shared",
      "#{configuration[:deploy_to]}/releases"
    ]
    dirs += configuration[:capistrano].shared_children.map { |d| "#{configuration[:deploy_to]}/shared/#{d}" }
    if configuration[:capistrano].respond_to?(:app_symlinks)
      dirs += ["#{configuration[:deploy_to]}/shared/public"]
      dirs += configuration[:capistrano].app_symlinks.map { |d| "#{configuration[:deploy_to]}/shared/public/#{d}" }
    end
    dirs.each do |dir|
      file dir, :ensure => :directory, :owner => configuration[:user], :group => configuration[:user]
    end
  end

private

  # Creates exec('rake #name') that runs in the working_directory of the rails
  # app, with RAILS_ENV properly set
  def rake(name, options = {})
    exec("rake #{name}", {
      :command => "rake #{name}",
      :cwd => self.class.working_directory,
      :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}"
    }.merge(options)
  )
  end

end

include Moonshine::Plugin::Rails
recipe :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations
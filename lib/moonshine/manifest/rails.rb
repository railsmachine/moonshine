class Moonshine::Manifest::Rails < Moonshine::Manifest
  recipe :gems_from_environment
  recipe :directories

  #database config
  configure(:database => YAML.load_file(File.join(ENV['RAILS_ROOT'], 'config', 'database.yml')))

  #capistrano
  cap = Capistrano::Configuration.new
  cap.load(:string => """
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['#{ENV['RAILS_ROOT']}/vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load '#{ENV['RAILS_ROOT']}/config/deploy'
""")
  configure(:capistrano => cap)

  def gems_from_environment
    #rails configuration
    $rails_gem_installer = true
    begin
      require(File.join(ENV['RAILS_ROOT'], 'config', 'environment'))
    rescue Exception
      if defined?(RAILS_GEM_VERSION)
        #we can't parse the environment. as a last ditch effort, shell out and
        #try to install rails
        `gem install rails --version #{RAILS_GEM_VERSION}`
      end
      require(File.join(ENV['RAILS_ROOT'], 'config', 'environment'))
    end
    configure(:rails => ::Rails.configuration)

    configuration['rails'].gems.each do |gem_dependency|
      package(gem_dependency.name, {
        :provider => :gem,
        :source   => gem_dependency.source,
        :ensure   => :latest,
        :version  => gem_dependency.requirement ? gem_dependency.requirement.to_s : nil
      })
    end
    package('rails', {
      :provider => :gem,
      :ensure   => :installed,
      :version  => (RAILS_GEM_VERSION rescue nil)
    })
  end

  #Essentially replicates the deploy:setup command from capistrano. Includes
  #shared_children and app_symlinks arrays from capistrano.
  def directories
    dirs = [
      "/srv",
      "/srv/#{configuration[:capistrano].application}",
      "/srv/#{configuration[:capistrano].application}/shared",
      "/srv/#{configuration[:capistrano].application}/releases"
    ]
    dirs += configuration[:capistrano].shared_children.map { |d| "/srv/#{configuration[:capistrano].application}/shared/#{d}" }
    if configuration[:capistrano].respond_to?(:app_symlinks)
      dirs += ["/srv/#{configuration[:capistrano].application}/shared/public"]
      dirs += configuration[:capistrano].app_symlinks.map { |d| "/srv/#{configuration[:capistrano].application}/shared/public/#{d}" }
    end
    dirs.each do |dir|
      file dir, :ensure => :directory, :owner => configuration[:capistrano].user, :group => configuration[:capistrano].user
    end
  end
end
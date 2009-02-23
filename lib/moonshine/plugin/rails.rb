module Moonshine::Plugin::Rails

  def rails_gems
    rails_configuration

    configuration['rails'].gems.each do |gem_dependency|
      package(gem_dependency.name, {
        :provider => :gem,
        :source   => gem_dependency.source,
        :ensure  => gem_dependency.requirement ? gem_dependency.requirement.to_s : :latest
      })
    end
    package('rails', {
      :provider => :gem,
      :ensure  => (RAILS_GEM_VERSION rescue :latest)
    })
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

  def rails_configuration
    return configuration[:rails] if configuration[:rails]
    $rails_gem_installer = true
    begin
      require(File.join(self.class.working_directory, 'config', 'environment'))
    rescue Exception
      if defined?(RAILS_GEM_VERSION)
        #we can't parse the environment. as a last ditch effort, shell out and
        #try to install rails
        `gem install rails --version #{RAILS_GEM_VERSION}`
      end
      require(File.join(self.class.working_directory, 'config', 'environment'))
    end
    configure(:rails => ::Rails.configuration)
    configuration[:rails]
  end

end

include Moonshine::Plugin::Rails
recipe :rails_gems, :rails_directories
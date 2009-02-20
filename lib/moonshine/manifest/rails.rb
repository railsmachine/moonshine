class Moonshine::Manifest::Rails < Moonshine::Manifest
  recipe :gems_from_environment

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
end
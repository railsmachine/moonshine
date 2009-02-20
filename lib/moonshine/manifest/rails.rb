class Moonshine::Manifest::Rails < Moonshine::Manifest
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

  #rails configuration
  $rails_gem_installer = true
  require(File.join(ENV['RAILS_ROOT'], 'config', 'environment'))
  configure(:rails => ::Rails.configuration)

  recipe :gems_from_environment
  def gems_from_environment
    configuration['rails'].gems.each do |gem_dependency|
      package(gem_dependency.name, {
        :provider => :gem,
        :source   => gem_dependency.source,
        :ensure   => :latest,
        :version  => gem_dependency.requirement ? gem_dependency.requirement.to_s : nil
      })
    end
  end
end
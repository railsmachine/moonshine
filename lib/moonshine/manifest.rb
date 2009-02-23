class Moonshine::Manifest < ShadowPuppet::Manifest
  def self.path_to_config
    File.join(working_directory, 'config', 'moonshine.yml')
  end

  def self.working_directory
    @working_directory ||= File.expand_path(ENV["RAILS_ROOT"] || Dir.getwd)
  end

  def self.plugin(name)
    name = name.to_s.underscore
    Kernel.require File.join(working_directory, 'vendor', 'plugins', "moonshine_#{name}", 'lib', 'moonshine', "#{name}.rb")
    Module.include "moonshine/#{name}".camelize.constantize
    true
   end

  #TODO support templates in working_directory/app/manifest/templates/
  #TODO support templates in working_directory/vendor/plugins/**templates
  def template(template, b = nil)
    b ||= self.send(:binding)
    template_contents = File.read(File.expand_path(File.join(File.dirname(__FILE__), '..', 'templates', template)))
    ERB.new(template_contents).result(b)
  end

  #config/moonshine.yml
  configure(YAML.load_file(self.path_to_config))

  #database config
  configure(:database => YAML.load_file(File.join(working_directory, 'config', 'database.yml')))

  #capistrano
  cap = Capistrano::Configuration.new
  cap.load(:string => """
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['#{working_directory}/vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load '#{working_directory}/config/deploy.rb'
""")
  configure(:capistrano => cap)

end
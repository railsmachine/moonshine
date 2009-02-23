class Moonshine::Manifest < ShadowPuppet::Manifest
  def self.path_to_config
    File.join(working_directory, 'config', 'moonshine.yml')
  end

  def self.working_directory
    @working_directory ||= File.expand_path(ENV["RAILS_ROOT"] || Dir.getwd)
  end

  # Load a Moonshine Plugin
  #
  #   class MyManifest < Moonshine::Manifest
  #
  #     # Evals vendor/plugins/moonshine_my_app/moonshine.init.rb
  #     plugin :moonshine_my_app
  #
  #     # Evals lib/my_recipe.rb
  #     plugin 'lib/my_recipe.rb'
  #
  #     ...
  #   end
  def self.plugin(name = nil)
    if name.is_a?(Symbol)
      path = File.join(working_directory, 'vendor', 'plugins', 'name', 'moonshine', 'init.rb')
    else
      path = File.join(working_directory, name)
    end
    Kernel.eval(File.read(path), binding, path)
    true
   end

  # Render the ERB template located at <tt>pathname</tt>. If a template exists
  # with the same basename at RAILS_ROOT/app/manifests/, it is used instead.
  # This is useful to override templates provided by plugins to customize
  # application configuration files.
  def template(pathname, b = nil)
    b ||= self.send(:binding)
    template_contents = nil
    basename = pathname.index('/') ? pathname.split('/').last : pathname
    if File.exist?(File.expand_path(File.join(self.class.working_directory, 'app', 'manifest', 'templates', basename)))
      template_contents = File.read(File.expand_path(File.join(self.class.working_directory, 'app', 'manifest', 'templates', basename)))
    elsif File.exist?(File.expand_path(pathname))
      template_contents = File.read(File.expand_path(pathname))
    else
      raise LoadError, "Can't find template #{pathname}"
    end
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
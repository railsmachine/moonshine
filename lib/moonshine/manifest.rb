# This is the base Moonshine Manifest class, which provides a simple system
# for loading moonshine recpies from plugins, a template helper, and parses
# several configuration files:
#
#   config/moonshine.yml
#
# The contents of <tt>config/moonshine.yml</tt> are expected to serialize into
# a hash, and are loaded into the manifest's Configatron::Store.
#
#   config/database.yml
#
# The contents of your database config are parsed and are available at
# <tt>configuration[:database]</tt>.
#
# If you'd like to create another 'default rails stack' using other tools that
# what Moonshine::Manifest::Rails uses, subclass this and go nuts.
class Moonshine::Manifest < ShadowPuppet::Manifest
  # Load a Moonshine Plugin
  #
  #   class MyManifest < Moonshine::Manifest
  #
  #     # Evals vendor/plugins/moonshine_my_app/moonshine/init.rb
  #     plugin :moonshine_my_app
  #
  #     # Evals lib/my_recipe.rb
  #     plugin 'lib/my_recipe.rb'
  #
  #     ...
  #   end
  def self.plugin(name = nil)
    if name.is_a?(Symbol)
      path = File.join(rails_root, 'vendor', 'plugins', name.to_s, 'moonshine', 'init.rb')
    else
      path = name
    end
    Kernel.eval(File.read(path), binding, path)
    true
   end

  # The working directory of the Rails application this manifests describes.
  def self.rails_root
   @rails_root ||= File.expand_path(ENV["RAILS_ROOT"] || Dir.getwd)
  end

  def rails_root
   self.class.rails_root
  end
  
  # The current Rails environment
  def self.rails_env
    ENV["RAILS_ENV"] || 'production'
  end
  
  def rails_env
    self.class.rails_env
  end

  # The current environment's database configuration
  def database_environment
   configuration[:database][rails_env.to_sym]
  end
  
  # The current deployment target. Best when used with capistrano-ext's multistage settings.
  def self.deploy_stage
    ENV['DEPLOY_STAGE'] || 'undefined'
  end
  
  def deploy_stage
    self.class.deploy_stage
  end
  
  # Only run tasks on the specified stage.
  def on_stage(stagename)
    yield if deploy_stage == stagename
  end

  # Render the ERB template located at <tt>pathname</tt>. If a template exists
  # with the same basename at <tt>RAILS_ROOT/app/manifests/templates</tt>, it
  # is used instead. This is useful to override templates provided by plugins
  # to customize application configuration files.
  def template(pathname, b = binding)
    template_contents = nil
    basename = pathname.index('/') ? pathname.split('/').last : pathname
    if File.exist?(File.expand_path(File.join(rails_root, 'app', 'manifests', 'templates', basename)))
      template_contents = File.read(File.expand_path(File.join(rails_root, 'app', 'manifests', 'templates', basename)))
    elsif File.exist?(File.expand_path(pathname))
      template_contents = File.read(File.expand_path(pathname))
    else
      raise LoadError, "Can't find template #{pathname}"
    end
    ERB.new(template_contents).result(b)
  end

  # config/moonshine.yml
  configure(YAML::load(ERB.new(IO.read(File.join(rails_root, 'config', 'moonshine.yml'))).result))

  # database config
  configure(:database => YAML::load(ERB.new(IO.read(File.join(rails_root, 'config', 'database.yml'))).result))

  # gems
  configure(:gems => (YAML.load_file(File.join(rails_root, 'config', 'gems.yml')) rescue nil))
end
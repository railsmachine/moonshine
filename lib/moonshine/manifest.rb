# This is the base Moonshine Manifest class, which provides a simple system
# for loading Moonshine recipes from plugins, a template helper, and parses
# several configuration files:
#
#   config/moonshine.yml
#   config/moonshine/<rails_env>.yml
#
# The contents of <tt>config/moonshine.yml</tt> are expected to serialize into
# a hash, and are loaded into the manifest's Configatron::Store.
#
#   config/database.yml
#
# The contents of your database config are parsed and are available at
# <tt>configuration[:database]</tt>.
#
# If you'd like to create another 'default rails stack' using other tools than
# what Moonshine::Manifest::Rails uses, subclass this and go nuts.
class Moonshine::Manifest < ShadowPuppet::Manifest

  # Load a Moonshine Plugin
  #
  # *Deprecated*: plugins are now auto-loaded.
  #
  #   class MyManifest < Moonshine::Manifest
  #
  #     # Evals vendor/plugins/moonshine_awesome/moonshine/init.rb
  #     plugin :awesome
  #
  #     # Evals lib/my_recipe.rb
  #     plugin 'lib/my_recipe.rb'
  #
  #     ...
  #   end
  def self.plugin(name = nil)
    require 'active_support/core_ext/module/attribute_accessors'
    require 'active_support/core_ext/kernel/reporting'
    require 'active_support/deprecation'

    ActiveSupport::Deprecation.warn("explicitly calling the plugin method is deprecated, as plugins are now automatically loaded", caller)
    true
  end

  # The working directory of the Rails application this manifest describes.
  def self.rails_root
   @rails_root ||= Pathname.new(ENV["RAILS_ROOT"] || Dir.getwd).expand_path
  end

  def self.moonshine_yml
    rails_root.join('config', 'moonshine.yml')
  end

  def self.database_yml
    rails_root.join('config', 'database.yml')
  end

  # The current Rails environment
  def self.rails_env
    ENV["RAILS_ENV"] || 'production'
  end

  # HAX for cases where we evaluate ERB that refers to Rails.env
  def self.env
    rails_env
  end

  # The current environment's database configuration
  def database_environment
   if configuration[:database]
     configuration[:database][rails_env.to_sym]
    else
      {}
    end
  end

  # The current deployment target. Best when used with capistrano-ext's multistage settings.
  def self.deploy_stage
    ENV['DEPLOY_STAGE'] || 'undefined'
  end

  # Delegate missing methods to class, so we don't have to have so many convenience methods
  def method_missing(method, *args, &block)
    if self.class.respond_to?(method)
      self.class.send(method, *args, &block)
    else
      super
    end
  end

  def respond_to?(method, include_private = false)
    super || self.class.respond_to?(method, include_private)
  end

  # Only run tasks on the specified deploy_stage.
  #
  # You can call it with the exact stage you want to run on:
  #
  #  on_stage(:my_stage) do
  #    puts "I'm on my_stage"
  #  end
  #
  # Or you can pass an array of stages to run on:
  #
  #  on_stage(:my_stage, :my_other_stage) do
  #    puts "I'm on one of my stages"
  #  end
  #
  # Or you can run a task unless it is on a stage:
  #
  #  on_stage(:unless => :my_stage) do
  #    puts "I'm not on my_stage"
  #  end
  #
  # Or you can run a task unless it is on one of several stages:
  #
  #  on_stage(:unless => [:my_stage, :my_other_stage]) do
  #    puts "I'm not on my stages"
  #  end
  def self.on_stage(*args)
    options = args.extract_options!
    if_opt = options[:if]
    unless_opt = options[:unless]

    unless if_opt || unless_opt
      if_opt = args
    end

    if if_opt && if_opt.is_a?(Array) && if_opt.map {|x| x.to_s}.include?(deploy_stage)
      yield
    elsif if_opt && (if_opt.is_a?(String) || if_opt.is_a?(Symbol)) && deploy_stage == if_opt.to_s
      yield
    elsif unless_opt && unless_opt.is_a?(Array) && !unless_opt.map {|x| x.to_s}.include?(deploy_stage)
      yield
    elsif unless_opt && (unless_opt.is_a?(String) || unless_opt.is_a?(Symbol)) && deploy_stage != unless_opt.to_s
      yield
    end
  end

  def self.local_template_dir
    @local_template_dir ||= rails_root.join('app/manifests/templates')
  end

  def self.local_template(pathname)
   (local_template_dir + pathname.basename).expand_path
  end

  # Render the ERB template located at <tt>pathname</tt>. If a template exists
  # with the same basename at <tt>RAILS_ROOT/app/manifests/templates</tt>, it
  # is used instead. This is useful to override templates provided by plugins
  # to customize application configuration files.
  def self.template(pathname, b = binding)
    pathname = Pathname.new(pathname) unless pathname.kind_of?(Pathname)

    template_contents = if local_template(pathname).exist?
                          template_contents = local_template(pathname).read
                        elsif pathname.exist?
                          template_contents = pathname.read
                        else
                          raise LoadError, "Can't find template #{pathname}"
                        end
    ERB.new(template_contents).result(b)
  end

  def template(pathname, b = binding)
    self.class.template(pathname, b)
  end

  # autoload plugins
  Dir.glob(rails_root + 'vendor/plugins/*/moonshine/init.rb').each do |path|
    Kernel.eval(File.read(path), binding, path)
  end  # config/moonshine.yml

  if moonshine_yml.exist?
    configure(YAML::load(ERB.new(moonshine_yml.read).result))
  end

  # config/moonshine/#{rails_env}.yml
  env_config = rails_root.join('config', 'moonshine', rails_env + '.yml')
  if env_config.exist?
    configure(YAML::load(ERB.new(env_config.read).result))
  end

  # database config
  if database_yml.exist?
    configure(:database => YAML::load(ERB.new(database_yml.read).result))
  end

  # gems
  gems_yml = rails_root.join('config', 'gems.yml')
  if gems_yml.exist?
    configure(:gems => (YAML.load_file(gems_yml) rescue nil))
  end


end

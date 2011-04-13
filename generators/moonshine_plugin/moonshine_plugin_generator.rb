class MoonshinePluginGenerator < Rails::Generator::Base
  attr_reader :name, :plugin_name, :module_name

  def initialize(runtime_args, runtime_options = {})
    plugin = runtime_args.shift
    if plugin
      @name = plugin.downcase.underscore
      @module_name = @name.camelize
      @plugin_name = 'moonshine_' + name
    else
      puts "Please specify the name of your plugin"
      puts "script/generate moonshine_plugin <name>"
      puts
      exit
    end
    super
  end

  def manifest
    record do |m|
      m.directory "vendor/plugins/#{plugin_name}"
      m.template  "LICENSE", "vendor/plugins/#{plugin_name}/LICENSE"
      m.template  "README.markdown", "vendor/plugins/#{plugin_name}/README.markdown"
      m.directory "vendor/plugins/#{plugin_name}/moonshine"
      m.template  'init.rb', "vendor/plugins/#{plugin_name}/moonshine/init.rb"
      m.directory "vendor/plugins/#{plugin_name}/lib/moonshine"
      m.template  'plugin.rb', "vendor/plugins/#{plugin_name}/lib/moonshine/#{name}.rb"
      m.directory "vendor/plugins/#{plugin_name}/spec/moonshine"
      m.template  'spec.rb', "vendor/plugins/#{plugin_name}/spec/moonshine/#{name}_spec.rb"
      m.template  'spec_helper.rb', "vendor/plugins/#{plugin_name}/spec/spec_helper.rb"
    end
  end
  
end

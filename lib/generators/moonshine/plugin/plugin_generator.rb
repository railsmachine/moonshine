module Moonshine
  module Generators
    class PluginGenerator < Rails::Generators::Base
      desc Pathname.new(__FILE__).dirname.join('..', '..', '..', '..', 'generators', 'moonshine_plugin', 'USAGE').read

      argument :name, :required => true, :description => 'The name of the new plugin'

      def self.source_root
        @_moonshine_source_root ||= Pathname.new(__FILE__).dirname.join('..', '..', '..', '..', 'generators', 'moonshine_plugin', 'templates')
      end

      def manifest
        template  "README.rdoc", "vendor/plugins/#{plugin_name}/README.rdoc"
        template  'init.rb', "vendor/plugins/#{plugin_name}/moonshine/init.rb"
        template  'plugin.rb', "vendor/plugins/#{plugin_name}/lib/#{name}.rb"
        template  'spec.rb', "vendor/plugins/#{plugin_name}/spec/#{name}_spec.rb"
        template  'spec_helper.rb', "vendor/plugins/#{plugin_name}/spec/spec_helper.rb"
      end

      protected

      def module_name
        @module_name ||= name.camelize
      end

      def plugin_name
        @plugin_name ||= 'moonshine_' + name
      end
    end
  end
end

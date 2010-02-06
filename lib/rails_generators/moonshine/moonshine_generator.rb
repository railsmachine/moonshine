class MoonshineGenerator < Rails::Generators::Base
  argument :name, :optional => true, :default => 'application'
 
  def self.source_root
    @_moonshine_source_root ||= Pathname.new(__FILE__).dirname.join('..', '..', '..', 'generators', 'moonshine', 'templates')
  end
  
  def manifest
    template "readme.templates", "app/manifests/templates/README"
    template "moonshine.rb", "app/manifests/#{file_name}.rb"
    template "moonshine.yml", "config/moonshine.yml"
    
    intro = <<-INTRO
    
After the Moonshine generator finishes don't forget to:
 
- Edit config/moonshine.yml
Use this file to manage configuration related to deploying and running the app: 
domain name, git repos, package dependencies for gems, and more.
 
- Edit app/manifests/#{file_name}.rb
Use this to manage the configuration of everything else on the server:
define the server 'stack', cron jobs, mail aliases, configuration files 
 
    INTRO
    puts intro if File.basename($0) == 'generate'
  end
 
protected
  def file_name
    @manifest_name ||= name.downcase.underscore + "_manifest"
  end
 
  def klass_name
    @klass_name ||= file_name.classify
  end

  def ruby_version
    @ruby_version = if Rails::VERSION::MAJOR >= 3
                      "ree187"
                    else
                      "ree"
                    end
  end
end


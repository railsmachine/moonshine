require 'rbconfig'

class MoonshineGenerator < Rails::Generator::Base
  attr_reader :file_name, :klass_name

  def initialize(runtime_args, runtime_options = {})
    name = runtime_args.shift || 'application'
    @file_name = name.downcase.underscore + "_manifest"
    @klass_name = @file_name.classify
    super
  end

  def gems
    gem_array = returning Array.new do |hash|
      Rails.configuration.gems.map do |gem|
        hash = { :name => gem.name }
        hash.merge!(:source => gem.source) if gem.source
        hash.merge!(:version => gem.requirement.to_s) if gem.requirement
        hash
      end if Rails.respond_to?( 'configuration' )
    end
    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end
    gem_array
  end

  def manifest
    recorded_session = record do |m|
      m.directory 'app/manifests'
      m.directory 'app/manifests/templates'
      m.template  'moonshine.rb', "app/manifests/#{file_name}.rb"
      m.directory 'app/manifests/templates'
      m.template  'readme.templates', 'app/manifests/templates/README'
      m.directory 'config'
      m.template  'moonshine.yml', "config/moonshine.yml"
      m.template  'gems.yml', "config/gems.yml", :assigns => { :gems => gems }
    end
    
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
    
    recorded_session
  end
  
end
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
    gem_array = Rails.configuration.gems.map do |gem|
      hash = { :name => gem.name }
      hash.merge!(:source => gem.source) if gem.source
      hash.merge!(:version => gem.requirement.to_s) if gem.requirement
      hash
    end
    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end
    gem_array
  end

  def manifest
    record do |m|
      m.directory 'app/manifests'
      m.directory 'app/manifests/templates'
      m.template  'moonshine.rb', "app/manifests/#{file_name}.rb"
      m.directory 'config'
      m.template  'moonshine.yml', "config/moonshine.yml", :assigns => { :gems => gems }
    end
  end

end
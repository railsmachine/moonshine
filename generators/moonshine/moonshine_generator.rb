require 'rbconfig'

class MoonshineGenerator < Rails::Generator::Base
  attr_reader :file_name, :klass_name

  def initialize(runtime_args, runtime_options = {})
    name = runtime_args.shift || 'application'
    @file_name = name.downcase.underscore + "_manifest"
    @klass_name = @file_name.classify
    super
  end

  def manifest
    record do |m|
      m.directory 'app/manifests'
      m.template  'moonshine.rb', "app/manifests/#{file_name}.rb"
      m.template  'moonshine.yml', "config/moonshine.yml"
    end
  end

end

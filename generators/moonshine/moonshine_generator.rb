require 'rbconfig'

class MoonshineGenerator < Rails::Generator::Base
  attr_reader :file_name, :klass_name

  def initialize(runtime_args, runtime_options = {})
    puts banner and exit(1) unless runtime_args.shift
    @file_name = runtime_args.shift.downcase.underscore
    @klass_name = @file_name.classify
    super
  end

  def manifest
    record do |m|
      m.directory 'config/moonshine'
      m.template  'moonshine.rb',        "config/moonshine/#{file_name}.rb"
    end
  end

protected

  def banner
    """Usage: #{$0} server SERVERNAME

Example:


  #{$0} server MyAppMain"""
  end

end

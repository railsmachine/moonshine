require 'rbconfig'

class MoonshineGenerator < Rails::Generator::Base
  attr_reader :server_name

  def initialize(runtime_args, runtime_options = {})
    @server_name = (runtime_args.shift || 'default').downcase
    super
  end

  def manifest
    record do |m|
      m.directory 'config/moonshine'
      m.template  'server.rb',        "config/moonshine/#{server_name}_moonshine_server.rb"
    end
  end

protected

  def banner
    "Usage: #{$0} server SERVERNAME"
  end

end
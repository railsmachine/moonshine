require 'rubygems'
require 'isolate/scenarios'
require 'isolate/now'
require 'spec/autorun'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'moonshine'
require 'moonshine/matchers'
require 'shadow_puppet/test'

Spec::Runner.configure do |config|
  config.include Moonshine::Matchers
  config.include Capistrano::Spec::Matchers
  config.include Capistrano::Spec::Helpers
  config.include MoonshineHelpers
  config.extend MoonshineHelpers::ClassMethods
end

require 'rubygems'
require 'test/unit'
require 'ginger'
require 'rails/version'

require 'moonshine'
require 'shadow_puppet/test'
require 'mocha'

Test::Unit::TestCase.class_eval do
  if Rails::VERSION::MAJOR < 3
    ENV['RAILS_ENV'] = 'test'
    ENV['RAILS_ROOT'] ||= File.join(File.dirname(__FILE__), 'rails_root')
    RAILS_ROOT = ENV['RAILS_ROOT'].dup
    FileUtils.mkdir_p RAILS_ROOT

    require 'logger'
    RAILS_DEFAULT_LOGGER = Logger.new($stdout)
    require 'initializer'
    Rails.configuration = Rails::Configuration.new

    require 'rails_generator'
    require 'rails_generator/scripts/generate'
    Rails::Generator::Base.sources << Rails::Generator::PathSource.new(:moonshine, Pathname.new(__FILE__).dirname.join('..', 'generators'))
  end

  def fake_rails_root
    File.join(File.dirname(__FILE__), 'rails_root')
  end


end

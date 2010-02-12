require 'rubygems'
require 'test/unit'
require 'ginger'
require 'rails/version'


require 'pathname'
$here = Pathname.new(__FILE__).dirname

Test::Unit::TestCase.class_eval do
  if Rails::VERSION::MAJOR < 3
    ENV['RAILS_ENV'] = 'test'
    ENV['RAILS_ROOT'] = fake_rails_root = $here.join('rails_root')
    RAILS_ROOT = fake_rails_root.to_s
    FileUtils.mkdir_p RAILS_ROOT

    FileUtils.mkdir_p fake_rails_root.join('config')
    FileUtils.cp $here.join('moonshine.yml'), fake_rails_root.join('config', 'moonshine.yml')

    FileUtils.mkdir_p fake_rails_root.join('config', 'moonshine')
    FileUtils.cp $here.join('moonshine-test.yml'), fake_rails_root.join('config', 'moonshine', 'test.yml')

    FileUtils.mkdir_p fake_rails_root.join('config')
    FileUtils.cp $here.join('database.yml'), fake_rails_root.join('config', 'database.yml')

    require 'logger'
    RAILS_DEFAULT_LOGGER = Logger.new($stdout)
    require 'initializer'
    Rails.configuration = Rails::Configuration.new

    require 'rails_generator'
    require 'rails_generator/scripts/generate'
    Rails::Generator::Base.sources << Rails::Generator::PathSource.new(:moonshine, Pathname.new(__FILE__).dirname.join('..', 'generators'))
  end

  require 'moonshine'
  require 'shadow_puppet/test'
  require 'mocha'

  def fake_rails_root
    Pathname.new($here).join('rails_root')
  end

  def create_database_yml
    FileUtils.mkdir_p fake_rails_root.join('config')
    FileUtils.cp $here.join('database.yml'), fake_rails_root.join('config', 'database.yml')
  end

  def create_moonshine_test_yml
    FileUtils.mkdir_p fake_rails_root.join('config', 'moonshine')
    FileUtils.cp $here.join('moonshine-test.yml'), fake_rails_root.join('config', 'moonshine', 'test.yml')
  end


end

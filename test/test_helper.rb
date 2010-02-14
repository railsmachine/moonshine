require 'rubygems'
require 'test/unit'
require 'ginger'

require 'pathname'
$here = Pathname.new(__FILE__).dirname

# hold off requiring moonshine for a second...

Test::Unit::TestCase.class_eval do
  def fake_rails_root
    self.class.fake_rails_root
  end

  def self.fake_rails_root
    $here.join('rails_root')
  end

  def generator_rails_root
    self.class.generator_rails_root
  end

  def self.generator_rails_root
    breakpoint
    $here.join('generator_rails_root')
  end

  # rails version specific kludge to get 
  require 'rails/version'
  if Rails::VERSION::MAJOR == 2
    require 'support/rails_2_generator_kludge'
  end

  # Need to generate our scaffold configuration _BEFORE_ requiring moonshine
  # because a manifest configures itself when moonshine is required the first time
  fake_rails_root = $here.join('rails_root')
  FileUtils.mkdir_p fake_rails_root.join('config')
  FileUtils.cp $here.join('moonshine.yml'), fake_rails_root.join('config', 'moonshine.yml')

  FileUtils.mkdir_p fake_rails_root.join('config', 'moonshine')
  FileUtils.cp $here.join('moonshine-test.yml'), fake_rails_root.join('config', 'moonshine', 'test.yml')

  FileUtils.mkdir_p fake_rails_root.join('config')
  FileUtils.cp $here.join('database.yml'), fake_rails_root.join('config', 'database.yml')

  # it's ok to require now
  require 'moonshine'
  require 'shadow_puppet/test'
  require 'mocha'

  def create_database_yml
    FileUtils.mkdir_p fake_rails_root.join('config')
    FileUtils.cp $here.join('database.yml'), fake_rails_root.join('config', 'database.yml')
  end

  def create_moonshine_test_yml
    FileUtils.mkdir_p fake_rails_root.join('config', 'moonshine')
    FileUtils.cp $here.join('moonshine-test.yml'), fake_rails_root.join('config', 'moonshine', 'test.yml')
  end


end

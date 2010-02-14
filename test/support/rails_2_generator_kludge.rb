require 'logger'
RAILS_ROOT = $here.join('rails_root').to_s
RAILS_DEFAULT_LOGGER = Logger.new($here.join('test.log')) # avoids generator output on stdout

ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] = fake_rails_root = $here.join('rails_root')
FileUtils.mkdir_p RAILS_ROOT


require 'initializer'
Rails.configuration = Rails::Configuration.new

require 'rails_generator'
require 'rails_generator/scripts/generate'
Rails::Generator::Base.sources << Rails::Generator::PathSource.new(:moonshine, Pathname.new(__FILE__).dirname.join('..', 'generators'))

# -*- encoding: utf-8 -*-
require File.expand_path('../lib/moonshine/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Josh Nichols"]
  gem.email         = ["josh@technicalpickles.com"]
  gem.description   = %q{Simple Rails deployment and configuration management. 15 minute deploys of Rails 2 or Rails 3 apps.}
  gem.summary       = %q{Moonshine is Rails deployment and configuration management done right.

By leveraging capistrano and puppet, moonshine allows you have a working application server in 15 minutes, and be able to sanely manage it’s configuration from the comfort of your version control of choice.}
  gem.homepage      = "http://github.com/railsmachine/moonshine"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "moonshine"
  gem.require_paths = ["lib"]
  gem.version       = Moonshine::VERSION

  gem.add_dependency 'shadow_puppet', '~> 0.6.1'
end

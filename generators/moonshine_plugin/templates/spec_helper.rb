require 'rubygems'
require 'test/unit'
gem 'rspec'
gem 'shadow_puppet'
require 'spec'
require 'shadow_puppet'
ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require File.join(File.dirname(__FILE__), '..', '..', 'moonshine', 'lib', 'moonshine.rb')
require File.join(File.dirname(__FILE__), '..', 'lib', '<%= name %>.rb')
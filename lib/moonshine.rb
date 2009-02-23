require 'shadow_puppet'
require 'capistrano'
require 'erb'
require 'active_support/inflector'
module Moonshine
end
require "#{File.dirname(__FILE__)}/moonshine/recipes.rb"
require "#{File.dirname(__FILE__)}/moonshine/manifest.rb"
require "#{File.dirname(__FILE__)}/moonshine/manifest/rails.rb"

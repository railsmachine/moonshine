require 'shadow_puppet'
require 'capistrano'
module Moonshine
end
require "#{File.dirname(__FILE__)}/moonshine/manifest.rb"
require "#{File.dirname(__FILE__)}/moonshine/manifest/rails.rb"

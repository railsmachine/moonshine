require 'shadow_puppet'
require 'capistrano'
module Moonshine
end
require "#{File.dirname(__FILE__)}/moonshine/manifest.rb"
Dir["#{File.dirname(__FILE__)}/moonshine/recipes/*"].each do |recipe|
  require recipe
end
require "#{File.dirname(__FILE__)}/moonshine/manifest/rails.rb"

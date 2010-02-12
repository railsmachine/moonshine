require 'shadow_puppet'
require 'erb'
require 'active_support/inflector'
require 'pathname'
module Moonshine  #:nodoc:
end
require File.join(File.dirname(__FILE__), 'moonshine', 'manifest.rb')
require File.join(File.dirname(__FILE__), 'moonshine', 'manifest', 'rails.rb')

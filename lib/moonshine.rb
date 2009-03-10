require 'shadow_puppet'
require 'erb'
require 'active_support/inflector'
module Moonshine  #:nodoc:
end
class Configatron::Store
  def to_s
    ''
  end
end
require File.join(File.dirname(__FILE__), 'moonshine', 'manifest.rb')
require File.join(File.dirname(__FILE__), 'moonshine', 'manifest', 'rails.rb')
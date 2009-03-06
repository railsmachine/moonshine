require 'shadow_puppet'
require 'erb'
require 'active_support/inflector'
module Moonshine  #:nodoc:
  module Manifest  #:nodoc:
  end
  module Plugin  #:nodoc:
  end
end
class Configatron::Store
  def to_s
    ''
  end
end
require "#{File.dirname(__FILE__)}/moonshine/manifest/base.rb"
require "#{File.dirname(__FILE__)}/moonshine/manifest/rails.rb"

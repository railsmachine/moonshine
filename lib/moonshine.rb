require 'shadow_puppet'

require 'erb'
require 'active_support/inflector'
require 'pathname'

module Moonshine  #:nodoc:
end

# make sure lib is on the LOAD_PATH.
# can't just rely on other stuff because of the way manifests are loaded at deploy time
here = File.expand_path('.', File.dirname(__FILE__))
unless $LOAD_PATH.any? {|path| File.expand_path(path) == here }
  $LOAD_PATH.unshift(here)
end

require 'moonshine/core_ext'
require 'moonshine/manifest'
require 'moonshine/manifest/rails'

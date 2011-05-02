# These extensions to Pathname let us use Pathname with puppet more easily, ie
#
#     exec "blah", :cwd => Pathname.new('/etc')
module Moonshine
  # These are the extensions we use to deal with reality.
  module CoreExt
    ## Pathname
    #
    # Pathname is basically awesome. Unfortunately, puppet doesn't deal particularly well with it all the time.
    # This extension let's it behave more string-like for puppet's sake
    module Pathname
      def =~(pattern)
        to_s =~ pattern
      end

      def gsub(*args)
        to_s.gsub(*args)
      end
    end
  end
end

Pathname.class_eval do
  include Moonshine::CoreExt::Pathname
end

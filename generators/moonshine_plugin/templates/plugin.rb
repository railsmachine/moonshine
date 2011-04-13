module Moonshine
  module <%= module_name %>

    # Define options for this plugin via the <tt>configure</tt> method
    # in your application manifest:
    #
    #    configure(:<%= name %> => {:foo => true})
    #
    # Moonshine will autoload plugins, just call the recipe(s) you need in your
    # manifests:
    #
    #    recipe :<%= name %>
    def <%= name %>(options = {})
      # define the recipe
      # options specified with the configure method will be 
      # automatically available here in the options hash.
      #    options[:foo]   # => true
    end
    
  end
end

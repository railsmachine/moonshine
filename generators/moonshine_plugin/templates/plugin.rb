module <%= module_name %>

  # Add recipes here to create the functionality of your plugin
  # You can set variables in the application manifest via the
  # <tt>configure</tt> method:
  #
  #   configure(:my_plugin => {:key => 'value'})
  #
  # You can then access those variables here in the plugin:
  #
  #   configuration[:my_plugin][:key]
  #
  # Remember to include the plugin and call the recipe(s)
  # you need in the manifest:
  #
  #  plugin :<%= name %>
  #  recipe :<%= name %>
  def <%= name %>
    # define the recipe
  end
  
end
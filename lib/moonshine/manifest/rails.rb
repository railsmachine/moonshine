class Moonshine::Manifest::Rails < Moonshine::Manifest
  include Moonshine::Recipes::MySQLRecipes
  include Moonshine::Recipes::PassengerRecipes
  include Moonshine::Recipes::ApacheRecipes
  include Moonshine::Recipes::RailsRecipes

  recipe :rails_gems, :rails_directories
  recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_load_schema, :mysql_migrations
  recipe :apache_server
  recipe :passenger_gem, :passenger_apache_module, :passenger_site

end
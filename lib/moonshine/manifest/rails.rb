#The Rails Manifest includes recipes for Apache, Mysql, Sqlite3 and Rails
#running on Ubuntu 8.10 or greater.
class Moonshine::Manifest::Rails < Moonshine::Manifest
  require File.join(File.dirname(__FILE__), 'rails', 'passenger.rb')
  include Moonshine::Manifest::Rails::Passenger
  require File.join(File.dirname(__FILE__), 'rails', 'mysql.rb')
  include Moonshine::Manifest::Rails::Mysql
  require File.join(File.dirname(__FILE__), 'rails', 'sqlite3.rb')
  include Moonshine::Manifest::Rails::Sqlite3
  require File.join(File.dirname(__FILE__), 'rails', 'apache.rb')
  include Moonshine::Manifest::Rails::Apache
  require File.join(File.dirname(__FILE__), 'rails', 'rails.rb')
  include Moonshine::Manifest::Rails::Rails
  require File.join(File.dirname(__FILE__), 'rails', 'os.rb')
  include Moonshine::Manifest::Rails::Os
end
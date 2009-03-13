#The Rails Manifest includes recipes for Apache, Mysql, Sqlite3 and Rails
#running on Ubuntu 8.10 or greater.
class Moonshine::Manifest::Rails < Moonshine::Manifest
  def validate_platform
    unless Facter.lsbdistid == 'Ubuntu' && Facter.lsbdistrelease.to_f >= 8.1
      error = <<-ERROR


      Moonshine::Manifest::Rails is currently only supported on Ubuntu 8.10
      or greater. If you'd like to see your favorite distro supported, fork
      Moonshine on GitHub!
      ERROR
      raise NotImplementedError, error
    end
  end
  recipe :validate_platform

  configure(:apt_gems => YAML.load_file(File.join(File.dirname(__FILE__), 'rails', 'apt_gems.yml')))

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
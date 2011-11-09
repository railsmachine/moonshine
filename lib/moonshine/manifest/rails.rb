# The Rails Manifest includes recipes for Apache, Mysql, Sqlite3 and Rails
# running on Ubuntu 8.10 or greater.
class Moonshine::Manifest::Rails < Moonshine::Manifest
  def validate_platform
    unless Facter.lsbdistid == 'Ubuntu' && Facter.lsbdistrelease.to_f >= 8.04
      error = <<-ERROR


      Moonshine::Manifest::Rails is currently only supported on Ubuntu 8.04
      or greater. If you'd like to see your favorite distro supported, fork
      Moonshine on GitHub!
      ERROR
      raise NotImplementedError, error
    end
  end
  recipe :validate_platform

  def self.apt_gems_path
    Pathname.new(__FILE__).dirname + 'rails/apt_gems.yml'
  end
  configure(:apt_gems => YAML.load_file(apt_gems_path.to_s))

  require 'moonshine/manifest/rails/passenger'
  require 'moonshine/manifest/rails/mysql'
  require 'moonshine/manifest/rails/postgresql'
  require 'moonshine/manifest/rails/sqlite3'
  require 'moonshine/manifest/rails/apache'
  require 'moonshine/manifest/rails/rails'
  require 'moonshine/manifest/rails/os'

  include Moonshine::Manifest::Rails::Passenger
  include Moonshine::Manifest::Rails::Mysql
  include Moonshine::Manifest::Rails::Postgresql
  include Moonshine::Manifest::Rails::Sqlite3
  include Moonshine::Manifest::Rails::Apache
  include Moonshine::Manifest::Rails::Rails
  include Moonshine::Manifest::Rails::Os

  # A super recipe for installing Apache, Passenger, a database,
  # Rails, NTP, Cron, Postfix. To customize your stack, call the
  # individual recipes you want to include rather than default_stack.
  #
  # default_stack installs the database based on the adapter in database.yml for the rails environment
  def default_stack
    recipe :apache_server
    recipe :passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site
    case database_environment[:adapter]
    when 'mysql', 'mysql2'
      recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start
    when 'postgresql'
      recipe :postgresql_server, :postgresql_gem, :postgresql_user, :postgresql_database
    when 'sqlite', 'sqlite3'
      recipe :sqlite3
    end
    recipe :rails_rake_environment, :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations, :rails_logrotate
    recipe :ntp, :time_zone, :postfix, :cron_packages, :motd, :security_updates, :apt_sources, :hostname

    if configuration[:assets] && configuration[:assets][:enabled]
      recipe :rails_asset_pipeline
    end
  end

  def rails_template_dir
    @rails_template_dir ||= Pathname.new(__FILE__).dirname.join('rails', 'templates').expand_path
  end
end

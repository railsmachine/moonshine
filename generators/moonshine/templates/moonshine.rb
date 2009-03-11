require "#{File.dirname(__FILE__)}/../../vendor/plugins/moonshine/lib/moonshine.rb"
class <%= klass_name %> < Moonshine::Manifest::Rails
  # By default, configuration is automatically loaded from <tt>config/moonshine.yml</tt>
  # If necessary, you may provide extra configuration directly to this class.
  # The hash passed to the configure method is deep merged with what is in
  # <tt>config/moonshine.yml</tt>. This could be used, for example, to store
  # passwords and/or private keys outside of your SCM, or to query a web
  # service for configuration data.
  configure({
    :passenger   => {
      :max_pool_size => 3,
      :use_global_queue => true
    }
  })

  # These recipes are included in in Moonshine::Manifest::Rails
  recipe :apache_server
  recipe :passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site
  recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start
  recipe :rails_rake_environment, :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations
  # recipe :sqlite3
  recipe :ntp, :time_zone, :postfix, :cron_packages, :motd

  # add your application's custom requirements here
  def application_packages
    # package 'some_awesome_gem', :ensure => :installed, :provider => :gem, :require => package('some_awesome_native_package')
    # package 'some_awesome_native_package', :ensure => :installed
  end
  # The following line delcares the 'application_packages' method as a recipe
  recipe :application_packages
end
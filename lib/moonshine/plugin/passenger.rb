module Moonshine::Plugin::Passenger

  def passenger_gem
    package "passenger", :ensure => :latest, :provider => :gem
  end

  def passenger_apache_module
    # Install Apache2 developer library
    package "apache2-threaded-dev", :ensure => :installed

    # Build Passenger from source
    exec "build_passenger",
      :cwd => configatron.passenger.path,
      :command => '/usr/bin/ruby -S rake clean apache2',
      :creates => "#{configatron.passenger.path}/ext/apache2/mod_passenger.so",
      :require => [package("passenger"), package("apache2-mpm-worker"), package("apache2-threaded-dev")]

    file '/etc/apache2/mods-available/passenger.load',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.load.erb')),
      :require => [exec("build_passenger")],
      :notify => service("apache2"),
      :alias => "passenger_load"

    file '/etc/apache2/mods-available/passenger.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.conf.erb')),
      :require => [exec("build_passenger")],
      :notify => service("apache2"),
      :alias => "passenger_conf"

    a2enmod 'passenger', :require => [exec("build_passenger"), file("passenger_conf"), file("passenger_load")]
  end

  def passenger_site
    file "/etc/apache2/sites-available/#{configatron.application}",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.vhost.erb')),
      :notify => service("apache2"),
      :alias => "passenger_vhost",
      :require => exec("a2enmod passenger")

    a2dissite 'default', :require => file("passenger_vhost")
    a2ensite configatron.application, :require => file("passenger_vhost")
  end

  def passenger_configure_gem_path
    return configatron.passenger.path unless configatron.passenger.path.nil?
    version = begin
      Gem::SourceIndex.from_installed_gems.find_name("passenger").last.version.to_s
    rescue
      `gem install passenger --no-ri --no-rdoc`
      Gem::SourceIndex.from_installed_gems.find_name("passenger").last.version.to_s
    end
    configatron.passenger.path = "#{Gem.dir}/gems/passenger-#{version}"
  end

private

  def passenger_config_boolean(key)
    if key.nil?
      nil
    elsif key == 'Off' || (!!key) == false
      'Off'
    else
      'On'
    end
  end

end

include Moonshine::Plugin::Passenger
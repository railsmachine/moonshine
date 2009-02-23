module Moonshine::Recipes::PassengerRecipes

  def passenger_gem
    package "passenger", :ensure => :latest, :provider => :gem
  end

  def passenger_apache_module
    # Install Apache2 developer library
    package "apache2-threaded-dev", :ensure => :installed

    # Build Passenger from source
    exec "build_passenger", {:cwd => passenger_gem_path,
                             :command => '/usr/bin/ruby -S rake clean apache2',
                             :creates => "#{passenger_gem_path}/ext/apache2/mod_passenger.so",
                             :require => [package("passenger"), package("apache2-mpm-worker"), package("apache2-threaded-dev")] }

    file '/etc/apache2/mods-available/passenger.load', { :ensure => :present,
                      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.load.erb')),
                      :require => [exec("build_passenger")],
                      :notify => service("apache2"),
                      :alias => "passenger_load" }

    file '/etc/apache2/mods-available/passenger.conf', { :ensure => :present,
                      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.conf.erb')),
                      :require => [exec("build_passenger")],
                      :notify => service("apache2"),
                      :alias => "passenger_conf" }

    exec "enable_passenger", { :command => '/usr/sbin/a2enmod passenger',
                               :unless => 'ls /etc/apache2/mods-enabled/passenger.*',
                               :require => [exec("build_passenger"), file("passenger_conf"), file("passenger_load")]}
  end

  def passenger_site
    file "/etc/apache2/sites-available/#{configuration[:application]}", { :ensure => :present,
                      :content => template(File.join(File.dirname(__FILE__), '..', 'templates', 'passenger.vhost.erb')),
                      :notify => service("apache2"),
                      :alias => "passenger_vhost",
                      :require => exec("enable_passenger") }

    exec "passenger_disable_default_site", { :command => "/usr/sbin/a2dissite default",
                             :onlyif => "ls /etc/apache2/sites-enabled/*default",
                             :require => [file("passenger_vhost")],
                             :notify => service("apache2") }

    exec "passenger_enable_site", { :command => "/usr/sbin/a2ensite #{configuration[:application]}",
                             :unless => "ls /etc/apache2/sites-enabled/#{configuration[:application]}",
                             :require => [file("passenger_vhost")],
                             :notify => service("apache2") }
  end

private

  def passenger_gem_path
    version = begin
      Gem::SourceIndex.from_installed_gems.find_name("passenger").last.version.to_s
    rescue
      `gem install passenger --no-ri --no-rdoc`
      Gem::SourceIndex.from_installed_gems.find_name("passenger").last.version.to_s
    end
    "#{Gem.dir}/gems/passenger-#{version}"
  end
  

end
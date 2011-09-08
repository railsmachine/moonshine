module Moonshine::Manifest::Rails::Passenger

  BLESSED_VERSION = '3.0.9'

  # Install the passenger gem
  def passenger_gem
    configure(:passenger => {})
    if configuration[:passenger][:version] && configuration[:passenger][:version] < "3.0"
      package "passenger",
        :ensure => configuration[:passenger][:version],
        :provider => :gem
    elsif configuration[:passenger][:version].nil? || configuration[:passenger][:version] == :latest
      package "passenger",
        :ensure => BLESSED_VERSION,
        :provider => :gem,
        :require => [ package('libcurl4-openssl-dev') ]
      package 'libcurl4-openssl-dev', :ensure => :installed
    elsif configuration[:passenger][:version]
      package "passenger",
        :ensure => (configuration[:passenger][:version]),
        :provider => :gem,
        :require => [ package('libcurl4-openssl-dev') ]
      package 'libcurl4-openssl-dev', :ensure => :installed
    end
  end

  # Build, install, and enable the passenger apache module. Please see the
  # <tt>passenger.conf.erb</tt> template for passenger configuration options.
  def passenger_apache_module
    # Install Apache2 developer library
    package "apache2-threaded-dev", :ensure => :installed

    file "/usr/local/src", :ensure => :directory

    exec "symlink_passenger",
      :command => 'ln -nfs `passenger-config --root` /usr/local/src/passenger',
      :unless => 'ls -al /usr/local/src/passenger | grep `passenger-config --root`',
      :require => [
        package("passenger"),
        file("/usr/local/src")
      ]

    # Build Passenger from source
    exec "build_passenger",
      :cwd => configuration[:passenger][:path],
      :command => 'sudo /usr/bin/ruby -S rake clean apache2',
      :unless => [
        "ls `passenger-config --root`/ext/apache2/mod_passenger.so",
        "ls `passenger-config --root`/ext/ruby/ruby-*/passenger_native_support.so",
        "ls `passenger-config --root`/agents/PassengerLoggingAgent"
        ].join(" && "),
      :require => [
        package("passenger"),
        package("apache2-mpm-worker"),
        package("apache2-threaded-dev"),
        exec('symlink_passenger')
      ],
      :timeout => 108000

    load_template = "LoadModule passenger_module #{configuration[:passenger][:path]}/ext/apache2/mod_passenger.so"

    file '/etc/apache2/mods-available/passenger.load',
      :ensure => :present,
      :content => load_template,
      :require => [exec("build_passenger")],
      :notify => service("apache2"),
      :alias => "passenger_load"

    file '/etc/apache2/mods-available/passenger.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'passenger.conf.erb')),
      :require => [exec("build_passenger")],
      :notify => service("apache2"),
      :alias => "passenger_conf"

    a2enmod 'headers', :notify => service('apache2')

    a2enmod 'passenger', :require => [exec("build_passenger"), file("passenger_conf"), file("passenger_load"), exec('a2enmod headers')]
  end

  # Creates and enables a vhost configuration named after your application.
  # Also ensures that the <tt>000-default</tt> vhost is disabled.
  def passenger_site
    file "/etc/apache2/sites-available/#{configuration[:application]}",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'passenger.vhost.erb')),
      :notify => service("apache2"),
      :alias => "passenger_vhost",
      :require => exec("a2enmod passenger")

    a2dissite '000-default', :require => file("passenger_vhost")
    a2ensite configuration[:application], :require => file("passenger_vhost")
  end

  def passenger_configure_gem_path
    configure(:passenger => {})
    if configuration[:passenger][:version].nil? || configuration[:passenger][:version] == :latest
      configure(:passenger => { :path => "#{Gem.dir}/gems/passenger-#{BLESSED_VERSION}" })
    elsif configuration[:passenger][:version]
      configure(:passenger => { :path => "#{Gem.dir}/gems/passenger-#{configuration[:passenger][:version]}" })
    end
  end

private

  def passenger_config_boolean(key, default = true)
    if key.nil?
      default ? 'On' : 'Off'
    else
      ((!!key) == true) ? 'On' : 'Off'
    end
  end

end

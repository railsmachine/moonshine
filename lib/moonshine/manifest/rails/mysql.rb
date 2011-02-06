module Moonshine::Manifest::Rails::Mysql

  # Installs <tt>mysql-server</tt> from apt and enables the <tt>mysql</tt>
  # service. Also creates a configuration file at
  # <tt>/etc/mysql/conf.d/moonshine.cnf</tt>. See
  # <tt>templates/moonshine.cnf</tt> for configuration options.
  def mysql_server
    package 'mysql-server', :ensure => :installed
    service 'mysql', :ensure => :running, :require => [
      package('mysql-server')
    ]

    # ensure the mysql key is present on the configuration hash
    configure(:mysql => { :version => mysql_version })

    file '/etc/mysql', :ensure => :directory
    file '/etc/mysql/conf.d', :ensure => :directory
    
    file '/etc/mysql/conf.d/innodb.cnf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'innodb.cnf.erb')),
      :before => package('mysql-server')
    
    file '/etc/mysql/conf.d/moonshine.cnf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'moonshine.cnf.erb')),
      :require => package('mysql-server'),
      :notify => service('mysql'),
      :checksum => :md5

    file '/etc/logrotate.d/varlogmysql.conf', :ensure => :absent
  end

  # Install the <tt>mysql</tt> rubygem and dependencies
  def mysql_gem
    gem(mysql_gem_name, :alias => 'mysql')
  end

  # GRANT the database user specified in the current <tt>database_environment</tt>
  # permisson to access the database with the supplied password
  def mysql_user
    grant =<<EOF
GRANT ALL PRIVILEGES 
ON #{database_environment[:database]}.*
TO #{database_environment[:username]}@localhost
IDENTIFIED BY \\"#{database_environment[:password]}\\";
FLUSH PRIVILEGES;
EOF

    exec "mysql_user",
      :command => mysql_query(grant),
      :unless  => "mysqlshow -u#{database_environment[:username]} -p#{database_environment[:password]} #{database_environment[:database]}",
      :require => exec('mysql_database'),
      :before => exec('rake tasks')
  end

  # Create the database from the current <tt>database_environment</tt>
  def mysql_database
    exec "mysql_database",
      :command => mysql_query("create database #{database_environment[:database]};"),
      :unless => mysql_query("show create database #{database_environment[:database]};"),
      :require => service('mysql'),
      :notify => exec('rails_bootstrap')
  end

  # Noop <tt>/etc/mysql/debian-start</tt>, which does some nasty table scans on
  # MySQL start.
  def mysql_fixup_debian_start
    file '/etc/mysql/debian-start',
      :ensure => :present,
      :content => "#!/bin/bash\nexit 0",
      :mode => '755',
      :owner => 'root',
      :require => package('mysql-server')
  end

private

  # Internal helper to shell out and run a query. Doesn't select a database.
  def mysql_query(sql)
    "su -c \'/usr/bin/mysql -u root -e \"#{sql}\"\'"
  end

  def mysql_version
    ubuntu_lucid? ? 5.1 : 5
  end

  def mysql_gem_name
    # Assume the gem name is the same as the adapter name
    database_environment[:adapter]
  end
end

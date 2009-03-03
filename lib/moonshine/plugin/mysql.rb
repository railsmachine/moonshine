module Moonshine::Plugin::Mysql

  def mysql_server
    package 'mysql-server', :ensure => :installed
    service 'mysql', :ensure => :running, :require => [
      package('mysql-server'),
      package('mysql')
    ]
  end

  def mysql_gem
    package "libmysqlclient15-dev", :ensure => :installed
    package "mysql", :ensure => :installed, :provider => :gem, :require => package("libmysqlclient15-dev")
  end

  def mysql_user
    grant =<<EOF
GRANT ALL PRIVILEGES 
ON #{mysql_config_from_environment[:database]}.*
TO #{mysql_config_from_environment[:username]}@localhost 
IDENTIFIED BY '#{mysql_config_from_environment[:password]}';
FLUSH PRIVILEGES;
EOF

    exec "mysql_user",
      :command => mysql_query(grant),
      :unless => mysql_query("show grants for #{mysql_config_from_environment[:username]}@localhost;"),
      :require => [
        exec('mysql_database'),
        exec('rake environment')
      ],
      :notify => exec('rails_bootstrap')
  end

  def mysql_database
    exec "mysql_database",
      :command => mysql_query("create database #{mysql_config_from_environment[:database]};"),
      :unless => mysql_query("show create database #{mysql_config_from_environment[:database]};"),
      :require => service('mysql')
  end

  def mysql_fixup_debian_start
    file '/etc/mysql/debian-start',
      :ensure => :present,
      :content => "#!/bin/bash\nexit 0",
      :mode => '755',
      :owner => 'root'
  end

private

  def mysql_query(sql)
    "/usr/bin/mysql -u root -p -e \"#{sql}\""
  end

  def mysql_config_from_environment
    @db_config ||= configuration['database'][(ENV['RAILS_ENV'] || 'production')]
  end
end

include Moonshine::Plugin::Mysql
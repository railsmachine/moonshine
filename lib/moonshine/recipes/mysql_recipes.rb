module MySQLRecipes

  def mysql_server
    package "mysql-server", :ensure => :installed
    service "mysql", :require => package("mysql-server")
  end

  def mysql_gem
    package "libmysqlclient15-dev", :ensure => :installed
    package "mysql", :ensure => :installed, :provider => :gem, :require => package("libmysqlclient15-dev")
  end

  def mysql_user
    sql =<<EOF
GRANT ALL PRIVILEGES 
ON #{mysql_config_from_environment[:database]}.*
TO #{mysql_config_from_environment[:username]}@localhost 
IDENTIFIED BY '#{mysql_config_from_environment[:password]}';
EOF
    # ok, this could compare the shown grants for the user to what it expects.
    exec "create_user", { :command => "/usr/bin/mysql -u root -e \"#{sql}\"",
                             :unless => "mysql -u root -p -e 'show grants for #{mysql_config_from_environment[:username]}@localhost;'",
                             :require => [exec("create_database")]}
  end

  def mysql_database
    exec "create_database", { :command => "/usr/bin/mysql -u root -e 'create database #{mysql_config_from_environment[:database]};'",
                             :unless => "mysql -u root -p -e 'show create database #{mysql_config_from_environment[:database]};'",
                             :require => [package("mysql-server")]}
  end

  def mysql_config_from_environment
    @db_config ||= configuration['database'][(ENV['RAILS_ENV'] || 'production')]
  end
end
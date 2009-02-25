module Moonshine::Plugin::Mysql

  def mysql_load_schema
    rake('db:schema:load', {
      :require => [
        exec('mysql_user'),
        exec('rails_gems')
      ],
      :notify => exec('rake db:bootstrap'),
      :unless => mysql_query("select * from #{mysql_config_from_environment[:database]}.schema_migrations;")
    })
  end

  def mysql_bootstrap
    rake('db:bootstrap', {
     :require => exec('rake db:schema:load'),
     :onlyif => 'test -d db/bootstrap',
     :refreshonly => true,
     :environment => [ "RAILS_ENV=production" ]
    })
  end

  def mysql_migrations
    rake 'db:migrate', :require => exec('rake db:schema:load')
  end

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
    # ok, this could compare the shown grants for the user to what it expects.
    exec "mysql_user", { :command => mysql_query(grant),
                             :unless => mysql_query("show grants for #{mysql_config_from_environment[:username]}@localhost;"),
                             :require => [exec('mysql_database')] }
  end

  def mysql_database
    exec "mysql_database", { :command => mysql_query("create database #{mysql_config_from_environment[:database]};"),
                             :unless => mysql_query("show create database #{mysql_config_from_environment[:database]};"),
                             :require => [service('mysql')] }
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
recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_load_schema, :mysql_bootstrap, :mysql_migrations
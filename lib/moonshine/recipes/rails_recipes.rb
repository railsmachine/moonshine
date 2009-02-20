module RailsRecipes
  def bootstrap_database
    exec "boostrap_database", { :command => 'rake db:schema:load',
                             :cwd => self.class.working_directory,
                             :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}",
                             :unless => "mysql -u root -p #{mysql_config_from_environment[:database]} -e 'select * from schema_migrations;'",
                             :require => [
                                package('mysql'),
                                package("mysql-server"),
                                exec('create_user')
                               ]}
  end

  def migrations
    exec "migrations", { :command => 'rake db:migrate',
                             :cwd => self.class.working_directory,
                             :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}",
                             :require => [
                               package("mysql"),
                               package("mysql-server"),
                               exec('create_user'),
                               exec('bootstrap_database')
                              ]}
  end
end
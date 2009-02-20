module RailsRecipes
  def bootstrap_database
    exec "boostrap_database", { :command => 'rake db:schema:load',
                             :cwd => self.class.working_directory,
                             :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}",
                             :refreshonly => true}
  end

  def migrations
    exec "migrations", { :command => 'rake db:migrate',
                             :cwd => self.class.working_directory,
                             :environment => "RAILS_ENV=#{ENV['RAILS_ENV']}"}
  end
end
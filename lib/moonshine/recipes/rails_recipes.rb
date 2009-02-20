module RailsRecipes
  def bootstrap_database
    exec "boostrap_database", { :command => 'rake db:schema:load',
                             :cwd => working_directory,
                             :environment => "RAILS_ENV=#{fetch(:rails_env, 'production')}",
                             :refreshonly => true}
  end

  def migrations
    exec "migrations", { :command => 'rake db:migrate',
                             :cwd => working_directory,
                             :environment => "RAILS_ENV=#{fetch(:rails_env, 'production')}"}
  end
end
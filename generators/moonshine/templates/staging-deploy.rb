set :rails_env, :staging
server '<%= staging_server %>', :app, :web, :db, :primary => true

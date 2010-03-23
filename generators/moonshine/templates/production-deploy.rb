set :rails_env, :production
server '<%= server %>', :app, :web, :db, :primary => true

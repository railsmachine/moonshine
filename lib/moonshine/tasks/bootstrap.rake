namespace :moonshine do

  namespace :db do
    desc "Bootstrap the database with fixtures from db/boostrap."
    task :bootstrap => :environment do
      require 'active_record/fixtures'
      ActiveRecord::Base.establish_connection(Rails.env)
      fixtures_dir = File.join(Rails.root, 'db/bootstrap/')
      Dir.glob(File.join(fixtures_dir, '*.{yml,csv}')).each do |fixture_file|
        Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
      end
    end

    desc "Create fixtures in db/bootstrap. Specify tables with FIXTURES=x,y otherwise all will be created."
    task :dump => :environment do
      sql = "SELECT * FROM %s"
      skip_tables = [ "schema_info", "sessions", "schema_migrations" ]
      ActiveRecord::Base.establish_connection
      tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : ActiveRecord::Base.connection.tables - skip_tables

      tables.each do |table_name|
        i = "0000"
        File.open("#{RAILS_ROOT}/db/bootstrap/#{table_name}.yml", 'w') do |file|
          data = ActiveRecord::Base.connection.select_all(sql % table_name)
          file.write data.inject({}) { |hsh, record|
            hsh["#{table_name}_#{i.succ!}"] = record
            hsh
          }.to_yaml
        end
      end
    end
  end

  namespace :app do
    desc "Overwrite this task in your app if you have any bootstrap tasks that need to be run"
    task :bootstrap do
      #
    end
  end

  desc <<-DOC
  Attempt to bootstrap this application. In order, we run:

    rake db:schema:load (if db/schema.rb exists)
    rake db:migrate (if db/migrate exists)
    rake moonshine:db:bootstrap (if db/bootstrap/ exists)
    rake moonshine:app:bootstrap

  All of this assumes one things. That your application can run 'rake
  environment' with an empty database. Please ensure your application can do
  so!
  DOC
  task :bootstrap do
    Rake::Task["db:schema:load"].invoke if File.exist?("db/schema.rb")
    Rake::Task["environment"].invoke
    Rake::Task["db:migrate"].invoke if File.exist?("db/migrate")
    Rake::Task["moonshine:db:bootstrap"].invoke if File.exist?("db/bootstrap")
    Rake::Task["moonshine:app:bootstrap"].invoke
  end
end
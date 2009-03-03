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
    Rake::Task["db:schema:load"] if File.exist?("#{Dir.pwd}/db/schema.rb")
    Rake::Task["environment"]
    Rake::Task["db:migrate"] if File.exist?("#{Dir.pwd}/db/migrate")
    Rake::Task["moonshine:db:bootstrap"] if File.exist?("#{Dir.pwd}/db/bootstrap")
    Rake::Task["moonshine:app:bootstrap"]
  end
end
namespace :db do
  namespace :fixtures do
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
end
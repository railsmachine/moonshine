class Moonshine::Manifest::Rails < Moonshine::Manifest
  plugin File.join(File.dirname(__FILE__), 'rails', 'passenger.rb')
  plugin File.join(File.dirname(__FILE__), 'rails', 'mysql.rb')
  plugin File.join(File.dirname(__FILE__), 'rails', 'sqlite3.rb')
  plugin File.join(File.dirname(__FILE__), 'rails', 'apache.rb')
  plugin File.join(File.dirname(__FILE__), 'rails', 'rails.rb')
  plugin File.join(File.dirname(__FILE__), 'rails', 'os.rb')
end

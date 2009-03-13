module Moonshine::Manifest::Rails::Sqlite3

  # Install the sqlite3 gem and it's dependencies
  def sqlite3
    gem 'sqlite3-ruby', :before => exec('rails_gems')
  end

end

module Moonshine::Plugin::Sqlite3

  def sqlite3
    package 'sqlite3', :ensure => :installed
    package 'libsqlite3-dev', :ensure => :installed
    package 'sqlite3-ruby',
      :ensure => :installed,
      :provider => :gem,
      :require => [
        package('sqlite3'),
        package('libsqlite3-dev')
      ],
      :before => exec('rails_gems')
  end

end

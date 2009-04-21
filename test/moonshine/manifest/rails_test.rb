require File.dirname(__FILE__) + '/../../test_helper.rb'

#mock out the gem source index to fake like passenger is installed, but
#nothing else
module Gem  #:nodoc:
  class SourceIndex  #:nodoc:
    alias_method :orig_search, :search
    def search(gem_pattern, platform_only = false)
      if gem_pattern.name.to_s =~ /passenger/
        orig_search(gem_pattern, platform_only)
      else
        []
      end
    end
  end
end

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase

  def setup
    @manifest = Moonshine::Manifest::Rails.new
  end

  def test_default_stack
    @manifest.expects(:database_environment).at_least_once.returns({:adapter => 'mysql' })
    @manifest.default_stack
    assert @manifest.recipes.map(&:first).include?(:apache_server), 'apache_server'
    [:passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site].each do |passenger_stack|
      assert @manifest.recipes.map(&:first).include?(passenger_stack), passenger_stack.to_s
    end
    [:mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start].each do |mysql_stack|
      assert @manifest.recipes.map(&:first).include?(mysql_stack), mysql_stack.to_s
    end
    [:rails_rake_environment, :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations, :rails_logrotate].each do |rails_stack|
      assert @manifest.recipes.map(&:first).include?(rails_stack), rails_stack.to_s
    end
    [:ntp, :time_zone, :postfix, :cron_packages, :motd, :security_updates].each do |os_stack|
      assert @manifest.recipes.map(&:first).include?(os_stack), os_stack.to_s
    end
  end
  
  def test_default_stack_with_postgresql
    @manifest.expects(:database_environment).at_least_once.returns({:adapter => 'postgresql' })
    @manifest.default_stack
    [:postgresql_server, :postgresql_gem, :postgresql_user, :postgresql_database].each do |pgsql_stack|
      assert @manifest.recipes.map(&:first).include?(pgsql_stack), pgsql_stack.to_s
    end
  end

  def test_default_stack_with_sqlite
    @manifest.expects(:database_environment).at_least_once.returns({:adapter => 'sqlite' })
    @manifest.default_stack
    assert @manifest.recipes.map(&:first).include?(:sqlite3), 'sqlite3'
  end

  def test_automatic_security_updates
    @manifest.configure(:unattended_upgrade => { :package_blacklist => ['foo', 'bar', 'widget']})
    @manifest.configure(:user => 'rails')
    @manifest.security_updates
    assert_not_nil @manifest.packages["unattended-upgrades"]
    assert_not_nil @manifest.files["/etc/apt/apt.conf.d/10periodic"]
    assert_not_nil @manifest.files["/etc/apt/apt.conf.d/50unattended-upgrades"]
    assert_match /APT::Periodic::Unattended-Upgrade "1"/, @manifest.files["/etc/apt/apt.conf.d/10periodic"].params[:content].value
    assert_match /Unattended-Upgrade::Mail "rails@localhost";/, @manifest.files["/etc/apt/apt.conf.d/50unattended-upgrades"].params[:content].value
    assert_match /"foo";/, @manifest.files["/etc/apt/apt.conf.d/50unattended-upgrades"].params[:content].value
  end

  def test_is_executable
    assert @manifest.executable?
  end

  def test_sets_up_gem_sources
    @manifest.rails_gems
    assert_match /gems.github.com/, @manifest.files["/etc/gemrc"].content
  end

  def test_loads_gems_from_config_hash
    @manifest.configure(:gems => [ { :name => 'jnewland-pulse', :source => 'http://gems.github.com/' } ])
    @manifest.rails_gems
    assert_not_nil Moonshine::Manifest::Rails.configuration[:gems]
    Moonshine::Manifest::Rails.configuration[:gems].each do |gem|
      assert_not_nil gem_resource = @manifest.packages[gem[:name]]
      assert_equal :gem, gem_resource.provider
    end
    assert_nil @manifest.packages['jnewland-pulse'].source
  end

  def test_magically_loads_gem_dependencies
    @manifest.configure(:gems => [
      { :name => 'webrat' },
      { :name => 'thoughtbot-paperclip', :source => 'http://gems.github.com/' }
    ])
    @manifest.rails_gems
    assert_not_nil @manifest.packages['webrat']
    assert_not_nil @manifest.packages['thoughtbot-paperclip']
    assert_not_nil @manifest.packages['libxml2-dev']
    assert_not_nil @manifest.packages['imagemagick']
  end

  def test_creates_directories
    config = {
      :application => 'foo',
      :user => 'foo',
      :deploy_to => '/srv/foo'
    }
    @manifest.configure(config)
    @manifest.rails_directories
    assert_not_nil shared_dir = @manifest.files["/srv/foo/shared"]
    assert_equal :directory, shared_dir.ensure
    assert_equal 'foo', shared_dir.owner
    assert_equal 'foo', shared_dir.group
  end

  def test_installs_apache
    @manifest.apache_server
    assert_not_nil apache = @manifest.services["apache2"]
    assert_equal @manifest.package('apache2-mpm-worker').to_s, apache.require.to_s
  end

  def test_enables_mod_ssl_if_ssl
    @manifest.configure(:ssl => {
      :certificate_file => 'cert_file',
      :certificate_key_file => 'cert_key_file',
      :certificate_chain_file => 'cert_chain_file'
    })
    @manifest.apache_server
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/sbin/a2enmod ssl' }
  end

  def test_enables_mod_rewrite
    @manifest.apache_server
    assert_not_nil apache = @manifest.execs["a2enmod rewrite"]
  end

  def test_enables_mod_status
    @manifest.apache_server
    assert_not_nil apache = @manifest.execs["a2enmod status"]
    assert_match /127.0.0.1/, @manifest.files["/etc/apache2/mods-available/status.conf"].content
  end

  def test_installs_passenger_gem
    @manifest.passenger_configure_gem_path
    @manifest.passenger_gem
    assert_not_nil @manifest.packages["passenger"]
  end

  def test_installs_passenger_module
    @manifest.passenger_configure_gem_path
    @manifest.passenger_apache_module
    assert_not_nil @manifest.packages['apache2-threaded-dev']
    assert_not_nil @manifest.files['/etc/apache2/mods-available/passenger.load']
    assert_not_nil @manifest.files['/etc/apache2/mods-available/passenger.conf']
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/sbin/a2enmod passenger' }
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/bin/ruby -S rake clean apache2' }
  end

  def test_configures_passenger_vhost
    @manifest.passenger_configure_gem_path
    @manifest.passenger_site
    assert_not_nil @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"]
    assert_match /RailsAllowModRewrite On/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/sbin/a2dissite 000-default' }
    assert_not_nil @manifest.execs.find { |n, r| r.command == "/usr/sbin/a2ensite #{@manifest.configuration[:application]}" }
  end

  def test_passenger_vhost_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:passenger => { :rails_base_uri => '/test' })
    @manifest.passenger_site
    assert_match /RailsBaseURI \/test/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
  end

  def test_ssl_vhost_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:ssl => {
      :certificate_file => 'cert_file',
      :certificate_key_file => 'cert_key_file',
      :certificate_chain_file => 'cert_chain_file'
    })
    @manifest.passenger_site
    assert_match /SSLEngine on/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_match /https/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
  end
  
  def test_htpasswd_generation
    @manifest.passenger_configure_gem_path
    @manifest.configure(:apache => {
      :users => {
        :jimbo  => 'motorcycle',
        :joebob => 'jimbo'
      }
    })
    @manifest.apache_server
    
    assert_not_nil @manifest.execs.find { |n, r| r.command == 'htpasswd -b /srv/foo/shared/config/htpasswd jimbo motorcycle' }
    assert_not_nil @manifest.execs.find { |n, r| r.command == 'htpasswd -b /srv/foo/shared/config/htpasswd joebob jimbo' }
    assert_not_nil @manifest.files["#{@manifest.configuration[:deploy_to]}/shared/config/htpasswd"]
  end

  def test_vhost_basic_auth_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:apache => {
      :users => {
        :jimbo  => 'motorcycle',
        :joebob => 'jimbo'
      }
    })
    @manifest.passenger_site

    assert_match /<Location \/ >/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_match /authuserfile #{@manifest.configuration[:deploy_to]}\/shared\/config\/htpasswd/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_match /require valid-user/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
  end
 
  def test_vhost_allow_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:apache => {
      :users => {},
      :deny  => {},
      :allow => ['192.168.1','env=safari_user']
    })
    @manifest.passenger_site
    vhost = @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_match /<Location \/ >/, vhost
    assert_match /allow from 192.168.1/, vhost
    assert_match /allow from env=safari_user/, vhost
  end

  def test_vhost_deny_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:apache => {
      :users => {},
      :allow => {},
      :deny => ['192.168.1','env=safari_user']
    })
    @manifest.passenger_site
    
    assert_match /<Location \/ >/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
    assert_match /deny from 192.168.1/, @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
  end

  def test_installs_postfix
    @manifest.postfix
    assert_not_nil @manifest.packages["postfix"]
  end

  def test_installs_ntp
    @manifest.ntp
    assert_not_nil @manifest.services["ntp"]
    assert_not_nil @manifest.packages["ntp"]
  end

  def test_installs_cron
    @manifest.cron_packages
    assert_not_nil @manifest.services["cron"]
    assert_not_nil @manifest.packages["cron"]
  end

  def test_sets_default_time_zone
    @manifest.time_zone
    assert_not_nil @manifest.files["/etc/timezone"]
    assert_not_nil @manifest.packages["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.files["/etc/localtime"].ensure
    assert_equal "UTC\n", @manifest.files["/etc/timezone"].content
  end

  def test_sets_default_time_zone
    @manifest.configure(:time_zone => nil)
    @manifest.time_zone
    assert_not_nil @manifest.files["/etc/timezone"]
    assert_equal "UTC\n", @manifest.files["/etc/timezone"].content
    assert_not_nil @manifest.files["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.files["/etc/localtime"].ensure
  end

  def test_sets_configured_time_zone
    @manifest.configure(:time_zone => 'America/New_York')
    @manifest.time_zone
    assert_not_nil @manifest.files["/etc/timezone"]
    assert_equal "America/New_York\n", @manifest.files["/etc/timezone"].content
    assert_not_nil @manifest.files["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/America/New_York', @manifest.files["/etc/localtime"].ensure
  end

  def test_logroate_helper_generates_config
    @manifest.send(:logrotate, '/srv/theapp/shared/logs/*.log', {:options => %w(daily missingok compress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})
    @manifest.send(:logrotate, '/srv/otherapp/shared/logs/*.log', {:options => %w(daily missingok nocompress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})
    assert_not_nil @manifest.packages["logrotate"]
    assert_match /compress/, @manifest.files["/etc/logrotate.d/srvtheappsharedlogslog.conf"].content
    assert_match /nocompress/, @manifest.files["/etc/logrotate.d/srvotherappsharedlogslog.conf"].content
  end

  def test_postgresql_server
    @manifest.postgresql_server
    assert_not_nil @manifest.services["postgresql-8.3"]
    assert_not_nil @manifest.packages["postgresql-client"]
    assert_not_nil @manifest.packages["postgresql-contrib"]
    assert_not_nil @manifest.files["/etc/postgresql/8.3/main/pg_hba.conf"]
    assert_not_nil @manifest.files["/etc/postgresql/8.3/main/postgresql.conf"]
  end

  def test_postgresql_gem
    @manifest.postgresql_gem
    assert_not_nil @manifest.packages["postgres"]
    assert_not_nil @manifest.packages["pg"]
    assert_not_nil @manifest.packages["postgresql-client"]
    assert_not_nil @manifest.packages["postgresql-contrib"]
    assert_not_nil @manifest.packages["libpq-dev"]
  end

  def test_postgresql_database_and_user
    @manifest.expects(:database_environment).at_least_once.returns({
      :username => 'pg_username',
      :database => 'pg_database',
      :password => 'pg_password'
    })
    @manifest.postgresql_user
    @manifest.postgresql_database
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/bin/psql -c "CREATE USER pg_username WITH PASSWORD \'pg_password\'"' }
    assert_not_nil @manifest.execs.find { |n, r| r.command == '/usr/bin/createdb -O pg_username pg_database' }
  end

end
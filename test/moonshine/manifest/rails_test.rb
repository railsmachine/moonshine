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


  def test_is_executable
    assert @manifest.executable?
  end

  def test_sets_up_gem_sources
    @manifest.rails_gems
    assert_match /gems.github.com/, @manifest.puppet_resources[Puppet::Type::File]["/etc/gemrc"].params[:content].value
  end

  def test_loads_gems_from_config_hash
    @manifest.configure(:gems => [ { :name => 'jnewland-pulse', :source => 'http://gems.github.com/' } ])
    @manifest.rails_gems
    assert_not_nil Moonshine::Manifest::Rails.configuration[:gems]
    Moonshine::Manifest::Rails.configuration[:gems].each do |gem|
      assert_not_nil gem_resource = @manifest.puppet_resources[Puppet::Type::Package][gem[:name]]
      assert_equal :gem, gem_resource.params[:provider].value
    end
    assert_nil @manifest.puppet_resources[Puppet::Type::Package]['jnewland-pulse'].params[:source]
  end

  def test_magically_loads_gem_dependencies
    @manifest.configure(:gems => [
      { :name => 'webrat' },
      { :name => 'thoughtbot-paperclip', :source => 'http://gems.github.com/' }
    ])
    @manifest.rails_gems
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['webrat']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['thoughtbot-paperclip']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['libxml2-dev']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['imagemagick']
  end

  def test_creates_directories
    config = {
      :application => 'foo',
      :user => 'foo',
      :deploy_to => '/srv/foo'
    }
    @manifest.configure(config)
    @manifest.rails_directories
    assert_not_nil shared_dir = @manifest.puppet_resources[Puppet::Type::File]["/srv/foo/shared"]
    assert_equal :directory, shared_dir.params[:ensure].value
    assert_equal 'foo', shared_dir.params[:owner].value
    assert_equal 'foo', shared_dir.params[:group].value
  end

  def test_installs_apache
    @manifest.apache_server
    assert_not_nil apache = @manifest.puppet_resources[Puppet::Type::Service]["apache2"]
    assert_equal @manifest.package('apache2-mpm-worker').to_s, apache.params[:require].value.to_s
  end

  def test_enables_mod_ssl_if_ssl
    @manifest.configure(:ssl => {
      :certificate_file => 'cert_file',
      :certificate_key_file => 'cert_key_file',
      :certificate_chain_file => 'cert_chain_file'
    })
    @manifest.apache_server
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/sbin/a2enmod ssl' }
  end

  def test_enables_mod_rewrite
    @manifest.apache_server
    assert_not_nil apache = @manifest.puppet_resources[Puppet::Type::Exec]["a2enmod rewrite"]
  end

  def test_enables_mod_status
    @manifest.apache_server
    assert_not_nil apache = @manifest.puppet_resources[Puppet::Type::Exec]["a2enmod status"]
    assert_match /127.0.0.1/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/mods-available/status.conf"].params[:content].value
  end

  def test_installs_passenger_gem
    @manifest.passenger_configure_gem_path
    @manifest.passenger_gem
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["passenger"]
  end

  def test_installs_passenger_module
    @manifest.passenger_configure_gem_path
    @manifest.passenger_apache_module
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['apache2-threaded-dev']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]['/etc/apache2/mods-available/passenger.load']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]['/etc/apache2/mods-available/passenger.conf']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/sbin/a2enmod passenger' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/bin/ruby -S rake clean apache2' }
  end

  def test_configures_passenger_vhost
    @manifest.passenger_configure_gem_path
    @manifest.passenger_site
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"]
    assert_match /RailsAllowModRewrite On/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/sbin/a2dissite 000-default' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == "/usr/sbin/a2ensite #{@manifest.configuration[:application]}" }
  end

  def test_passenger_vhost_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:passenger => { :rails_base_uri => '/test' })
    @manifest.passenger_site
    assert_match /RailsBaseURI \/test/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
  end

  def test_ssl_vhost_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:ssl => {
      :certificate_file => 'cert_file',
      :certificate_key_file => 'cert_key_file',
      :certificate_chain_file => 'cert_chain_file'
    })
    @manifest.passenger_site
    assert_match /SSLEngine on/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_match /https/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
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
    
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == 'htpasswd -b /srv/foo/current/config/htpasswd jimbo motorcycle' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == 'htpasswd -b /srv/foo/current/config/htpasswd joebob jimbo' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["#{@manifest.configuration[:deploy_to]}/current/config/htpasswd"]
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

    assert_match /<Location \/ >/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_match /authuserfile #{@manifest.configuration[:deploy_to]}\/current\/config\/htpasswd/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_match /require valid-user/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
  end
 
  def test_vhost_allow_configuration
    @manifest.passenger_configure_gem_path
    @manifest.configure(:apache => {
      :users => {},
      :deny  => {},
      :allow => ['192.168.1','env=safari_user']
    })
    @manifest.passenger_site
    vhost = @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
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
    
    assert_match /<Location \/ >/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_match /deny from 192.168.1/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
  end

  def test_installs_postfix
    @manifest.postfix
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postfix"]
  end

  def test_installs_ntp
    @manifest.ntp
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Service]["ntp"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["ntp"]
  end

  def test_installs_cron
    @manifest.cron_packages
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Service]["cron"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["cron"]
  end

  def test_sets_default_time_zone
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
    assert_equal "UTC\n", @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"].params[:content].value
  end

  def test_sets_default_time_zone
    @manifest.configure(:time_zone => nil)
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_equal "UTC\n", @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
  end

  def test_sets_configured_time_zone
    @manifest.configure(:time_zone => 'America/New_York')
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_equal "America/New_York\n", @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/America/New_York', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
  end

  def test_logroate_helper_generates_config
    @manifest.send(:logrotate, '/srv/theapp/shared/logs/*.log', {:options => %w(daily missingok compress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})
    @manifest.send(:logrotate, '/srv/otherapp/shared/logs/*.log', {:options => %w(daily missingok nocompress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["logrotate"]
    assert_match /compress/, @manifest.puppet_resources[Puppet::Type::File]["/etc/logrotate.d/srvtheappsharedlogslog.conf"].params[:content].value
    assert_match /nocompress/, @manifest.puppet_resources[Puppet::Type::File]["/etc/logrotate.d/srvotherappsharedlogslog.conf"].params[:content].value
  end

  def test_postgresql_server
    @manifest.postgresql_server
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Service]["postgresql-8.3"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postgresql-client"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postgresql-contrib"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/postgresql/8.3/main/pg_hba.conf"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/postgresql/8.3/main/postgresql.conf"]
  end

  def test_postgresql_gem
    @manifest.postgresql_gem
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postgres"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["pg"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postgresql-client"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postgresql-contrib"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["libpq-dev"]
  end

  def test_postgresql_database_and_user
    @manifest.expects(:database_environment).at_least_once.returns({
      :username => 'pg_username',
      :database => 'pg_database',
      :password => 'pg_password'
    })
    @manifest.postgresql_user
    @manifest.postgresql_database
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/bin/psql -c "CREATE USER pg_username WITH PASSWORD \'pg_password\'"' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/bin/createdb -O pg_username pg_database' }
  end

end
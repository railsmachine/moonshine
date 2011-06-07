require 'spec_helper'

# mock out the gem source index to fake like passenger is installed, but
# nothing else
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

describe Moonshine::Manifest::Rails do

  before do
    @manifest = subject
  end

  it { should be_executable }

  context "default_stack" do
    it "supports mysql" do
      @manifest.should_receive(:database_environment).at_least(:once).and_return({:adapter => 'mysql'})

      @manifest.default_stack

      @manifest.should use_recipe(:apache_server)
      @manifest.should use_recipe(:passenger_gem)
      @manifest.should use_recipe(:passenger_configure_gem_path)
      @manifest.should use_recipe(:passenger_apache_module)
      @manifest.should use_recipe(:passenger_site)

      @manifest.should use_recipe(:mysql_server)
      @manifest.should use_recipe(:mysql_gem)
      @manifest.should use_recipe(:mysql_database)
      @manifest.should use_recipe(:mysql_user)
      @manifest.should use_recipe(:mysql_fixup_debian_start)

      @manifest.should use_recipe(:rails_rake_environment)
      @manifest.should use_recipe(:rails_gems)
      @manifest.should use_recipe(:rails_directories)
      @manifest.should use_recipe(:rails_bootstrap)
      @manifest.should use_recipe(:rails_migrations)
      @manifest.should use_recipe(:rails_logrotate)

      @manifest.should use_recipe(:ntp)
      @manifest.should use_recipe(:time_zone)
      @manifest.should use_recipe(:postfix)
      @manifest.should use_recipe(:cron_packages)
      @manifest.should use_recipe(:motd)
      @manifest.should use_recipe(:security_updates)

    end

    it "supports postgresl" do 
      @manifest.should_receive(:database_environment).at_least(:once).and_return({:adapter => 'postgresql' })

      @manifest.default_stack

      @manifest.should use_recipe(:postgresql_server)
      @manifest.should use_recipe(:postgresql_gem)
      @manifest.should use_recipe(:postgresql_user)
      @manifest.should use_recipe(:postgresql_database)
    end

    it "supports sqlite3" do
      @manifest.should_receive(:database_environment).at_least(:once).and_return({:adapter => 'sqlite' })

      @manifest.default_stack

      @manifest.should use_recipe(:sqlite3)
    end
  end

  describe "#rails_gems" do
    it "configures gem options" do
      @manifest.rails_gems

      @manifest.should have_file('/etc/gemrc').with_content(
        /--no-rdoc/
      )
    end
    
    it "configures gem sources" do
      @manifest.rails_gems

      @manifest.should have_file('/etc/gemrc').with_content(
        /rubygems.org/
      )
    end
    
    it "should be valid gemrc syntax (i.e. no leading symbols)" do
      @manifest.rails_gems

      @manifest.should have_file('/etc/gemrc').with_content(
        /^gem:/
      )
    end

    it "loads gems from config" do
      @manifest.configure(:gems => [ { :name => 'jnewland-pulse', :source => 'http://rubygems.org' } ])
      @manifest.rails_gems

      Moonshine::Manifest::Rails.configuration[:gems].should_not be_nil

      Moonshine::Manifest::Rails.configuration[:gems].each do |gem|
        @manifest.should have_package(gem[:name]).from_provider(:gem)
      end
#      @manifest.packages['jnewland-pulse'].source.should be_nil
    end

    it "magically loads gem dependencies" do
      @manifest.configure(:gems => [
        { :name => 'webrat' },
        { :name => 'paperclip' }
      ])

      @manifest.rails_gems

      @manifest.should have_package('webrat')
      @manifest.should have_package('paperclip')
      @manifest.should have_package('libxml2-dev')
    end

  end

  it "creates directories" do
    config = {
      :application => 'foo',
      :user => 'foo',
      :deploy_to => '/srv/foo'
    }
    @manifest.configure(config)

    @manifest.rails_directories


    shared_dir = @manifest.files["/srv/foo/shared"]
    shared_dir.should_not be_nil
    shared_dir.ensure.should == :directory
    shared_dir.owner.should == 'foo'
    shared_dir.group.should == 'foo'
  end

  describe "passenger support" do

    describe "passenger_site" do
      it "enables passenger vhost, disables default vhost, and configures mod_rewrite" do
        @manifest.passenger_configure_gem_path
        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /RailsAllowModRewrite is deprecated/
        )

        @manifest.should exec_command('/usr/sbin/a2dissite 000-default')
        @manifest.should exec_command("/usr/sbin/a2ensite #{@manifest.configuration[:application]}")
      end

      it "supports configuring RailsBaseURI" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:passenger => { :rails_base_uri => '/test' })

        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /RailsBaseURI \/test/
        )
      end

      it "makes the maintenance.html page return a 503" do
        @manifest.passenger_configure_gem_path

        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /ErrorDocument 503 \/system\/maintenance\.html/
        )
        @manifest.should have_file(vhost_conf_path).with_content(
          /RewriteCond \%\{SCRIPT_FILENAME\} \!maintenance\.html/
        )
        @manifest.should have_file(vhost_conf_path).with_content(
          /RewriteRule \^\.\*\$ - \[R=503,L\]/
        )
      end

      it "supports configuring gzip" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:apache => {
          :gzip => true,
          :gzip_types => ['text/css', 'application/javascript']
        })

        @manifest.passenger_site

        @manifest.should have_file("/etc/apache2/sites-available/#{@manifest.configuration[:application]}").with_content(
          /AddOutputFilterByType DEFLATE text\/css application\/javascript/
        )
      end

      it "sets the X-Request-Start header" do
        @manifest.passenger_configure_gem_path
        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /RequestHeader set X-Request-Start "%t"/
        )
      end

      it "supports configuring FileETag" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:apache => { :file_etag => "MTime Size" })
        
        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /FileETag MTime Size/
        )
      end

      it "supports configuring ssl" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:ssl => {
          :certificate_file => 'cert_file',
          :certificate_key_file => 'cert_key_file',
          :certificate_chain_file => 'cert_chain_file',
          :protocol => 'all -SSLv2',
          :cipher_suite => 'ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM'
        })

        @manifest.passenger_site

        @manifest.should have_file("/etc/apache2/sites-available/#{@manifest.configuration[:application]}").with_content(
          /SSLEngine on/
        )
        @manifest.should have_file("/etc/apache2/sites-available/#{@manifest.configuration[:application]}").with_content(
          /https/
        )
        @manifest.should have_file("/etc/apache2/sites-available/#{@manifest.configuration[:application]}").with_content(
          /SSLProtocol all -SSLv2/
        )
        @manifest.should have_file("/etc/apache2/sites-available/#{@manifest.configuration[:application]}").with_content(
          /ALL:\!aNULL:\!ADH:\!eNULL:\!LOW:\!EXP:RC4\+RSA:\+HIGH:\+MEDIUM/
        )
      end

      it "supports basic auth" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:apache => {
          :users => {
          :jimbo  => 'motorcycle',
          :joebob => 'jimbo'
        }
        })

        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /<Location \/ >/
        )

        @manifest.should have_file(vhost_conf_path).with_content(
          /authuserfile #{@manifest.configuration[:deploy_to]}\/shared\/config\/htpasswd/
        )

        @manifest.should have_file(vhost_conf_path).with_content(
          /require valid-user/
        )
      end

      it "supports allowing access" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:apache => {
          :users => {},
          :deny  => {},
          :allow => ['192.168.1','env=safari_user']
        })

        @manifest.passenger_site

        vhost = @manifest.files["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].content
        vhost.should match(/<Location \/ >/)
        vhost.should match(/allow from 192.168.1/)
        vhost.should match(/allow from env=safari_user/)
      end

      it "supports denying access" do
        @manifest.passenger_configure_gem_path
        @manifest.configure(:apache => {
          :users => {},
          :allow => {},
          :deny => ['192.168.1','env=safari_user']
        })

        @manifest.passenger_site

        vhost_conf_path = "/etc/apache2/sites-available/#{@manifest.configuration[:application]}"
        @manifest.should have_file(vhost_conf_path).with_content(
          /<Location \/ >/
        )

        @manifest.should have_file(vhost_conf_path).with_content(
          /deny from 192.168.1/
        )
      end
    end

  end
  
  describe "apache server" do
    it "generates htpasswd" do
      @manifest.passenger_configure_gem_path
      @manifest.configure(:apache => {
        :users => {
          :jimbo  => 'motorcycle',
          :joebob => 'jimbo'
        }
      })
      @manifest.apache_server
      
      @manifest.should exec_command('htpasswd -b /srv/foo/shared/config/htpasswd jimbo motorcycle')
      @manifest.should exec_command('htpasswd -b /srv/foo/shared/config/htpasswd joebob jimbo')
      @manifest.should have_file("#{@manifest.configuration[:deploy_to]}/shared/config/htpasswd")
    end
  end


  it "supports postfix" do
    @manifest.postfix

    @manifest.should have_package("postfix")
  end

  it "supports ntp" do
    @manifest.ntp

    @manifest.should have_service("ntp")
    @manifest.should have_package("ntp")
  end

  it "supports cron" do
    @manifest.cron_packages

    @manifest.should have_service("cron")
    @manifest.should have_package("cron")
  end

  describe "#time_zone" do
    it "sets default time zone" do
      @manifest.time_zone

      @manifest.should have_file("/etc/timezone").with_content("UTC\n")
      @manifest.should have_file("/etc/localtime").symlinked_to('/usr/share/zoneinfo/UTC')
    end

    it "sets default timezone" do
      @manifest.configure(:time_zone => nil)

      @manifest.time_zone

      @manifest.should have_file("/etc/timezone").with_content("UTC\n")
      @manifest.should have_file("/etc/localtime").symlinked_to('/usr/share/zoneinfo/UTC')
    end

    it "sets configured time zone" do
      @manifest.configure(:time_zone => 'America/New_York')

      @manifest.time_zone

      @manifest.should have_file("/etc/timezone").with_content("America/New_York\n")
      @manifest.should have_file("/etc/localtime").symlinked_to('/usr/share/zoneinfo/America/New_York')
    end
  end

  describe "#log_rotate" do
    it "generates configuration files" do
      @manifest.send(:logrotate, '/srv/theapp/shared/logs/*.log', {:options => %w(daily missingok compress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})
      @manifest.send(:logrotate, '/srv/otherapp/shared/logs/*.log', {:options => %w(daily missingok nocompress delaycompress sharedscripts), :postrotate => 'touch /home/deploy/app/current/tmp/restart.txt'})

      @manifest.should have_package("logrotate")

      @manifest.should have_file("/etc/logrotate.d/srvtheappsharedlogslog.conf").with_content(/compress/)
      @manifest.should have_file("/etc/logrotate.d/srvotherappsharedlogslog.conf").with_content(/nocompress/)
    end

    it "is configurable" do
      @manifest.configure(
        :deploy_to => '/srv/foo',
        :rails_logrotate => {
          :options => %w(foo bar baz),
          :postrotate => 'do something'
        }
      )

      @manifest.send(:rails_logrotate)

      @manifest.should have_package("logrotate")
      @manifest.should have_file("/etc/logrotate.d/srvfoosharedloglog.conf")
      
      logrotate_conf = @manifest.files["/etc/logrotate.d/srvfoosharedloglog.conf"].content

      logrotate_conf.should match(/foo/)
      logrotate_conf.should_not match(/compress/)
      logrotate_conf.should_not match(/restart\.txt/)
    end
  end

  specify "#postgresql_server" do
    @manifest.postgresql_server

    @manifest.should have_service("postgresql-8.3")
    @manifest.should have_package("postgresql-client")
    @manifest.should have_package("postgresql-contrib")
    @manifest.should have_file("/etc/postgresql/8.3/main/pg_hba.conf")
    @manifest.should have_file("/etc/postgresql/8.3/main/postgresql.conf")
  end

  specify "#postgresql_gem" do
    @manifest.postgresql_gem

    @manifest.should have_package("postgres")
    @manifest.should have_package("pg")
    @manifest.should have_package("postgresql-client")
    @manifest.should have_package("postgresql-contrib")
    @manifest.should have_package("libpq-dev")
  end

  specify "#postgresql_database and #postgresql_user" do
    @manifest.should_receive(:database_environment).at_least(:once).and_return({
      :username => 'pg_username',
      :database => 'pg_database',
      :password => 'pg_password'
    })

    @manifest.postgresql_user
    @manifest.postgresql_database

    @manifest.should exec_command('/usr/bin/psql -c "CREATE USER pg_username WITH PASSWORD \'pg_password\'"')
    @manifest.should exec_command('/usr/bin/createdb -O pg_username pg_database')
  end

  describe "#gem" do
    before do
      @manifest.gem 'rmagick'
    end
    it "uses gem provider for package" do
      @manifest.should have_package('rmagick').from_provider('gem')
    end

    it "runs before rails_gem" do
      package = @manifest.packages['rmagick']
      package.before.type.should == 'Exec'
      package.before.title.should == 'rails_gems'
    end

    it "requires /etc/gemrc" do
      package = @manifest.packages['rmagick']

      gemrc = package.require.detect do |require|
        require.title == '/etc/gemrc'
      end

      gemrc.should_not == nil
      gemrc.type.should == 'File'
    end

    it "requires native packages" do
      package = @manifest.packages['rmagick']

      imagemagick = package.require.detect do |require|
        require.title == 'imagemagick'
      end

      imagemagick.should_not == nil
      imagemagick.type.should == 'Package'

      libmagick9_dev = package.require.detect do |require|
        require.title == 'libmagick9-dev'
      end

      libmagick9_dev.should_not == nil
      libmagick9_dev.type.should == 'Package'
    end
  end

  describe "rake" do
    it "installs :installed by default" do
      @manifest.configure(:rake_version => nil)
      @manifest.rails_rake_environment
      @manifest.should have_package('rake').version(:installed)
    end

    it "can be pinned to a specific version" do
      @manifest.configure(:rake_version => '1.2.3')
      @manifest.rails_rake_environment
      @manifest.should have_package('rake').version('1.2.3')
    end
  end

end

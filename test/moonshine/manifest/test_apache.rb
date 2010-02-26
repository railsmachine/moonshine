require 'test_helper'

class Moonshine::Manifest::ApacheTest < Test::Unit::TestCase
  def setup
    @manifest = Moonshine::Manifest::Rails.new
  end

  def test_default_configuration
    @manifest.apache_server

    apache2_conf_content = @manifest.files['/etc/apache2/apache2.conf'].content

    assert_kind_of Hash, @manifest.configuration[:apache]

    assert_equal 'Off', @manifest.configuration[:apache][:keep_alive]
    assert_apache_directive apache2_conf_content, 'KeepAlive', 'Off'

    assert_equal 100, @manifest.configuration[:apache][:max_keep_alive_requests]
    assert_apache_directive apache2_conf_content, 'MaxKeepAliveRequests', 100

    assert_equal 15, @manifest.configuration[:apache][:keep_alive_timeout]
    assert_apache_directive apache2_conf_content, 'KeepAliveTimeout', 15

    assert_equal 150, @manifest.configuration[:apache][:max_clients]
    assert_apache_directive apache2_conf_content, 'MaxClients', 150

    assert_equal 16, @manifest.configuration[:apache][:server_limit]
    assert_apache_directive apache2_conf_content, 'ServerLimit', 16

    assert_equal 300, @manifest.configuration[:apache][:timeout]
    assert_apache_directive apache2_conf_content, 'Timeout', 300
  end

  def test_overridden_configuration_early
    @manifest.configure :apache => {
      :keep_alive => 'On',
      :max_keep_alive_requests => 200,
      :keep_alive_timeout => 30,
      :max_clients => 300,
      :server_limit => 32,
      :timeout => 600
    }
    @manifest.apache_server

    apache2_conf_content = @manifest.files['/etc/apache2/apache2.conf'].content

    assert_equal 600, @manifest.configuration[:apache][:timeout]
    assert_apache_directive apache2_conf_content, 'Timeout', 600

    assert_equal 'On', @manifest.configuration[:apache][:keep_alive]
    assert_apache_directive apache2_conf_content, 'KeepAlive', 'On'

    assert_equal 200, @manifest.configuration[:apache][:max_keep_alive_requests]
    assert_apache_directive apache2_conf_content, 'MaxKeepAliveRequests', 200

    assert_equal 30, @manifest.configuration[:apache][:keep_alive_timeout]
    assert_apache_directive apache2_conf_content, 'KeepAliveTimeout', 30

    in_apache_if_module apache2_conf_content, 'mpm_worker_module' do |mpm_worker_module|
      assert_equal 300, @manifest.configuration[:apache][:max_clients]
      assert_apache_directive mpm_worker_module, 'MaxClients', 300

      assert_equal 32, @manifest.configuration[:apache][:server_limit]
      assert_apache_directive mpm_worker_module, 'ServerLimit', 32
    end

  end

  def test_overridden_configuration_late
    @manifest.apache_server
    @manifest.configure :apache => { :keep_alive => 'On' }

    apache2_conf_content = @manifest.files['/etc/apache2/apache2.conf'].content

    assert_equal 'On', @manifest.configuration[:apache][:keep_alive]
    assert_apache_directive apache2_conf_content, 'KeepAlive', 'On'
  end

  def test_default_keepalive_off
    @manifest.apache_server

    apache2_conf_content = @manifest.files['/etc/apache2/apache2.conf'].content
    assert_apache_directive apache2_conf_content, 'KeepAlive', 'Off'
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
end

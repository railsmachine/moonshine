module Moonshine::Manifest::Rails::Apache
  def self.included(manifest)
    manifest.configure :apache => {
      :keep_alive => 'Off',
      :max_keep_alive_requests => 100,
      :keep_alive_timeout => 15,
      :max_clients => 150,
      :server_limit => 16,
      :timeout => 300,
      :trace_enable => 'On',
      :gzip => false,
      :gzip_types => ['text/html', 'text/plain', 'text/xml', 'text/css', 'application/x-javascript', 'application/javascript']
    }
  end

  # Installs Apache 2.2 and enables mod_rewrite and mod_status. Enables mod_ssl
  # if <tt>configuration[:ssl]</tt> is present
  def apache_server
    package "apache2-mpm-worker", :ensure => :installed
    service "apache2", :require => package("apache2-mpm-worker"), :restart => '/etc/init.d/apache2 restart', :ensure => :running
    a2enmod('rewrite')
    a2enmod('status')
    a2enmod('expires')
    if configuration[:ssl]
      a2enmod('headers')
      a2enmod('ssl')
    end
    if configuration[:apache][:gzip]
      a2enmod('deflate')
    end

    if configuration[:apache][:users]
      htpasswd = configuration[:apache][:htpasswd] || "#{configuration[:deploy_to]}/shared/config/htpasswd"
      
      file htpasswd, :ensure => :file, :owner => configuration[:user], :mode => '644'
      
      configuration[:apache][:users].each do |user,pass|
        exec "htpasswd #{user}",
          :command => "htpasswd -b #{htpasswd} #{user} #{pass}",
          :unless  => "grep '#{user}' #{htpasswd}"
      end
    end

    apache2_conf = template(rails_template_dir.join('apache2.conf.erb'), binding)
    file '/etc/apache2/apache2.conf',
      :ensure => :present,
      :content => apache2_conf,
      :mode => '644',
      :require => package('apache2-mpm-worker'),
      :notify => service('apache2')

    status = <<-STATUS
<IfModule mod_status.c>
ExtendedStatus On
<Location /server-status>
     SetHandler server-status
     order deny,allow
     deny from all
     allow from 127.0.0.1
</Location>
</IfModule>
STATUS



    file '/etc/apache2/mods-available/status.conf',
      :ensure => :present,
      :mode => '644',
      :require => exec('a2enmod status'),
      :content => status,
      :notify => service("apache2")
    file '/etc/logrotate.d/varlogapachelog.conf', :ensure => :absent

  end

private

  # Symlinks a site from <tt>/etc/apache2/sites-enabled/site</tt> to
  #<tt>/etc/apache2/sites-available/site</tt>. Creates
  #<tt>exec("a2ensite #{site}")</tt>.
  def a2ensite(site, options = {})
    exec("a2ensite #{site}", {
        :command => "/usr/sbin/a2ensite #{site}",
        :unless => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  # Removes a symlink from <tt>/etc/apache2/sites-enabled/site</tt> to
  #<tt>/etc/apache2/sites-available/site</tt>. Creates
  #<tt>exec("a2dissite #{site}")</tt>.
  def a2dissite(site, options = {})
    exec("a2dissite #{site}", {
        :command => "/usr/sbin/a2dissite #{site}",
        :onlyif => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  # Symlinks a module from <tt>/etc/apache2/mods-enabled/mod</tt> to
  #<tt>/etc/apache2/mods-available/mod</tt>. Creates
  #<tt>exec("a2enmod #{mod}")</tt>.
  def a2enmod(mod, options = {})
    exec("a2enmod #{mod}", {
        :command => "/usr/sbin/a2enmod #{mod}",
        :unless => "ls /etc/apache2/mods-enabled/#{mod}.load",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  # Removes a symlink from <tt>/etc/apache2/mods-enabled/mod</tt> to
  #<tt>/etc/apache2/mods-available/mod</tt>. Creates
  #<tt>exec("a2dismod #{mod}")</tt>.
  def a2dismod(mod, options = {})
    exec("a2dismod #{mod}", {
        :command => "/usr/sbin/a2enmod #{mod}",
        :onlyif => "ls /etc/apache2/mods-enabled/#{mod}.load",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end
  
end

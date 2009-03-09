module Moonshine::Plugin::Apache

  def apache_server
    package "apache2-mpm-worker", :ensure => :installed
    service "apache2", :require => package("apache2-mpm-worker"), :restart => '/etc/init.d/apache2 restart', :ensure => :running
    a2enmod('rewrite')
    a2enmod('status')
    unless configatron.ssl.nil?
      a2enmod('headers')
      a2enmod('ssl')
    end
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
  end

private

  def a2ensite(site, options = {})
    exec("a2ensite #{site}", {
        :command => "/usr/sbin/a2ensite #{site}",
        :unless => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  def a2dissite(site, options = {})
    exec("a2dissite #{site}", {
        :command => "/usr/sbin/a2dissite #{site}",
        :onlyif => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  def a2enmod(mod, options = {})
    exec("a2enmod #{mod}", {
        :command => "/usr/sbin/a2enmod #{mod}",
        :unless => "ls /etc/apache2/mods-enabled/#{mod}.load",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

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

include Moonshine::Plugin::Apache
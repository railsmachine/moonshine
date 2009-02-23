module Moonshine::Plugin::Apache

  def apache_server
    package "apache2-mpm-worker", :ensure => :installed
    service "apache2", :require => package("apache2-mpm-worker")
  end

end

include Moonshine::Plugin::Apache
recipe :apache_server
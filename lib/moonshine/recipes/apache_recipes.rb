module ApacheRecipes

  def apache_server
    package "apache2-mpm-worker", :ensure => :installed
    service "apache2", :require => package("apache2-mpm-worker"), :subscribe => [file("passenger_conf"), file("passenger_load") ]
  end

end
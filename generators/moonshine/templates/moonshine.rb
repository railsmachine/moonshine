class Moonshine::Manifest::Rails::<%= klass_name %> < Moonshine::Manifest::Rails
  ruby(:debian)
  gems('rails')
  db(:mysql)
  web(:apache2)
  rails(:passenger)
  deploy('/srv/rails')

  #service('memcached', %w(memcache libmemcached))
  #puppet.exec 'foo', :command => "echo 'normal puppet stuff' > /tmp/test"
end
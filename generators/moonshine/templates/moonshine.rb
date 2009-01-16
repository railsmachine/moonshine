class <%= klass_name %> < Moonshine::Manifest::Rails
  #packages(%w(vim curl))

  #service('memcached', %w(memcache libmemcached))

  #puppet.exec 'foo',
  #  :command => "curl -o some_url > /tmp/test"
  #  :require => package(:curl)
end
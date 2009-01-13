class <%= server_name.capitalize %>MoonshineServer < Moonshine::Manifest::Rails
  #the user to run non-privedged tasks as.
  #if this user doesn't exist, one will be created for you.
  user "rails"

  #install packages needed by your rails app
  #packages %w(foo bar baz)

  #services needed by your rails app, and an array of packages they depend on
  #service('memcached', %w(memcached libmemcache0 libmemcache-dev))

  #rubified puppet manifests
  #role :something_else do
  #  exec "foo", :command => "echo 'normal puppet stuff here' > /tmp/test"
  #end
end
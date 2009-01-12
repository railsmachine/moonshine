class <%= server_name.capitalize %>MoonshineServer < Moonshine::Manifest::Rails
  #the user to run non-privedged tasks as.
  #if this user doesn't exist, one will be created for you.
  user "rails"
end
class <%= klass_name %> < Moonshine::Manifest::Rails
  # By default, configuration is automatically loaded from <tt>config/moonshine.yml</tt>
  # If necessary, you may provide a configuration hash directly to this class.
  # Any configuration provided on the class is deep merged with what is in
  # <tt>config/moonshine.yml</tt>. This could be use, for example, to store
  # passwords and/or private keys outside of your SCM, or to query a web
  # service for configuration data.
  # configuration = {
  #   :name     => 'yourappname',
  #   :apache   => {
  #     :server_name => 'yourappname.com'
  #   },
  #   :mysql => {
  #     :password => 'secret'
  #   }
  # }

  # add your gems and other good stuff here
  def application_packages
    # package 'some_awesome_gem', :ensure => :installed, :provider => :gem, :require => package('some_awesome_native_package')
    # package 'some_awesome_native_package', :ensure => :installed
  end
  # Uncomment the following line to declare the 'application_packages' method
  # as a recipe
  # recipe :application_packages
end
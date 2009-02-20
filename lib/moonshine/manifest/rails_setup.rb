class Moonshine::Manifest::RailsSetup < Moonshine::Manifest
  recipe :gems

  # Installs the gem dependencies of the Moonshine::Manifest::Rails
  def gems
    package 'shadow_puppet', :provider => :gem, :version => '0.1.6', :ensure => :installed
    package 'shadow_facter', :provider => :gem, :version => '0.1.2', :ensure => :installed
    package 'capistrano', :provider => :gem, :version => '2.5.4', :ensure => :installed
    package 'rails', :provider => :gem, :ensure => :latest
  end
end
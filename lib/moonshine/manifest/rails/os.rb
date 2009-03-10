module Moonshine::Manifest::Rails::Os
  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
  end

  def postfix
    package 'postfix', :ensure => :latest
  end

  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  def time_zone
    zone = configatron.retrieve('time_zone', 'UTC')
    zone = 'UTC' if zone.nil? || zone.strip == ''
    file "/etc/timezone",
      :content => zone+"\n",
      :ensure => :present
    file "/etc/localtime",
      :ensure => "/usr/share/zoneinfo/#{zone}",
      :notify => service('ntp')
  end

end

include Moonshine::Manifest::Rails::Os
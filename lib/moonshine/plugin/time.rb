module Moonshine::Plugin::Time
  def time_ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  def time_zone
    zone = configuration[:time_zone] || 'UTC'
    file "/etc/timezone",
      :content => zone+"\n",
      :ensure => :present
    file "/etc/localtime",
      :ensure => "/usr/share/zoneinfo/#{zone}",
      :notify => service('ntp')
  end

end

include Moonshine::Plugin::Time
recipe :time_ntp, :time_zone
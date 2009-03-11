module Moonshine::Manifest::Rails::Os
  # Set up cron and enable the service. You can create cron jobs in your
  # manifests like so:
  #
  #   cron :run_me_at_three
  #     :command => "/usr/sbin/something",
  #     :user => root,
  #     :hour => 3
  #
  #   cron 'rake:task',
  #       :command => "cd #{rails_root} && RAILS_ENV=#{ENV['RAILS_ENV']} rake rake:task",
  #       :user => configatron.user,
  #       :minute => 15
  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
  end

  #Overwrites <tt>/etc/motd</tt> to indicate Moonshine Managemnt
  def motd
    package 'figlet', :ensure => :installed
    exec '/etc/motd',
      :command => 'echo "Mooonshine Managed" | figlet | tee /etc/motd',
      :unless => "grep '(_)' /etc/motd",
      :require => package('figlet')
  end

  # Install postfix.
  def postfix
    package 'postfix', :ensure => :latest
  end

  # Install ntp and enables the ntp service.
  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  # Set the system timezone to <tt>configatron.time_zone</tt> or 'UTC' by
  # default.
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
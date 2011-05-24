# **Moonshine::Manifest::Rails::Os** is a manifest for configuring the
# base Ubuntu operating system.

module Moonshine::Manifest::Rails::Os
  #### Cron
  
  # Ensures the cron package is installed and the service is running.
  #
  # Cron jobs can be defined inside any manifest or recipe like so:
  #
  #     cron :run_me_at_three
  #       :command => "/usr/sbin/something",
  #       :user => root,
  #       :hour => 3
  #
  #     cron 'rake:task',
  #       :command => [
  #         "cd #{rails_root}",
  #         "RAILS_ENV=#{ENV['RAILS_ENV']} rake rake:task"
  #       ].join(' && '),
  #       :user => configuration[:user],
  #       :minute => 15

  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
  end

  #### MOTD

  # We provide a default MOTD (message of the day) which has some basic
  # information. You can override this particular recipe or
  # the two file resources it declares in order to customize your own
  # MOTD.

  def motd
    motd_contents ="""-----------------
Moonshine Managed
-----------------

  Application:  #{configuration[:application]}
  Repository:   #{configuration[:repository]}
  Deploy Path:  #{configuration[:deploy_to]}

----------------
  A Reminder
----------------
As the configuration of this server is managed with Moonshine, please refrain
from installing any gems, packages, or dependencies directly on the server.
----------------
"""
    file '/var/run/motd',
      :mode => '644',
      :content => `uname -snrvm`+motd_contents
    file '/etc/motd.tail',
      :mode => '644',
      :content => motd_contents
  end

  #### Hostname
  
  # This recipe is used to configure the hostname on a server via the
  # `/etc/hostname` file. Generally, this requires a restart to take
  # effect. We default back to `Facter.fqdn` (the current hostname) as
  # a default value to avoid any unanticipated changes.
  
  def hostname
    file '/etc/hostname',
      :ensure  => :present,
      :content => (configuration[:hostname] || Facter.fqdn || Facter.hostname || ''),
      :owner   => 'root',
      :group   => 'root',
      :mode    => '644'
  end

  #### Postfix

  # We enable Postfix by default because it provides a sane default
  # and makes sending emails, a common task for many Rails apps,
  # easy to setup.
  #
  # We also allow configuring the hostname used for sending email
  # via the `configuration[:mailname]` variable, which can be set
  # in a recipe/manifest via the `configure(opts)` method or in
  # a Moonshine YML file.

  def postfix
    package 'postfix', :ensure => :latest
    file '/etc/mailname',
      :ensure  => :present,
      :content => (configuration[:mailname] || Facter.fqdn || Facter.hostname || ''),
      :owner   => 'root',
      :group   => 'root',
      :mode    => '644'
  end

  #### NTP

  # We enable NTP by default to ensure that servers always have a sane time.

  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  #### Time Zones

  # Sometimes it's desirable to have a server run in a time besides UTC.
  # The format for time zones looks like so:
  #
  #     America/New_York
  #
  # You can find a complete list of available time zones by running:
  #
  #     $ ls /usr/share/zoneinfo/*

  def time_zone
    zone = configuration[:time_zone] || 'UTC'
    zone = 'UTC' if zone.nil? || zone.strip == ''
    file "/etc/timezone",
      :content => zone+"\n",
      :ensure => :present
    file "/etc/localtime",
      :ensure => "/usr/share/zoneinfo/#{zone}",
      :notify => service('ntp')
  end

  #### Security Updates

  # Ubuntu allows system administrators to configure the server to automatically
  # download and install stable security updates. We enable these by default
  # because they're well-vetted and ensure servers that might not be actively
  # maintained still receive updates to protect against vulnerabilities.

  def security_updates
    configure(:unattended_upgrade => {:allowed_origins => [distro_unattended_security_origin].compact})
    unattended_config = <<-CONFIG
APT::Periodic::Update-Package-Lists "#{configuration[:unattended_upgrade][:package_lists]||1}";
APT::Periodic::Unattended-Upgrade "#{configuration[:unattended_upgrade][:interval]||1}";
CONFIG

    package 'unattended-upgrades', :ensure => :latest
    file '/etc/apt/apt.conf.d/10periodic',
      :ensure => :present,
      :mode => '644',
      :content => unattended_config
    file '/etc/apt/apt.conf.d/50unattended-upgrades',
      :ensure => :present,
      :mode => '644',
      :content => template(File.join(File.dirname(__FILE__), "templates", "unattended_upgrades.erb"))
  end

  #### Apt Sources

  # Ubuntu 8.10 has been End of Life'd, so we provide a special apt
  # mirror for it. This recipe simply uses those repos for Intrepid users
  # and Lucid for everyone else.

  def apt_sources
    if ubuntu_intrepid?
      file '/etc/apt/sources.list',
        :ensure => :present,
        :mode => '644',
        :content => template(File.join(File.dirname(__FILE__), "templates", "sources.list.intrepid"))
      exec 'apt-get update', :command => 'apt-get update', :require => file('/etc/apt/sources.list')
    else
      exec 'apt-get update', :command => 'apt-get update'
    end
  end

  #### Packages

  # We Override the `shadow_puppet` package method to inject a dependency on
  # `exec('apt-get update')`. This accomplishes two things:
  #
  # 1. Apt won't fail to retrieve a package because the apt-cache is out of date
  # 2. Apt will always fetch the latest version of a package unless otherwise specified

  def package(*args)
    if args && args.flatten.size == 1
      super(*args)
    elsif
      name = args.first
      hash = args.last
      hash[:require] = Array(hash[:require]).push(exec('apt-get update'))
      super(name, hash)
    end
  end

private

  #### Ubuntu Version Detection

  # Some parts of the server may need configured differently based on
  # the version of Ubuntu they're running. Moonshine currently supports
  # 8.10 and 10.04, so we provide helpers to detect those versions.

  def ubuntu_lucid?
    Facter.lsbdistid == 'Ubuntu' && Facter.lsbdistrelease.to_f == 10.04
  end

  def ubuntu_intrepid?
    Facter.lsbdistid == 'Ubuntu' && Facter.lsbdistrelease.to_f == 8.10
  end

  def distro_unattended_security_origin
    case Facter.lsbdistrelease.to_f
    when 8.10 then 'Ubuntu intrepid-security'
    when 10.04 then 'Ubuntu lucid-security'
    end
  end

  #### Logrotate

  # We provide a simple helper for automating the configuration of logrotate
  # scripts since many utilities can log lots of output that we can safely
  # rotate on a regular basis.
  #
  # Example:
  #
  #     logrotate '/srv/theapp/shared/logs/*.log',
  #       :options => [
  #         'daily', 'missingok', 'compress',
  #         'delaycompress', 'sharedscripts'
  #       ],
  #       :postrotate => 'touch /srv/theapp/current/tmp/restart.txt'


  def logrotate(log_or_glob, options = {})
    options = options.respond_to?(:to_hash) ? options.to_hash : {}

    package "logrotate", :ensure => :installed, :require => package("cron"), :notify => service("cron")

    safename = log_or_glob.gsub(/[^a-zA-Z]/, '')

    file "/etc/logrotate.d/#{safename}.conf",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), "templates", "logrotate.conf.erb"), binding),
      :notify => service("cron"),
      :alias => "logrotate_#{safename}"
  end

end

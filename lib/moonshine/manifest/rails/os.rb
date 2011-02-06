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
  #       :user => configuration[:user],
  #       :minute => 15
  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
  end

  # Create a MOTD to remind those logging in via SSH that things are managed
  # with Moonshine
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

  # Install postfix.
  def postfix
    package 'postfix', :ensure => :latest
  end

  # Install ntp and enables the ntp service.
  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  # Set the system timezone to <tt>configuration[:time_zone]</tt> or 'UTC' by
  # default.
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

  # Configure automatic security updates. Output regarding errors
  # will be sent to <tt>configuration[:user]</tt>. To exclude specific
  # packages from these upgrades, create an array of packages on
  # <tt>configuration[:unattended_upgrade][:package_blacklist]</tt>
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

  # Override the shadow_puppet package method to inject a dependency on
  # exec('apt-get update')
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

  #Provides a helper for creating logrotate config for various parts of your
  #stack. For example:
  #
  #  logrotate('/srv/theapp/shared/logs/*.log', {
  #    :options => %w(daily missingok compress delaycompress sharedscripts),
  #    :postrotate => 'touch /srv/theapp/current/tmp/restart.txt'
  #  })
  #
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

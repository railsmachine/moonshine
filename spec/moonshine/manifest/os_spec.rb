require 'spec_helper'

describe Moonshine::Manifest::Rails::Os do
  before do
    @manifest = Moonshine::Manifest::Rails.new
  end

  context "Ubuntu Lucid (10.04)" do
    before do
      Facter.stub!(:lsbdistrelease => '10.04')
      Facter.stub!(:lsbdistid => 'Ubuntu')
    end

    specify "#security_update sets up unattended upgrades from lucid-security" do
      @manifest.security_updates

      @manifest.should have_file("/etc/apt/apt.conf.d/50unattended-upgrades").with_content(
        /Ubuntu lucid-security/
      )

    end

    specify "#apt_sources injects a dependency on apt-get update" do
      @manifest.apt_sources

      @manifest.should exec_command('apt-get update')

      @manifest.should_not have_file("/etc/apt/sources.list")

      @manifest.package('foo', :ensure => :installed)

      @manifest.packages['foo'].should require_resource(@manifest.exec('apt-get update'))

      @manifest.execs['apt-get update'].should_not require_resource(@manifest.file('/etc/apt/sources.list'))

    end
  end

  context "Ubuntu Intrepid (8.10)" do
    before do
      Facter.stub!(:lsbdistrelease => '8.10')
      Facter.stub!(:lsbdistid => 'Ubuntu')
    end

    specify "#security_update sets up unattended upgrades from intrepid-security" do
      @manifest.security_updates

      @manifest.should have_file("/etc/apt/apt.conf.d/50unattended-upgrades").with_content(
        /Ubuntu intrepid-security/
      )
    end

    specify "#apt_sources installs customized sources.lst and injects a dependency on it" do
      @manifest.apt_sources

      @manifest.should exec_command('apt-get update')

      @manifest.execs['apt-get update'].should require_resource([
        @manifest.file('/etc/apt/sources.list')
      ])

      @manifest.should have_file("/etc/apt/sources.list").with_content(
        /deb http:\/\/old-releases.ubuntu.com\/ubuntu intrepid main restricted universe multiverse/
      )

      @manifest.package('foo', :ensure => :installed)
      @manifest.package('too', :ensure => :installed)
      @manifest.package('bar', :ensure => :installed, :require => @manifest.package('foo'))
      @manifest.package('baz', :ensure => :installed, :require => [@manifest.package('foo'), @manifest.package('too')])

      @manifest.packages['foo'].should require_resource(@manifest.exec('apt-get update'))
      @manifest.packages['bar'].should require_resource([
        @manifest.package('foo'),
        @manifest.exec('apt-get update')
      ])
      @manifest.packages['baz'].should require_resource([
        @manifest.package('foo'),
        @manifest.package('too'),
        @manifest.exec('apt-get update')
      ])
    end

  end

  specify "#security_update" do
    @manifest.configure(:unattended_upgrade => { :package_blacklist => ['foo', 'bar', 'widget']})
    @manifest.configure(:user => 'rails')

    @manifest.security_updates

    @manifest.should have_package("unattended-upgrades")
    @manifest.should have_file("/etc/apt/apt.conf.d/10periodic").with_content(
      /APT::Periodic::Unattended-Upgrade "1"/
    )
    @manifest.should have_file("/etc/apt/apt.conf.d/50unattended-upgrades").with_content(
      /Unattended-Upgrade::Mail "rails@localhost";/
    )
    @manifest.should have_file("/etc/apt/apt.conf.d/50unattended-upgrades").with_content(
      /"foo";/
    )
  end

  specify "hostname" do
    @manifest.configure(:hostname => "awesome-mc-winface.com")
    @manifest.hostname

    @manifest.should have_file('/etc/hostname').with_content(
      /^awesome\-mc\-winface\.com$/
    )
  end

  specify "postfix" do
    @manifest.configure(:mailname => "mail.awesome-mc-winface.com")
    @manifest.postfix

    @manifest.should have_package("postfix")
    @manifest.should have_file("/etc/mailname").with_content(
      /^mail\.awesome\-mc\-winface\.com$/
    )
  end
end
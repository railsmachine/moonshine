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
end
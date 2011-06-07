require 'spec_helper'

describe Moonshine::Manifest::Rails::Passenger do
  before do
    @manifest = Moonshine::Manifest::Rails.new
  end

  context 'without a version configured' do
    before do
      @manifest.configure(:passenger => { :version => nil })
      @manifest.passenger_gem
      @manifest.passenger_configure_gem_path
      @manifest.passenger_apache_module
    end

    it "installs #{Moonshine::Manifest::Rails::Passenger::BLESSED_VERSION} by default" do
      @manifest.should have_package('passenger').version(Moonshine::Manifest::Rails::Passenger::BLESSED_VERSION)
    end

    it "loads #{Moonshine::Manifest::Rails::Passenger::BLESSED_VERSION} into apache" do
      @manifest.should have_file('/etc/apache2/mods-available/passenger.load').with_content(
        /#{Moonshine::Manifest::Rails::Passenger::BLESSED_VERSION}/
      )
    end

    it 'configures and builds the apache module' do
      @manifest.should have_package('apache2-threaded-dev')
      @manifest.should have_file('/etc/apache2/mods-available/passenger.conf').with_content(
        /PassengerUseGlobalQueue On/
      )
      @manifest.should exec_command('/usr/sbin/a2enmod passenger')
      @manifest.should exec_command('sudo /usr/bin/ruby -S rake clean apache2')
    end

    it "allows setting booleans configurations to false" do
      @manifest.configure(:passenger => { :use_global_queue => false })
      @manifest.passenger_configure_gem_path
      @manifest.passenger_apache_module

      @manifest.should have_file('/etc/apache2/mods-available/passenger.conf').with_content(
        /PassengerUseGlobalQueue Off/
      )
    end
  end

  context 'with a version configured' do
    before do
      @manifest.configure(:passenger => { :version => '2.2.2' })
      @manifest.passenger_gem
      @manifest.passenger_configure_gem_path
      @manifest.passenger_apache_module
    end

    it 'installs the configured version' do
      @manifest.should have_package('passenger').version('2.2.2')
    end

    it "loads the configured version into apache" do
      @manifest.should have_file('/etc/apache2/mods-available/passenger.load').with_content(
        /2.2.2/
      )
    end
  end

end
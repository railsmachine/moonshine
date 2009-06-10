#!/bin/bash

apt-get update

echo "Installing build packages"
apt-get install -q -y git-core build-essential zlib1g-dev libssl-dev libreadline5-dev wget

echo "Installing Ruby"
apt-get install -q -y ruby-full

echo "Installing RubyGems"
cd /tmp
wget http://rubyforge.org/frs/download.php/45905/rubygems-1.3.1.tgz
tar xfz rubygems-1.3.1.tgz
cd rubygems-1.3.1
ruby setup.rb
ln -s /usr/bin/gem1.8 /usr/bin/gem
gem update --system
cd ..
echo "Cleaning up RubyGems Download"
rm -rf rubygems-1.3.1*

echo "Installing Shadow Puppet"
gem install shadow_puppet --no-rdoc --no-ri
#!/bin/bash

apt-get update

echo "Installing build packages"
apt-get install -q -y git-core build-essential zlib1g-dev libssl-dev libreadline5-dev wget

echo "Removing Ruby from apt"
apt-get remove -q -y ^ruby*

PREFIX="/usr"
REE="ruby-enterprise-1.8.6-20090610"

if [ -z `which ruby` ] || [ "$FORCE_RUBY" = "true" ]; then

  echo "Installing Ruby"

  cd /tmp
  echo "Downloading REE"
  wget -q http://assets.railsmachine.com/other/$REE.tar.gz
  echo "Untar REE"
  tar xzf $REE.tar.gz

  echo "Running installer"
  ./$REE/installer --dont-install-useful-gems -a $PREFIX

  echo "Cleaning up REE download"
  rm -rf $REE*

else

  echo "Ruby already installed."

fi

echo "Installing Rake"
gem install rake --no-rdoc --no-ri

echo "Installing Shadow Puppet"
gem install shadow_puppet --no-rdoc --no-ri
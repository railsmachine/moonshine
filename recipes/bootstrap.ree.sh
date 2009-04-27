#!/bin/bash

echo "***Bootstrappin' the system!***"
apt-get update

echo "Installing build packages"
apt-get install -q -y git-core build-essential zlib1g-dev libssl-dev libreadline5-dev wget

echo "Removing Ruby from apt"
apt-get remove -q -y ^ruby*

PREFIX="/usr"
REE="ruby-enterprise-1.8.6-20090421"

if [ `which ruby` ]; then

 echo "Ruby already installed."

else

  echo "Installing Ruby"

  pushd /tmp
  echo "Downloading REE"
  wget -q http://rubyforge.org/frs/download.php/55511/$REE.tar.gz
  echo "Untar REE"
  tar xzf $REE.tar.gz
  pushd $REE/

  echo "Running installer"
  ./installer --dont-install-useful-gems -a $PREFIX

  echo "Cleaning up REE download"
  popd
  rm -rf $REE*
  popd

fi

echo "Installing Rake"
gem install rake --no-rdoc --no-ri

echo "Installing Shadow Puppet"
gem install shadow_puppet --no-rdoc --no-ri
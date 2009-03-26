#!/bin/bash

echo "***Bootstrappin' the system!***"
apt-get update

echo "Installing build packages"
apt-get install -q -y git-core build-essential zlib1g-dev libssl-dev libreadline5-dev wget

echo "Removing Ruby from apt"
apt-get remove -q -y ^ruby*

PREFIX="/usr"
REE="ruby-enterprise-1.8.6-20090201"

pushd /tmp
echo "Downloading REE"
wget -q http://rubyforge.org/frs/download.php/51100/$REE.tar.gz
echo "Untar REE"
tar xvzf $REE.tar.gz
pushd $REE/

echo "Installing fancy google memory thingie"
pushd ./source/vendor/google-perftools-0.99.2
./configure --prefix=$PREFIX --disable-dependency-tracking
make libtcmalloc_minimal.la
rm -f $PREFIX/lib/libtcmalloc_minimal*.so*
cp -pf .libs/libtcmalloc_minimal*.so* $PREFIX/lib/
popd

echo "Makeing and installing REE"
pushd ./source
./configure --prefix=$PREFIX
echo 'Avert your eyes'
# YIKES!
sed -i 's?LIBS = -ldl?LIBS = $(PRELIBS) -ldl?' ./Makefile
make PRELIBS="-Wl,-rpath,$PREFIX/lib -L$PREFIX/lib -ltcmalloc_minimal"
make install
popd

echo "Installing RubyGems"
pushd ./rubygems
ruby setup.rb --no-rdoc --no-ri
popd

echo "Cleaning up REE download"
rm -rf $REE*
popd

echo "Installing Rake"
gem install rake --no-rdoc --no-ri

echo "Installing Shadow Puppet"
gem install shadow_puppet --no-rdoc --no-ri
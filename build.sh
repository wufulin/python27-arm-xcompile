#!/bin/bash

# change these to match your environment
TARGET_HOST="arm-fsl-linux-gnueabi"
CROSS_TOOLS_PATH=/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/$TARGET_HOST/bin
BUILD_HOST="arm"

# you shouldn't need to change these
PYTHON="Python-2.7.3"
CONFIGURE_ARGS="--disable-ipv6"
BUILD_LOG="build.log"

# build log goes here
rm -f $BUILD_LOG
touch $BUILD_LOG
echo "Build output will be in $BUILD_LOG"

# download dist if it doesn't already exist
if [ ! -f $PYTHON.tar.xz ] ; then
    echo "Downloading $PYTHON .."
    wget http://www.python.org/ftp/python/2.7.3/Python-2.7.3.tar.xz >> $BUILD_LOG
fi

rm -rf $PYTHON
tar -xf $PYTHON.tar.xz
cp -p files/config.site $PYTHON
cd $PYTHON
BUILD_LOG="../$BUILD_LOG"
unset CROSS_COMPILE

# ensure static glibc is installed
rpm -qa | grep -q glibc-static
if [ $? -eq 1 ] ; then
    echo "Installing glibc-static (with sudo yum install) .."
    sudo yum install -y glibc-static >> $BUILD_LOG
fi

set -e

# first we need to build the host executables (python and Parser/pgen)
echo "Stage 1: compiling host executables .."
./configure $CONFIGURE_ARGS CONFIG_SITE="config.site" >> $BUILD_LOG
make python Parser/pgen >> $BUILD_LOG
mv python hostpython
mv Parser/pgen Parser/hostpgen
make distclean

# set up environment for cross compile - we really shouldn't blindly add to PATH
# PATH=$PATH:/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/arm-fsl-linux-gnueabi/bin
# CC=/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/arm-fsl-linux-gnueabi/bin/arm-fsl-linux-gnueabi-gcc
# AR=/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/arm-fsl-linux-gnueabi/bin/arm-fsl-linux-gnueabi-ar
# RANLIB=/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/arm-fsl-linux-gnueabi/bin/arm-fsl-linux-gnueabi-ranlib
# LD=/opt/gcc-4.4.4-glibc-2.11.1-multilib-1.0/arm-fsl-linux-gnueabi/bin/arm-fsl-linux-gnueabi-ld

export PATH="$PATH:$CROSS_TOOLS_PATH"
export CROSS_COMPILE=arm-fsl-linux-gnueabi-
export CC=$CROSS_TOOLS_PATH/arm-fsl-linux-gnueabi-gcc
export AR=$CROSS_TOOLS_PATH/arm-fsl-linux-gnueabi-ar
export RANLIB=$CROSS_TOOLS_PATH/arm-fsl-linux-gnueabi-ranlib
export LD=$CROSS_TOOLS_PATH/arm-fsl-linux-gnueabi-ld


echo "Stage 1.5: patching Python for cross-compile .."
patch -p0 < ../files/Python-2.7.3-xcompile.patch

# cross compile
echo "Stage 2: cross-compiling for $TARGET_HOST .."
# ./configure --disable-ipv6 --build="arm" --host="arm-fsl-linux-gnueabi" --prefix=$PWD/_install LDFLAGS="-L/usr/lib  -static -static-libgcc" CPPFLAGS="-I/usr/include -static" CONFIG_SITE="config.site"
./configure $CONFIGURE_ARGS --build=$BUILD_HOST --host=$TARGET_HOST \
    LDFLAGS="-L/usr/lib -static -static-libgcc" CPPFLAGS="-I/usr/include -static" CONFIG_SITE="config.site" >> $BUILD_LOG
sed -i '1r ../files/Setup' Modules/Setup
# make HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen CROSS_COMPILE_TARGET=yes BLDSHARED="arm-fsl-linux-gnueabi-gcc -shared" BUILDARCH="arm" HOSTARCH="arm-fsl-linux-gnueabi"
make HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen BLDSHARED="arm-fsl-linux-gnueabi-gcc -shared" CROSS_COMPILE_TARGET=yes BUILDARCH=$BUILD_HOST HOSTARCH=$TARGET_HOST >> $BUILD_LOG

# make install HOSTPYTHON=./hostpython BLDSHARED="arm-fsl-linux-gnueabi-gcc -shared" CROSS_COMPILE=arm-fsl-linux-gnueabi- CROSS_COMPILE_TARGET=yes prefix=$PWD/_install
make install HOSTPYTHON=./hostpython BLDSHARED="arm-fsl-linux-gnueabi-gcc -shared" CROSS_COMPILE=$CROSS_COMPILE CROSS_COMPILE_TARGET=yes prefix=$PWD/_install >> $BUILD_LOG

sed -n -e '/Python build finished/,$p' $BUILD_LOG | grep -v 'install'
file python

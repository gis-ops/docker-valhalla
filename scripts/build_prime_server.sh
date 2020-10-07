#!/usr/bin/env bash

url="https://github.com/kevinkreiser/prime_server.git"
NPROC=$(nproc)

git clone ${url} && cd prime_server
git fetch && git fetch --tags && git checkout "${1}"
git submodule update --init --recursive
./autogen.sh
./configure --prefix=/usr LIBS="-lpthread"
make all -j"$NPROC"
make -k test -j"$NPROC"
make install

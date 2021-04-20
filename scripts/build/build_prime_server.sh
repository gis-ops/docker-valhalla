#!/usr/bin/env bash

set -e

url="https://github.com/kevinkreiser/prime_server.git"
NPROC=$(nproc)

git clone --recurse-submodules ${url} && cd prime_server
git fetch --tags && git checkout "${1}"
./autogen.sh
./configure
make -k test -j"$NPROC"

make install

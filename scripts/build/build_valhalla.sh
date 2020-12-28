#!/usr/bin/env bash

set -e

url="https://github.com/valhalla/valhalla"
NPROC=$(nproc)

git clone $url valhalla_git
cd valhalla_git
git fetch --tags
git checkout "${1}"
git submodule sync
git submodule update --init --recursive
mkdir build
cmake -H. -Bbuild \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_CCACHE=OFF \
  -DENABLE_BENCHMARKS=OFF
make -C build -j"$NPROC"
#make -C build -j"$NPROC" check
make -C build install

#!/usr/bin/env bash

set -e

url="https://github.com/valhalla/valhalla"
NPROC=$(nproc)

git clone --recurse-submodules $url valhalla_git
cd $_
git fetch --tags
git checkout "${1}"
# install to /usr/local so we can copy easily from the builder to the runner
cmake -H. -Bbuild \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_CCACHE=OFF \
  -DENABLE_BENCHMARKS=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_TOOLS=ON
make -C build -j"$NPROC"
make -C build install

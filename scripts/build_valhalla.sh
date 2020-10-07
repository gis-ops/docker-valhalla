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
  -DCMAKE_C_FLAGS:STRING="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS:STRING="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS:STRING="${LDFLAGS}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DENABLE_DATA_TOOLS=On \
  -DENABLE_PYTHON_BINDINGS=On \
  -DENABLE_SERVICES=On \
  -DENABLE_HTTP=On
cd build
make -j"$NPROC"
make -j"$NPROC" check
make install

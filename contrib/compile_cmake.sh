#!/bin/sh
# Compile CMake from source
# This file is a part of Julia. License is MIT: http://julialang.org/license

set -e

mkdir -p "$(dirname "$0")/../deps/scratch"
cd "$(dirname "$0")/../deps/scratch"

CMAKE_VERSION_MAJOR=3
CMAKE_VERSION_MINOR=7
CMAKE_VERSION_PATCH=2
CMAKE_VERSION_MAJMIN="${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}"
CMAKE_VERSION="${CMAKE_VERSION_MAJMIN}.${CMAKE_VERSION_PATCH}"

CMAKE_SHA256="dc1246c4e6d168ea4d6e042cfba577c1acd65feea27e56f5ff37df920c30cae0"

FULLNAME="cmake-${CMAKE_VERSION}"

../tools/jldownload "https://cmake.org/files/v${CMAKE_VERSION_MAJMIN}/${FULLNAME}.tar.gz"
echo "${CMAKE_SHA256}  ${FULLNAME}.tar.gz" | sha256sum -c -

tar -xvzf "${FULLNAME}.tar.gz"
cd "${FULLNAME}/"
./configure
make

# This has to be a separate step when running on CircleCI
if [ -z "$1" ]; then
    echo "override CMAKE=${PWD}/bin/cmake" >> ../../Make.user
fi

# We want to exit with failure if the built CMake doesn't work
./bin/cmake --version

#!/bin/bash

set -ex

gh release upload $1 ./build/libtantivy-rs.xcframework.zip --clobber
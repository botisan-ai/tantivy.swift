#!/bin/bash

set -ex

BUILD_DIR="./build"
LIB_BASENAME="tantivy"

XCFRAMEWORK_NAME="lib${LIB_BASENAME}-rs"
XCFRAMEWORK_DIR="${BUILD_DIR}/${XCFRAMEWORK_NAME}.xcframework"
XCFRAMEWORK_ZIP="${XCFRAMEWORK_DIR}.zip"

version=$(sed -nE 's/^[[:space:]]*let releaseTag = "([^"]+)".*/\1/p' ./Package.swift | head -n 1)
if [ -z "$version" ]; then
  echo "Could not parse releaseTag from ./Package.swift" >&2
  exit 1
fi

gh release create "$version" --generate-notes
gh release upload "$version" "${XCFRAMEWORK_ZIP}" --clobber

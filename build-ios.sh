#!/bin/bash

set -ex

# arch targets to build for
TARGETS_LIST="aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin"
IFS=' ' read -r -a TARGETS <<< "${TARGETS_LIST}"

OUT_DIR="./out"
BUILD_DIR="./build"

SOURCE_SUBPATH="TantivyFFI"
HEADER_SUBPATH="tantivyFFI"
LIB_BASENAME="tantivy"

SOURCE_DIR="./Sources/${SOURCE_SUBPATH}"
SWIFT_SRC_FILE="${LIB_BASENAME}.swift"
DYLIB_NAME="lib${LIB_BASENAME}.dylib"
STATICLIB_NAME="lib${LIB_BASENAME}.a"

HEADERS_DIR="${BUILD_DIR}/Headers"
HEADER_DIR="${HEADERS_DIR}/${HEADER_SUBPATH}"
HEADER_FILE="${HEADER_SUBPATH}.h"
MODULEMAP_FILE="${HEADER_SUBPATH}.modulemap"

XCFRAMEWORK_NAME="lib${LIB_BASENAME}-rs"
XCFRAMEWORK_DIR="${BUILD_DIR}/${XCFRAMEWORK_NAME}.xcframework"
XCFRAMEWORK_ZIP="${XCFRAMEWORK_DIR}.zip"

rm -rf "${BUILD_DIR}"
rm -rf "${OUT_DIR}"

cargo build
cargo run --bin uniffi-bindgen generate --library "./target/debug/${DYLIB_NAME}" --language swift --out-dir "${OUT_DIR}"

mv "${OUT_DIR}/${MODULEMAP_FILE}" "${OUT_DIR}/module.modulemap"

for target in "${TARGETS[@]}"; do
  cargo build --release --target "${target}"
done

rm -rf "${BUILD_DIR}"
mkdir -p "${HEADER_DIR}"
cp "${OUT_DIR}/${HEADER_FILE}" "${HEADER_DIR}/"
cp "${OUT_DIR}/module.modulemap" "${HEADER_DIR}/"

mkdir -p "${SOURCE_DIR}"
cp "${OUT_DIR}/${SWIFT_SRC_FILE}" "${SOURCE_DIR}/"

XCF_ARGS=()
for target in "${TARGETS[@]}"; do
  XCF_ARGS+=(-library "./target/${target}/release/${STATICLIB_NAME}" -headers "${HEADERS_DIR}")
done
xcodebuild -create-xcframework "${XCF_ARGS[@]}" -output "${XCFRAMEWORK_DIR}"

ditto -c -k --sequesterRsrc --keepParent "${XCFRAMEWORK_DIR}" "${XCFRAMEWORK_ZIP}"
checksum=$(swift package compute-checksum "${XCFRAMEWORK_ZIP}")
metadata=$(cargo metadata --format-version 1 --no-deps)
pkg_id=$(jq -r '.workspace_members[0]' <<<"$metadata")
pkg_name=$(jq -r --arg pkg_id "$pkg_id" '.packages[] | select(.id==$pkg_id) .name' <<<"$metadata")
version=$(jq -r --arg pkg_id "$pkg_id" '.packages[] | select(.id==$pkg_id) .version' <<<"$metadata")
sed -i "" -E "s/(let releaseTag = \")[^\"]*(\")/\1$version\2/g" ./Package.swift
sed -i "" -E "s/(let releaseChecksum = \")[^\"]*(\")/\1$checksum\2/g" ./Package.swift

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${SIPMAN_DEPS_WORK_DIR:-${TELEPHONE_DEPS_WORK_DIR:-/private/tmp/sipman-deps}}"
MIN_MACOS="${SIPMAN_MIN_MACOS:-${TELEPHONE_MIN_MACOS:-13.5}}"
ARCHS="${SIPMAN_ARCHS:-${TELEPHONE_ARCHS:-arm64}}"
FORCE=0

OPUS_VERSION="1.3.1"
LIBRESSL_VERSION="3.1.5"
PJPROJECT_VERSION="2.10"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build and install SIPMan's third-party dependencies into ThirdParty/.

Options:
  --work-dir PATH    Source/build work directory. Default: $WORK_DIR
  --archs "LIST"    Architectures to build. Default: "$ARCHS"
                    Example: --archs "arm64 x86_64"
  --min-macos VER   Minimum macOS deployment target. Default: $MIN_MACOS
  --force           Rebuild dependencies even if installed artifacts exist.
  -h, --help        Show this help.

Environment overrides:
  SIPMAN_DEPS_WORK_DIR, SIPMAN_ARCHS, SIPMAN_MIN_MACOS
  TELEPHONE_DEPS_WORK_DIR, TELEPHONE_ARCHS, TELEPHONE_MIN_MACOS are still accepted for compatibility.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    --archs)
      ARCHS="$2"
      shift 2
      ;;
    --min-macos)
      MIN_MACOS="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

arch_flags() {
  local flags=()
  local arch
  for arch in $ARCHS; do
    flags+=("-arch" "$arch")
  done
  printf '%q ' "${flags[@]}"
}

download() {
  local url="$1"
  local output="$2"

  if [[ -f "$output" ]]; then
    echo "Using cached $(basename "$output")"
    return
  fi

  echo "Downloading $url"
  curl -L -o "$output" "$url"
}

extract() {
  local archive="$1"
  local directory="$2"

  if [[ "$FORCE" -eq 1 && "$directory" == "$WORK_DIR"/* ]]; then
    rm -rf "$directory"
  fi

  if [[ -d "$directory" ]]; then
    echo "Using existing source directory $directory"
    return
  fi

  echo "Extracting $(basename "$archive")"
  tar xzf "$archive" -C "$WORK_DIR"
}

run_make_install() {
  make
  make install
}

build_opus() {
  local prefix="$ROOT_DIR/ThirdParty/Opus"
  local archive="$WORK_DIR/opus-$OPUS_VERSION.tar.gz"
  local source="$WORK_DIR/opus-$OPUS_VERSION"
  local cflags
  cflags="$(arch_flags)-Os -mmacosx-version-min=$MIN_MACOS"

  if [[ "$FORCE" -eq 0 && -f "$prefix/lib/libopus.a" && -f "$prefix/include/opus/opus.h" ]]; then
    echo "Opus already installed at $prefix"
    return
  fi

  download "https://archive.mozilla.org/pub/opus/opus-$OPUS_VERSION.tar.gz" "$archive"
  extract "$archive" "$source"

  echo "Building Opus $OPUS_VERSION"
  (
    cd "$source"
    ./configure --prefix="$prefix" --disable-shared CFLAGS="$cflags"
    run_make_install
  )
}

build_libressl() {
  local prefix="$ROOT_DIR/ThirdParty/LibreSSL"
  local archive="$WORK_DIR/libressl-$LIBRESSL_VERSION.tar.gz"
  local source="$WORK_DIR/libressl-$LIBRESSL_VERSION"
  local cflags
  cflags="$(arch_flags)-Os -mmacosx-version-min=$MIN_MACOS"

  if [[ "$FORCE" -eq 0 && -f "$prefix/lib/libssl.a" && -f "$prefix/lib/libcrypto.a" && -f "$prefix/include/openssl/ssl.h" ]]; then
    echo "LibreSSL already installed at $prefix"
    return
  fi

  download "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$LIBRESSL_VERSION.tar.gz" "$archive"
  extract "$archive" "$source"

  echo "Building LibreSSL $LIBRESSL_VERSION"
  (
    cd "$source"
    ./configure --prefix="$prefix" --disable-shared CFLAGS="$cflags"
    run_make_install
  )
}

patch_pjproject() {
  local source="$1"
  local stamp="$source/.sipman-patches-applied"

  if [[ -f "$stamp" ]]; then
    echo "PJSIP patches already applied"
    return
  fi

  cp "$ROOT_DIR/ThirdParty/PJSIP/config_site.h" "$source/pjlib/include/pj/config_site.h"

  (
    cd "$source"
    patch -p0 -i "$ROOT_DIR/ThirdParty/PJSIP/patches/sock_qos_darwin.patch"
    patch -p0 -i "$ROOT_DIR/ThirdParty/PJSIP/patches/os_core_unix.patch"
    patch -p0 -i "$ROOT_DIR/ThirdParty/PJSIP/patches/coreaudio_dev.patch"
    touch "$stamp"
  )
}

build_pjsip() {
  local prefix="$ROOT_DIR/ThirdParty/PJSIP"
  local archive="$WORK_DIR/pjproject-$PJPROJECT_VERSION.tar.gz"
  local source="$WORK_DIR/pjproject-$PJPROJECT_VERSION"
  local flags
  flags="$(arch_flags)-Os -DNDEBUG -mmacosx-version-min=$MIN_MACOS"

  if [[ "$FORCE" -eq 0 && -f "$prefix/lib/libpjsua-arm-apple-darwin.a" && -f "$prefix/include/pjsua-lib/pjsua.h" ]]; then
    echo "PJSIP already installed at $prefix"
    return
  fi

  download "https://codeload.github.com/pjsip/pjproject/tar.gz/$PJPROJECT_VERSION" "$archive"
  extract "$archive" "$source"
  patch_pjproject "$source"

  echo "Building PJSIP $PJPROJECT_VERSION"
  (
    cd "$source"
    ./configure \
      --prefix="$prefix" \
      --with-opus="$ROOT_DIR/ThirdParty/Opus" \
      --with-ssl="$ROOT_DIR/ThirdParty/LibreSSL" \
      --disable-video \
      --disable-libyuv \
      --disable-libwebrtc \
      --host=arm-apple-darwin \
      CFLAGS="$flags" \
      CXXFLAGS="$flags"
    make dep
    make lib
    make install
  )
}

main() {
  require_tool curl
  require_tool make
  require_tool patch
  require_tool tar

  mkdir -p "$WORK_DIR"

  build_opus
  build_libressl
  build_pjsip

  echo
  echo "Third-party dependencies are installed."
  echo "Next:"
  echo "  xcodebuild -project SIPMan.xcodeproj -scheme SIPMan -configuration Debug -derivedDataPath /tmp/sipman-deriveddata CODE_SIGNING_ALLOWED=NO build"
}

main "$@"

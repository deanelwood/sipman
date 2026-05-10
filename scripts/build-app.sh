#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: scripts/build-app.sh [--open] [--unsigned] [--configuration NAME] [--derived-data PATH]

Builds the local SIPMan app.

Options:
  --open              Launch the app after a successful build.
  --unsigned          Build without code signing. Use for compile checks only;
                      unsigned builds can trigger Keychain prompts on launch.
  --configuration     Xcode configuration. Default: Debug.
  --derived-data      Derived data path. Default: /tmp/sipman-deriveddata.
  -h, --help          Show this help message.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="/tmp/sipman-deriveddata"
CONFIGURATION="Debug"
OPEN_APP=0
UNSIGNED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      OPEN_APP=1
      shift
      ;;
    --unsigned)
      UNSIGNED=1
      shift
      ;;
    --configuration)
      [[ $# -ge 2 ]] || { echo "Missing value for --configuration" >&2; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --derived-data)
      [[ $# -ge 2 ]] || { echo "Missing value for --derived-data" >&2; exit 2; }
      DERIVED_DATA_PATH="$2"
      shift 2
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

if [[ "${UNSIGNED}" -eq 0 ]] && ! security find-identity -v -p codesigning | grep -Eq '[0-9A-F]{40}'; then
  cat >&2 <<EOF
No valid code-signing identity was found.

Install a Mac Development or Apple Development certificate in Xcode, then
rerun this script for a signed app build. Signed builds give SIPMan a stable
Keychain identity.

For compile-only work you can run:

  scripts/build-app.sh --unsigned

Unsigned builds are useful for local compile checks, but launching them can
make macOS ask for Keychain access each time the app is rebuilt.
EOF
  exit 65
fi

build_settings=(
  -project "${ROOT_DIR}/SIPMan.xcodeproj"
  -scheme SIPMan
  -configuration "${CONFIGURATION}"
  -derivedDataPath "${DERIVED_DATA_PATH}"
  ARCHS=arm64
)

if [[ "${UNSIGNED}" -eq 1 ]]; then
  echo "Warning: building without code signing. Keychain prompts are expected when launching rebuilt apps." >&2
  build_settings+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${build_settings[@]}" build

if [[ "${OPEN_APP}" -eq 1 ]]; then
  open "${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/SIPMan.app"
fi

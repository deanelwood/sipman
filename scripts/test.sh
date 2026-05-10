#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: scripts/test.sh [--scheme NAME] [--derived-data PATH]

Runs the local arm64 XCTest schemes used while developing SIPMan.

Options:
  --scheme NAME        Run one scheme instead of the default test set.
  --derived-data PATH  Derived data path. Default: /tmp/sipman-deriveddata
  -h, --help           Show this help message.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="/tmp/sipman-deriveddata"
SCHEMES=(
  "Domain"
  "UseCasesTests"
  "ReceiptValidationTests"
  "TelephoneTests"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      [[ $# -ge 2 ]] || { echo "Missing value for --scheme" >&2; exit 2; }
      SCHEMES=("$2")
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

for scheme in "${SCHEMES[@]}"; do
  echo "==> Testing ${scheme}"
  xcodebuild \
    -project "${ROOT_DIR}/SIPMan.xcodeproj" \
    -scheme "${scheme}" \
    -configuration Debug \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS=arm64 \
    test
done

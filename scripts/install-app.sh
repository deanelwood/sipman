#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: scripts/install-app.sh [--open] [--unsigned] [--configuration NAME] [--derived-data PATH] [--destination DIR]

Build SIPMan and install SIPMan.app somewhere easy to double-click.

By default the app is copied to:

  ~/Applications/SIPMan.app

Options:
  --open              Launch the installed app after copying it.
  --unsigned          Build without code signing. Use only as a fallback;
                      unsigned rebuilt apps can trigger Keychain prompts.
  --configuration     Xcode configuration. Default: Debug.
  --derived-data      Derived data path. Default: /tmp/sipman-deriveddata.
  --destination       Install directory. Default: ~/Applications.
  -h, --help          Show this help message.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="/tmp/sipman-deriveddata"
CONFIGURATION="Debug"
DESTINATION_DIR="${HOME}/Applications"
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
    --destination)
      [[ $# -ge 2 ]] || { echo "Missing value for --destination" >&2; exit 2; }
      DESTINATION_DIR="${2/#\~/${HOME}}"
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

build_args=(
  --configuration "${CONFIGURATION}"
  --derived-data "${DERIVED_DATA_PATH}"
)

if [[ "${UNSIGNED}" -eq 1 ]]; then
  build_args+=(--unsigned)
fi

"${ROOT_DIR}/scripts/build-app.sh" "${build_args[@]}"

SOURCE_APP="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/SIPMan.app"
TARGET_APP="${DESTINATION_DIR}/SIPMan.app"

if [[ ! -d "${SOURCE_APP}" ]]; then
  echo "Built app was not found at ${SOURCE_APP}" >&2
  exit 66
fi

mkdir -p "${DESTINATION_DIR}"
rm -rf "${TARGET_APP}"
ditto "${SOURCE_APP}" "${TARGET_APP}"

echo "Installed SIPMan at ${TARGET_APP}"
echo "You can now double-click it in Finder."

if [[ "${OPEN_APP}" -eq 1 ]]; then
  open "${TARGET_APP}"
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

required_paths=(
  "${ROOT_DIR}/bin/devtools"
  "${ROOT_DIR}/lib"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "ERROR: missing required path for vendoring contract: $path" >&2
    exit 1
  fi
done

echo "OK: vendorize placeholder passed (required paths exist)."

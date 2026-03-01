#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats is not installed. Install bats-core to run tests." >&2
  exit 1
fi

bats "${ROOT_DIR}/tests"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "${ROOT_DIR}/lib/promote/strategies/dev-direct.sh"

# source only, no execution side-effects expected
# shellcheck source=../lib/promote/strategies/dev-direct.sh
source "${ROOT_DIR}/lib/promote/strategies/dev-direct.sh"

declare -F promote_to_dev_direct >/dev/null 2>&1 || {
  echo "FAIL: promote_to_dev_direct not defined" >&2
  exit 1
}

declare -F promote_dev_direct_monitor >/dev/null 2>&1 || {
  echo "FAIL: promote_dev_direct_monitor not defined" >&2
  exit 1
}

echo "OK: manual_dev_direct_source"

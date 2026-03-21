#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$ROOT"

eval "$(devbox shell --print-env)"

command -v bats >/dev/null 2>&1 || {
  echo "bats no esta disponible despues de devbox shell --print-env" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "jq no esta disponible despues de devbox shell --print-env" >&2
  exit 1
}

bats tests/contracts/devbox-shell/devbox-shell-contract.bats

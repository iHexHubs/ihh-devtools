#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKFLOW_FILE="${ROOT_DIR}/lib/promote/workflows/to-dev.sh"

extract_fn() {
  local file="$1"
  local fn="$2"
  awk -v fn="$fn" '
    BEGIN { capture=0; depth=0 }
    $0 ~ "^" fn "\\(\\)[[:space:]]*\\{" {
      capture=1
    }
    capture {
      print
      line=$0
      opens=gsub(/\{/, "{", line)
      closes=gsub(/\}/, "}", line)
      depth += opens - closes
      if (depth == 0) {
        exit
      }
    }
  ' "$file"
}

fn_code="$(extract_fn "$WORKFLOW_FILE" "promote_dev_is_protected_branch")"
[[ -n "$fn_code" ]] || { echo "ERROR: function not found" >&2; exit 1; }

# shellcheck disable=SC1090
source /dev/stdin <<< "$fn_code"

assert_rc() {
  local expected_rc="$1"
  local label="$2"
  shift 2

  set +e
  "$@"
  local rc=$?
  set -e

  if [[ "$rc" -ne "$expected_rc" ]]; then
    echo "FAIL: ${label}: expected_rc=${expected_rc} actual_rc=${rc}" >&2
    exit 1
  fi
}

DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS='dev|main|release/*'
assert_rc 0 "dev" promote_dev_is_protected_branch dev
assert_rc 0 "release wildcard" promote_dev_is_protected_branch release/v1.2.3
assert_rc 1 "feature branch" promote_dev_is_protected_branch feature/test

DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS='prod,stable/*'
assert_rc 0 "comma pattern" promote_dev_is_protected_branch stable/1
assert_rc 1 "comma pattern mismatch" promote_dev_is_protected_branch dev

echo "OK: manual_to_dev_protected_branch"

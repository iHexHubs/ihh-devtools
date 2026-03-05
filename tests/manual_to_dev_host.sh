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

fn_code="$(extract_fn "$WORKFLOW_FILE" "__promote_dev_host_from_origin_url")"
[[ -n "$fn_code" ]] || { echo "ERROR: function not found" >&2; exit 1; }

# shellcheck disable=SC1090
source /dev/stdin <<< "$fn_code"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: ${label}: expected='${expected}' actual='${actual}'" >&2
    exit 1
  fi
}

assert_eq "github.com" "$(__promote_dev_host_from_origin_url 'git@github.com:iHexHubs/ihh.git')" "ssh-short"
assert_eq "github.enterprise.local" "$(__promote_dev_host_from_origin_url 'ssh://git@github.enterprise.local/iHexHubs/ihh.git')" "ssh-url"
assert_eq "github.com" "$(__promote_dev_host_from_origin_url 'https://github.com/iHexHubs/ihh.git')" "https"
assert_eq "github.com" "$(__promote_dev_host_from_origin_url 'invalid-origin-url')" "fallback"

echo "OK: manual_to_dev_host"

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

fn_code="$(extract_fn "$WORKFLOW_FILE" "promote_dev_verify_target_advanced_or_die")"
[[ -n "$fn_code" ]] || { echo "ERROR: function not found" >&2; exit 1; }

log_error() {
  echo "$*" >&2
}

# shellcheck disable=SC1090
source /dev/stdin <<< "$fn_code"

tdir="$(mktemp -d)"
trap 'rm -rf "$tdir"' EXIT

cd "$tdir"
git init -q
git config user.name "Test Bot"
git config user.email "test@example.com"
git config commit.gpgsign false

echo "base" > f.txt
git add f.txt
git commit -m "base" >/dev/null 2>&1
git branch -M dev

base_sha="$(git rev-parse dev)"

git checkout -q -b feature/test
echo "advance" >> f.txt
git add f.txt
git commit -m "advance" >/dev/null 2>&1
source_sha="$(git rev-parse HEAD)"

git checkout -q dev
git merge --ff-only feature/test >/dev/null 2>&1

advance_out="$(promote_dev_verify_target_advanced_or_die dev "$source_sha" "$base_sha")"
if [[ "$advance_out" != "$source_sha" ]]; then
  echo "FAIL: expected advanced sha '${source_sha}', got '${advance_out}'" >&2
  exit 1
fi

before_same="$(git rev-parse dev)"
set +e
promote_dev_verify_target_advanced_or_die dev "$source_sha" "$before_same" >/tmp/manual_to_dev_verify_noop.out 2>&1
noop_rc=$?
set -e

if [[ "$noop_rc" -eq 0 ]]; then
  echo "FAIL: expected NO-OP detection to fail" >&2
  exit 1
fi

echo "OK: manual_to_dev_verify_advanced"

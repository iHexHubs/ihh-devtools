#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
COMMON_FILE="${ROOT_DIR}/lib/promote/workflows/common.sh"

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

fn_code="$(extract_fn "$COMMON_FILE" "resolve_promote_component")"
[[ -n "$fn_code" ]] || { echo "ERROR: resolve_promote_component not found" >&2; exit 1; }

# shellcheck disable=SC1090
source /dev/stdin <<< "$fn_code"

make_repo_case() {
  local changed_paths_csv="$1"
  local tdir
  tdir="$(mktemp -d)"

  git -C "$tdir" init -q
  git -C "$tdir" config user.name "Test Bot"
  git -C "$tdir" config user.email "test@example.com"
  git -C "$tdir" config commit.gpgsign false

  echo "base" > "${tdir}/README.md"
  git -C "$tdir" add README.md
  git -C "$tdir" commit -m "base" >/dev/null 2>&1
  git -C "$tdir" branch -M main

  git -C "$tdir" checkout -q -b feature/case

  IFS=',' read -r -a paths <<< "$changed_paths_csv"
  local p
  for p in "${paths[@]}"; do
    mkdir -p "${tdir}/$(dirname "$p")"
    echo "change-${p}" > "${tdir}/${p}"
    git -C "$tdir" add "$p"
  done
  git -C "$tdir" commit -m "change" >/dev/null 2>&1

  echo "$tdir"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: ${label}: expected='${expected}' actual='${actual}'" >&2
    exit 1
  fi
}

case_ihh="$(make_repo_case 'apps/ihh/service.txt')"
out_ihh="$(cd "$case_ihh" && resolve_promote_component 'main..HEAD')"
assert_eq "ihh" "$out_ihh" "apps/ihh/*"

case_pmbok="$(make_repo_case 'apps/pmbok/api.txt')"
out_pmbok="$(cd "$case_pmbok" && resolve_promote_component 'main..HEAD')"
assert_eq "pmbok" "$out_pmbok" "apps/pmbok/*"

case_devbox="$(make_repo_case '.devtools/config/apps.yaml')"
out_devbox="$(cd "$case_devbox" && resolve_promote_component 'main..HEAD')"
assert_eq "devbox" "$out_devbox" ".devtools/*"

case_mix="$(make_repo_case 'apps/ihh/a.txt,apps/pmbok/b.txt')"
out_mix="$(cd "$case_mix" && resolve_promote_component 'main..HEAD')"
assert_eq "ihh-ecosystem" "$out_mix" "mixed paths"

echo "OK: manual_common_resolve_component"

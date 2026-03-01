#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source=../lib/core/utils.sh
source "${ROOT_DIR}/lib/core/utils.sh"
# shellcheck source=../lib/core/git-ops.sh
source "${ROOT_DIR}/lib/core/git-ops.sh"
# shellcheck source=../lib/promote/workflows/to-local/30-git.sh
source "${ROOT_DIR}/lib/promote/workflows/to-local/30-git.sh"

# Case A: ff-only success
t1="$(mktemp -d)"
trap 'rm -rf "$t1"' EXIT

git -C "$t1" init -q
git -C "$t1" config user.name "Test Bot"
git -C "$t1" config user.email "test@example.com"
git -C "$t1" config commit.gpgsign false
echo base > "${t1}/f.txt"
git -C "$t1" add f.txt
git -C "$t1" commit -m "base" >/dev/null 2>&1
git -C "$t1" branch -M dev
git -C "$t1" checkout -q -b local
base_local="$(git -C "$t1" rev-parse HEAD)"
git -C "$t1" checkout -q dev
echo next >> "${t1}/f.txt"
git -C "$t1" add f.txt
git -C "$t1" commit -m "next" >/dev/null 2>&1
source_sha_ok="$(git -C "$t1" rev-parse HEAD)"

(
  cd "$t1"
  export DEVTOOLS_PROMOTE_STRATEGY=ff-only
  promote_local_apply_strategy_to_local_or_die "$source_sha_ok" local
  current_local="$(git rev-parse local)"
  [[ "$current_local" == "$source_sha_ok" ]] || { echo "FAIL: ff-only should move local to source" >&2; exit 1; }
)

# Case B: ff-only conflict returns rc=3 path
t2="$(mktemp -d)"
git -C "$t2" init -q
git -C "$t2" config user.name "Test Bot"
git -C "$t2" config user.email "test@example.com"
git -C "$t2" config commit.gpgsign false
echo base > "${t2}/f.txt"
git -C "$t2" add f.txt
git -C "$t2" commit -m "base" >/dev/null 2>&1
git -C "$t2" branch -M dev
git -C "$t2" checkout -q -b local
echo local > "${t2}/local.txt"
git -C "$t2" add local.txt
git -C "$t2" commit -m "local diverge" >/dev/null 2>&1
git -C "$t2" checkout -q dev
echo dev > "${t2}/dev.txt"
git -C "$t2" add dev.txt
git -C "$t2" commit -m "dev diverge" >/dev/null 2>&1
source_sha_conflict="$(git -C "$t2" rev-parse HEAD)"

set +e
(
  cd "$t2"
  unset DEVTOOLS_PROMOTE_STRATEGY
  export DEVTOOLS_NONINTERACTIVE=1
  promote_local_apply_strategy_to_local_or_die "$source_sha_conflict" local
) >/tmp/manual_local_apply_strategy_err.txt 2>&1
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "FAIL: ff-only conflict should fail in non-interactive mode" >&2
  cat /tmp/manual_local_apply_strategy_err.txt >&2
  exit 1
fi

grep -q "Fast-Forward NO es posible" /tmp/manual_local_apply_strategy_err.txt || {
  echo "FAIL: expected ff-only conflict message" >&2
  cat /tmp/manual_local_apply_strategy_err.txt >&2
  exit 1
}

echo "OK: manual_local_apply_strategy"

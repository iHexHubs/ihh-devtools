#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

tdir="$(mktemp -d)"
trap 'rm -rf "$tdir"' EXIT

remote_dir="${tdir}/remote.git"
repo_dir="${tdir}/repo"

git init -q --bare "$remote_dir"
git init -q "$repo_dir"
git -C "$repo_dir" config user.name "Test Bot"
git -C "$repo_dir" config user.email "test@example.com"
git -C "$repo_dir" config commit.gpgsign false
git -C "$repo_dir" remote add origin "$remote_dir"

echo "base" > "${repo_dir}/README.md"
git -C "$repo_dir" add README.md
git -C "$repo_dir" commit -m "base" >/dev/null 2>&1
git -C "$repo_dir" branch -M main
git -C "$repo_dir" push -u origin main >/dev/null 2>&1

git -C "$repo_dir" checkout -q -b feature/test
echo "feature" >> "${repo_dir}/README.md"
git -C "$repo_dir" add README.md
git -C "$repo_dir" commit -m "feature" >/dev/null 2>&1
git -C "$repo_dir" push -u origin feature/test >/dev/null 2>&1
git -C "$repo_dir" checkout -q main

cd "$repo_dir"

# shellcheck source=../lib/core/utils.sh
source "${ROOT_DIR}/lib/core/utils.sh"
# shellcheck source=../lib/promote/workflows/common.sh
source "${ROOT_DIR}/lib/promote/workflows/common.sh"

export DEVTOOLS_ASSUME_YES=1

# Case 1: explicit keep
export DEVTOOLS_PROMOTE_DELETE_SOURCE_BRANCH=0
maybe_delete_source_branch "feature/test"

git -C "$repo_dir" show-ref --verify --quiet refs/heads/feature/test || {
  echo "FAIL: feature/test should remain locally when delete flag=0" >&2
  exit 1
}

git -C "$repo_dir" ls-remote --exit-code --heads origin feature/test >/dev/null 2>&1 || {
  echo "FAIL: feature/test should remain remotely when delete flag=0" >&2
  exit 1
}

# Case 2: explicit delete
export DEVTOOLS_PROMOTE_DELETE_SOURCE_BRANCH=1
maybe_delete_source_branch "feature/test"

if git -C "$repo_dir" show-ref --verify --quiet refs/heads/feature/test; then
  echo "FAIL: feature/test should be deleted locally when delete flag=1" >&2
  exit 1
fi

if git -C "$repo_dir" ls-remote --exit-code --heads origin feature/test >/dev/null 2>&1; then
  echo "FAIL: feature/test should be deleted remotely when delete flag=1" >&2
  exit 1
fi

echo "OK: manual_common_delete_source_branch"

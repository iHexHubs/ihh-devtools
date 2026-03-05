#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

tdir="$(mktemp -d)"
trap 'rm -rf "$tdir"' EXIT

git -C "$tdir" init -q
git -C "$tdir" config user.name "Test Bot"
git -C "$tdir" config user.email "test@example.com"
git -C "$tdir" config commit.gpgsign false

echo base > "${tdir}/README.md"
git -C "$tdir" add README.md
git -C "$tdir" commit -m "base" >/dev/null 2>&1
git -C "$tdir" branch -M dev

git -C "$tdir" checkout -q -b feature/test
mkdir -p "${tdir}/apps/pmbok/backend"
echo change > "${tdir}/apps/pmbok/backend/x.txt"
git -C "$tdir" add apps/pmbok/backend/x.txt
git -C "$tdir" commit -m "backend change" >/dev/null 2>&1
source_sha="$(git -C "$tdir" rev-parse HEAD)"

# shellcheck source=../lib/core/utils.sh
source "${ROOT_DIR}/lib/core/utils.sh"
# to-local modules expect SCRIPT_DIR pointing to workflows root
SCRIPT_DIR="${ROOT_DIR}/lib/promote/workflows"
# shellcheck source=../lib/promote/workflows/to-local/20-ci-gate.sh
source "${ROOT_DIR}/lib/promote/workflows/to-local/20-ci-gate.sh"

out="$(cd "$tdir" && promote_local_detect_changes "dev" "$source_sha")"

echo "$out" | grep -q '^backend=1$' || { echo "FAIL: expected backend=1" >&2; exit 1; }
echo "$out" | grep -q '^frontend=0$' || { echo "FAIL: expected frontend=0" >&2; exit 1; }

echo "OK: manual_local_detect_changes"

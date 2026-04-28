#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/devbox-packages.bats
# Iteración: T-AMBOS-5 (2026-04-28)

setup() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd -P)"
}

@test "devbox.json no contiene argocd@latest" {
  run bash -lc 'cd "$REPO_ROOT" && ! grep -q "\"argocd@latest\"" devbox.json'
  [ "$status" -eq 0 ]
}

@test "devbox.lock no contiene argocd@latest" {
  run bash -lc 'cd "$REPO_ROOT" && ! grep -q "\"argocd@latest\"" devbox.lock'
  [ "$status" -eq 0 ]
}

@test "devbox.lock contiene pin argocd@3.1.9" {
  run bash -lc 'cd "$REPO_ROOT" && grep -q "\"argocd@3.1.9\"" devbox.lock'
  [ "$status" -eq 0 ]
}

@test "workflows/scripts no usan devbox update" {
  run bash -lc 'cd "$REPO_ROOT" && ! rg -n "\\bdevbox update\\b" .github scripts bin lib >/tmp/devbox_update_refs.log 2>&1'
  [ "$status" -eq 0 ]
}

@test "lock sync: devbox install no modifica devbox.json/devbox.lock" {
  run bash -lc '
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap "rm -rf \"$tmp\"" EXIT
    cd "$tmp"

    cp "$REPO_ROOT/devbox.json" .
    cp "$REPO_ROOT/devbox.lock" .

    git init -b main >/dev/null
    git config user.email "tests@example.com"
    git config user.name "Test Runner"
    git add devbox.json devbox.lock
    git commit -m "fixture" >/dev/null

    DEVTOOLS_SKIP_WIZARD=1 DEVTOOLS_NONINTERACTIVE=1 devbox install >/tmp/devbox_lock_sync_install.log 2>&1
    git diff --exit-code -- devbox.json devbox.lock
  '
  [ "$status" -eq 0 ]
}

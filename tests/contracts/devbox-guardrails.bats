#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/devbox-guardrails.bats
# Iteración: T-AMBOS-5 (2026-04-28)

# tests/devbox-guardrails.bats
#
# Guardrails para evitar drift de Devbox:
# - Nunca permitir argocd@latest
# - Exigir pin explícito argocd@3.1.9 en json+lock
# - Evitar devbox update en scripts/CI (solo manual)

setup() {
  set -euo pipefail
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd -P)"
}

@test "devbox.json no contiene argocd@latest" {
  run bash -lc "
    set -euo pipefail
    ! rg -n 'argocd@latest' '$REPO_ROOT/devbox.json'
  "
  [ "$status" -eq 0 ]
}

@test "devbox.lock no contiene argocd@latest" {
  run bash -lc "
    set -euo pipefail
    ! rg -n 'argocd@latest' '$REPO_ROOT/devbox.lock'
  "
  [ "$status" -eq 0 ]
}

@test "argocd está pinneado a 3.1.9 en devbox.json y devbox.lock" {
  run bash -lc "
    set -euo pipefail
    rg -n 'argocd@3\\.1\\.9' '$REPO_ROOT/devbox.json' '$REPO_ROOT/devbox.lock'
  "
  [ "$status" -eq 0 ]
}

@test "scripts/CI no usan devbox update" {
  run bash -lc "
    set -euo pipefail
    if rg -n 'devbox update' '$REPO_ROOT/.github' '$REPO_ROOT/devops' '$REPO_ROOT/scripts' '$REPO_ROOT'/'Taskfile'* 2>/dev/null; then
      exit 1
    fi
  "
  [ "$status" -eq 0 ]
}

@test "lock sync: devbox install mantiene devbox.lock estable" {
  run bash -lc "
    set -euo pipefail
    tmp=\$(mktemp -d)
    cp '$REPO_ROOT/devbox.json' '$REPO_ROOT/devbox.lock' \"\$tmp/\"
    before=\$(sha256sum \"\$tmp/devbox.lock\" | awk '{print \$1}')
    cd \"\$tmp\"
    DEVTOOLS_SKIP_WIZARD=1 DEVTOOLS_NONINTERACTIVE=1 devbox install >/dev/null
    after=\$(sha256sum \"\$tmp/devbox.lock\" | awk '{print \$1}')
    [ \"\$before\" = \"\$after\" ]
  "
  [ "$status" -eq 0 ]
}

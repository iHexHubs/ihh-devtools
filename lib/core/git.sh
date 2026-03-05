#!/usr/bin/env bash

resolve_repo_root_or_die() {
  local root=""
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    if declare -F die >/dev/null 2>&1; then
      die "Debes ejecutar este comando dentro de un repositorio Git."
    fi
    echo "ERROR: Debes ejecutar este comando dentro de un repositorio Git." >&2
    return 1
  }
  printf '%s\n' "$root"
}

resolve_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

resolve_workspace_root() {
  git rev-parse --show-superproject-working-tree 2>/dev/null || true
}

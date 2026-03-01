#!/usr/bin/env bash

resolve_repo_root_or_die() {
  git rev-parse --show-toplevel 2>/dev/null || die "Debes ejecutar este comando dentro de un repositorio Git."
}

resolve_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

resolve_workspace_root() {
  git rev-parse --show-superproject-working-tree 2>/dev/null || true
}

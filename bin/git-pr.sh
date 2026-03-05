#!/usr/bin/env bash
set -euo pipefail
# Crea o abre PR de la rama actual.
BASE="${BASE_BRANCH:-${PR_BASE_BRANCH:-dev}}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "❌ Debes ejecutar esto dentro de un repositorio Git."; exit 1; }

branch="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  echo "❌ HEAD desacoplado. No puedo abrir PR."
  exit 1
fi

# CAMBIO FASE 1.3: Permitir fix/ y hotfix/ además de feature/
if [[ "$branch" != feature/* && "$branch" != fix/* && "$branch" != hotfix/* ]]; then
  echo "❌ Política de PR: solo desde feature/**, fix/** o hotfix/**"
  echo "   Rama actual: $branch"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ℹ️  'gh' no está disponible; skipping PR."
  exit 0
fi

if ! GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "ℹ️  'gh' no autenticado; skipping PR."
  exit 0
fi

# Si no hay PR abierto, créalo; si existe, muéstralo
pr_json="$(
  GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 \
    gh pr list --state open --head "$branch" --base "$BASE" --json number 2>/dev/null || true
)"
count="$(printf '%s\n' "$pr_json" | awk '/"number"[[:space:]]*:/ {c++} END{print c+0}')"
if [[ "$count" == "0" ]]; then
  echo "🚀 Creando PR: $branch -> $BASE"
  GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 GIT_TERMINAL_PROMPT=0 \
    gh pr create --base "$BASE" --head "$branch" --fill || {
      echo "ℹ️  No pude crear PR (posible falta de permisos/remoto/push). Skipping."
      exit 0
    }
else
  echo "🟢 Ya existe PR abierto para $branch -> $BASE"
  GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 \
    gh pr list --state open --head "$branch" --base "$BASE"
fi

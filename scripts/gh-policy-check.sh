#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if ! command -v grep >/dev/null 2>&1; then
  echo "❌ grep no esta instalado."
  exit 1
fi

# Patrones prohibidos en workflows
PATTERN='release-please|git tag|push --tags|create-release'

# ✅ Lista blanca: permitimos únicamente el prefijo de rama del bot:
#   release-please--*
# (Esto evita falsos positivos por checks de ramas, sin permitir el action "release-please" en general.)
ALLOWLIST_RE='release-please--'

mapfile -d '' files < <(
  find "$ROOT" -type f \
    \( -path '*/.github/workflows/*.yml' -o -path '*/.github/workflows/*.yaml' \) \
    ! -name '*.disabled' \
    ! -path '*/_legacy/*' \
    ! -path '*/.terraform/*' \
    -print0
)

if [ "${#files[@]}" -eq 0 ]; then
  echo "✅ Policy OK: no se encontraron workflows para revisar."
  exit 0
fi

# Buscar matches prohibidos
matches="$(grep -nE "$PATTERN" "${files[@]}" || true)"

# Filtrar falsos positivos permitidos por allowlist
if [ -n "$matches" ]; then
  matches="$(printf '%s\n' "$matches" | grep -vE "$ALLOWLIST_RE" || true)"
fi

if [ -n "$matches" ]; then
  echo "❌ Policy violada: se detectaron patrones prohibidos en workflows de GitHub."
  echo
  echo "$matches"
  exit 1
fi

echo "✅ Policy OK: no se detectaron patrones prohibidos en workflows."

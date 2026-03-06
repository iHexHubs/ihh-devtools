#!/usr/bin/env bash
set -euo pipefail
# ==============================================================================
# Script: gh-policy-check.sh
#
# DESCRIPCIÓN (Qué hace):
# Escanea todos los archivos de GitHub Actions (.yml o .yaml) del repositorio 
# en busca de patrones de texto prohibidos (como 'release-please', 'git tag', 
# 'push --tags' o 'create-release'). Filtra los falsos positivos permitiendo 
# explícitamente el prefijo de ramas de bots ('release-please--').
#
# PROPÓSITO (Para qué sirve):
# Sirve como una barrera de seguridad y cumplimiento normativo (compliance). 
# Evita que los desarrolladores automaticen la creación de versiones (releases) 
# o etiquetas (tags) directamente desde sus workflows individuales. Garantiza 
# que todo el equipo utilice un proceso de lanzamiento centralizado, seguro 
# y estandarizado por la organización.
# ==============================================================================

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

#!/usr/bin/env bash
# Crea o actualiza release draft para un tag existente.
set -euo pipefail

# Crea o actualiza un Release draft en GitHub para un tag existente.
# Uso:
#   git-release-draft.sh TAG=v1.2.3 [--notes archivo.md]

TAG=""
NOTES_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    TAG=*)
      TAG="${1#TAG=}"
      shift
      ;;
    --notes=*)
      NOTES_FILE="${1#--notes=}"
      shift
      ;;
    --notes)
      shift
      if [[ $# -eq 0 ]]; then
        echo "❌ Falta el archivo de notas despues de --notes"
        exit 1
      fi
      NOTES_FILE="$1"
      shift
      ;;
    *)
      if [[ -z "$TAG" ]]; then
        TAG="$1"
        shift
      else
        echo "❌ Argumento desconocido: $1"
        exit 1
      fi
      ;;
  esac
done

TAG="$(echo "$TAG" | tr -d '[:space:]')"

if [[ -z "$TAG" ]]; then
  echo "❌ Debes indicar TAG=..."
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ 'gh' no esta instalado."
  exit 1
fi

if ! GH_PAGER=cat gh auth status -t >/dev/null 2>&1; then
  echo "❌ gh no autenticado. Ejecuta 'gh auth login' y reintenta."
  exit 1
fi

notes_args=()
if [[ -n "$NOTES_FILE" ]]; then
  if [[ ! -f "$NOTES_FILE" ]]; then
    echo "❌ El archivo de notas no existe: $NOTES_FILE"
    exit 1
  fi
  notes_args+=(--notes-file "$NOTES_FILE")
else
  notes_args+=(--notes " ")
fi

# Si existe, lo actualizamos como draft. Si no, lo creamos como draft.
if GH_PAGER=cat gh release view "$TAG" >/dev/null 2>&1; then
  echo "ℹ️  Release existe. Actualizando como draft: $TAG"
  GH_PAGER=cat gh release edit "$TAG" --draft "${notes_args[@]}" >/dev/null
else
  echo "✅ Creando release draft: $TAG"
  GH_PAGER=cat gh release create "$TAG" --draft --title "$TAG" "${notes_args[@]}" >/dev/null
fi

echo "✅ Release draft listo: $TAG"

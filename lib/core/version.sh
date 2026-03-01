#!/usr/bin/env bash
# .devtools/lib/core/version.sh
# Antes: este archivo contenía solo texto plano (ej: "0.1.0") y no era un script válido.
# Ahora: expone una forma consistente de obtener la versión sin romper compatibilidad.
# - Si existe un VERSION en el repo, lo usa.
# - Si no, cae a un valor por defecto seguro.
#
# Nota: evitamos `set -euo pipefail` porque este archivo podría ser "source" y no debe
# alterar el modo del caller.

devtools_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

devtools_read_version_file() {
  local root="$1"
  local f=""
  for f in "$root/VERSION" "$root/.devtools/VERSION"; do
    if [[ -f "$f" ]]; then
      # Primera línea, sin espacios/saltos
      sed -n '1p' "$f" | tr -d ' \t\r\n'
      return 0
    fi
  done
  return 1
}

devtools_version() {
  local root v
  root="$(devtools_repo_root)"
  v="$(devtools_read_version_file "$root" 2>/dev/null || true)"
  [[ -n "${v:-}" ]] || v="0.1.0"
  echo "$v"
}

# Si se ejecuta, imprime versión. Si se "sourcea", exporta DEVTOOLS_VERSION.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  devtools_version
else
  DEVTOOLS_VERSION="$(devtools_version)"
  export DEVTOOLS_VERSION
fi

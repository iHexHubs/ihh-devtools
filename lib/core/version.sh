#!/usr/bin/env bash
# Helpers para obtener la version del repo (contrato-first).
#
# Orden:
# 1) <repo>/VERSION
# 2) <repo>/<vendor_dir>/VERSION        (vendor_dir via contrato; default ".devtools")
# 3) Compat legacy: <repo>/<dot_dir>/VERSION (solo por repos antiguos)

# Nota: evitamos `set -euo pipefail` porque este archivo puede ser "source"
# y no debe alterar el modo del caller.

__devtools_core_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./contract.sh
source "${__devtools_core_dir}/contract.sh"

devtools_read_version_file() {
  local root="$1"
  local vendor_dir=""
  local dot_dir=".devtools"
  local f=""

  vendor_dir="$(devtools_vendor_dir "$root" 2>/dev/null || echo ".devtools")"
  vendor_dir="${vendor_dir#./}"
  vendor_dir="${vendor_dir%/}"

  for f in \
    "$root/VERSION" \
    "$root/${vendor_dir}/VERSION" \
    "$root/${dot_dir}/VERSION"
  do
    if [[ -f "$f" ]]; then
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

# Si se ejecuta, imprime version. Si se "sourcea", exporta DEVTOOLS_VERSION.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  devtools_version
else
  DEVTOOLS_VERSION="$(devtools_version)"
  export DEVTOOLS_VERSION
fi

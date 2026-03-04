#!/usr/bin/env bash
# Shim de compatibilidad para tests/scripts legados.
__lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__core_utils="${__lib_dir}/core/utils.sh"
if [[ -f "${__core_utils}" ]]; then
  # shellcheck source=./core/utils.sh
  source "${__core_utils}"
else
  echo "ERROR: falta lib/core/utils.sh (este build no incluye core utils)." >&2
  return 1 2>/dev/null || exit 1
fi

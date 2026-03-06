#!/usr/bin/env bash
set -euo pipefail
# ==============================================================================
# Script: vendorize.sh
#
# DESCRIPCIÓN (Qué hace):
# Verifica la existencia de rutas críticas dentro del repositorio, 
# específicamente el ejecutable 'bin/devtools' y el directorio 'lib'.
# Si alguna de estas rutas falta, el script aborta la ejecución con un error.
#
# PROPÓSITO (Para qué sirve):
# Actúa como un chequeo de pre-requisitos o "contrato de integridad". 
# Sirve para garantizar que la estructura básica y las herramientas necesarias 
# del proyecto están intactas antes de iniciar un proceso de empaquetado 
# (vendoring), compilación o despliegue. Esto evita que los procesos 
# posteriores fallen de manera impredecible por falta de dependencias.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

required_paths=(
  "${ROOT_DIR}/bin/devtools"
  "${ROOT_DIR}/lib"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "ERROR: missing required path for vendoring contract: $path" >&2
    exit 1
  fi
done

echo "OK: vendorize placeholder passed (required paths exist)."

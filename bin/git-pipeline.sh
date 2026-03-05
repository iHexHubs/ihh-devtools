#!/usr/bin/env bash
# Ejecuta el pipeline local detectado para el repo actual.
set -euo pipefail

# Bootstrap
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
source "${LIB_DIR}/core/utils.sh"
# No cargamos config.sh entero para evitar logs innecesarios,
# pero cargamos el workflow que tiene la lógica de detección.
source "${LIB_DIR}/ci-workflow.sh"

echo "🚀 Iniciando Pipeline Local (via Git)..."

# Asegurar detección
if declare -F detect_ci_tools >/dev/null 2>&1; then
  detect_ci_tools
else
  log_error "No está disponible detect_ci_tools (revisa ci-workflow.sh)."
  exit 1
fi

# CAMBIO FASE 1.1: Usar K8S_FULL_CMD en lugar de LOCAL_PIPELINE_CMD
if [[ -n "${K8S_FULL_CMD:-}" ]]; then
  echo "▶️  Ejecutando: $K8S_FULL_CMD"
  # Usamos eval para permitir comandos compuestos (ej. "task build && task deploy")
  eval "$K8S_FULL_CMD"
else
  log_error "No se detectó un comando de pipeline local."
  echo "   Define una tarea 'pipeline:local' (si usas Taskfile) o configura el contrato de CI."
  exit 1
fi

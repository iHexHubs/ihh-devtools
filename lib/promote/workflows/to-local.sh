#!/usr/bin/env bash
# Promote workflow: to-local
# Flujo LOCAL:
# - Gate (task ci + task ci:act)
# - Calcular tag local (rev.N sobre el ultimo tag dev)
# - Build solo lo que cambio; retag en minikube para lo demas
# - Actualizar overlay local y push a rama "local"..

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/00-env.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/10-utils.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/20-ci-gate.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/30-git.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/40-build.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/50-k8s.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/60-argocd.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/to-local/90-main.sh"

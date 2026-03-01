#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Delega a la implementación real de promote local (sin reimplementar bootstrap).
source "${REPO_ROOT}/lib/core/utils.sh"
source "${REPO_ROOT}/lib/promote/workflows/to-local/10-utils.sh"
source "${REPO_ROOT}/lib/promote/workflows/to-local/50-k8s.sh"
source "${REPO_ROOT}/lib/promote/workflows/to-local/60-argocd.sh"

REVISION="${1:-local}"
APP_NAME="${DEVTOOLS_ARGOCD_APP_LOCAL:-devbox-app}"
APP_FILE="${REPO_ROOT}/devbox-app/gitops/argocd/application.yaml"

main() {
    local runtime=""

    # 1) Runtime/cluster por contrato existente del toolset.
    promote_local_ensure_cluster_runtime runtime
    promote_local_guard_runtime_matches_kubectl_context_or_die "${runtime}"
    log_info "Bootstrap delegado: runtime local = ${runtime}"

    # 2) Si existe contrato task cluster:up, delega ahí.
    if command -v task >/dev/null 2>&1 && task_exists "cluster:up"; then
        log_info "Delegando bootstrap de cluster al contrato existente: task cluster:up"
        run_cmd "task cluster:up"
    else
        log_warn "No existe task cluster:up; continúo con validaciones/sync existentes."
    fi

    # 3) App manifest (idempotente). No instala ArgoCD: solo usa recursos existentes.
    if command -v kubectl >/dev/null 2>&1 && [[ -f "${APP_FILE}" ]]; then
        run_cmd "kubectl apply -f ${APP_FILE}"
    else
        log_warn "Omito apply de Application (kubectl o manifest no disponibles)."
    fi

    # 4) Delega preflight/sync al módulo existente de ArgoCD.
    promote_local_preflight_argocd_or_die "${APP_NAME}"
    promote_local_argocd_sync_by_tag_or_die "${REVISION}" "${APP_NAME}" "${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}"

    log_success "✅ Bootstrap delegado completado: app=${APP_NAME} revision=${REVISION}"
}

main "$@"

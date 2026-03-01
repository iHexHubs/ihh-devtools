#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_argocd_wait_healthy_or_die() {
    local strict="${DEVTOOLS_E2E_ARGOCD_STRICT:-0}"
    local namespace="${DEVTOOLS_ARGOCD_NAMESPACE:-argocd}"
    local timeout="${DEVTOOLS_ARGOCD_WAIT_SECS:-300}"
    local poll="${DEVTOOLS_ARGOCD_POLL_SECS:-5}"

    promote_local_argocd_warn_or_die() {
        local message="$1"
        if [[ "${strict}" == "1" ]]; then
            die "${message}"
        fi
        log_warn "${message}"
        return 0
    }

    if ! command -v kubectl >/dev/null 2>&1; then
        promote_local_argocd_warn_or_die "ArgoCD E2E omitido: no existe 'kubectl'. Define DEVTOOLS_E2E_ARGOCD_STRICT=1 para exigirlo."
        return 0
    fi

    if [[ ! "${timeout}" =~ ^[0-9]+$ ]] || (( timeout <= 0 )); then
        timeout=300
    fi
    if [[ ! "${poll}" =~ ^[0-9]+$ ]] || (( poll <= 0 )); then
        poll=5
    fi

    if ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
        promote_local_argocd_warn_or_die "ArgoCD E2E omitido: no existe CRD applications.argoproj.io. Define DEVTOOLS_E2E_ARGOCD_STRICT=1 para exigirlo."
        return 0
    fi

    local app_list=""
    local app_list_rc=0
    app_list="$(kubectl -n "${namespace}" get applications.argoproj.io -o name 2>/dev/null)" || app_list_rc=$?
    if [[ "$app_list_rc" -ne 0 ]]; then
        promote_local_argocd_warn_or_die "ArgoCD E2E no verificable: no pude listar Applications en namespace '${namespace}'. Define DEVTOOLS_E2E_ARGOCD_STRICT=1 para exigirlo."
        return 0
    fi
    if [[ -z "${app_list:-}" ]]; then
        promote_local_argocd_warn_or_die "ArgoCD E2E omitido: no hay Applications en namespace '${namespace}'. Define DEVTOOLS_E2E_ARGOCD_STRICT=1 para exigirlo."
        return 0
    fi

    local deadline=$((SECONDS + timeout))
    local pending_summary=""
    while (( SECONDS <= deadline )); do
        pending_summary=""
        local app=""
        while IFS= read -r app; do
            [[ -n "${app:-}" ]] || continue
            local sync_status=""
            local health_status=""
            sync_status="$(kubectl -n "${namespace}" get "${app}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
            health_status="$(kubectl -n "${namespace}" get "${app}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
            if [[ "${sync_status:-}" != "Synced" || "${health_status:-}" != "Healthy" ]]; then
                pending_summary+="${app}(${sync_status:-Unknown}/${health_status:-Unknown}) "
            fi
        done <<< "$app_list"

        if [[ -z "${pending_summary:-}" ]]; then
            log_info "ArgoCD E2E OK: Applications en '${namespace}' están Synced/Healthy."
            return 0
        fi

        sleep "$poll"
    done

    promote_local_argocd_warn_or_die "ArgoCD E2E falló por timeout (${timeout}s). Estado pendiente: ${pending_summary}"
    return 0
}



promote_local_report_pull_errors_or_die() {
    local expected_tag="${1:-}"
    local namespace="default"
    local rollout_timeout="${DEVTOOLS_LOCAL_ROLLOUT_TIMEOUT:-180s}"
    local strict="${DEVTOOLS_E2E_ARGOCD_STRICT:-0}"

    if ! command -v kubectl >/dev/null 2>&1; then
        log_warn "No existe kubectl; omito diagnóstico de errores de pod post-sync."
        return 0
    fi

    local has_failure=0
    local dep=""
    for dep in local-pmbok-backend-deployment local-pmbok-frontend-deployment local-postgres-db; do
        if ! kubectl -n "${namespace}" get deploy "${dep}" >/dev/null 2>&1; then
            continue
        fi
        if ! kubectl -n "${namespace}" rollout status "deploy/${dep}" --timeout="${rollout_timeout}" >/dev/null 2>&1; then
            log_error "Rollout no saludable: deploy/${dep} (timeout=${rollout_timeout})."
            has_failure=1
        fi
    done

    if [[ -n "${expected_tag:-}" ]]; then
        local backend_applied=""
        local frontend_applied=""
        backend_applied="$(kubectl -n "${namespace}" get deploy local-pmbok-backend-deployment -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null | awk '{print $1}')"
        frontend_applied="$(kubectl -n "${namespace}" get deploy local-pmbok-frontend-deployment -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null | awk '{print $1}')"
        if [[ -n "${backend_applied:-}" && "${backend_applied}" != *":${expected_tag}" ]]; then
            log_error "Tag aplicado backend no coincide: ${backend_applied} (esperado *:${expected_tag})."
            has_failure=1
        fi
        if [[ -n "${frontend_applied:-}" && "${frontend_applied}" != *":${expected_tag}" ]]; then
            log_error "Tag aplicado frontend no coincide: ${frontend_applied} (esperado *:${expected_tag})."
            has_failure=1
        fi
    fi

    local failing_pods=""
    failing_pods="$(kubectl -n "${namespace}" get pods --no-headers 2>/dev/null \
        | awk '$3 == "ImagePullBackOff" || $3 == "ErrImagePull" || $3 == "CrashLoopBackOff" || $3 == "CreateContainerConfigError" { print $1" "$3 }')"
    [[ -z "${failing_pods:-}" ]] || has_failure=1

    if [[ "$has_failure" -eq 0 ]]; then
        return 0
    fi

    log_error "Detecté errores post-sync en workloads/pods."
    kubectl -n "${namespace}" get pods -o wide 2>/dev/null || true

    local described=0
    local pod="" status=""
    while IFS=' ' read -r pod status; do
        [[ -n "${pod:-}" ]] || continue
        if (( described >= 4 )); then
            break
        fi
        described=$((described + 1))
        echo "---- describe pod ${namespace}/${pod} (${status:-unknown}) ----"
        kubectl -n "${namespace}" describe pod "${pod}" 2>/dev/null \
            | grep -E 'Image:|Reason:|Back-off|Failed|Pulling|ErrImagePull|ImagePullBackOff|CrashLoop|CreateContainerConfigError' \
            | tail -n 40 || true
    done <<< "${failing_pods}"

    echo "---- eventos recientes (${namespace}) ----"
    kubectl -n "${namespace}" get events --sort-by=.lastTimestamp 2>/dev/null | tail -n 60 || true

    if [[ "${strict}" == "1" ]]; then
        die "Errores post-sync detectados (ImagePullBackOff/ErrImagePull/CrashLoopBackOff/CreateContainerConfigError)."
    fi
    log_warn "Post-sync con errores de pods/imagenes; continúo porque DEVTOOLS_E2E_ARGOCD_STRICT!=1."
    return 1
}



promote_local_preflight_argocd_or_die() {
    local app="${1:-pmbok-backend-app}"
    local namespace="${DEVTOOLS_ARGOCD_NAMESPACE:-argocd}"

    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "❌ Kubernetes CLI no disponible. Instala kubectl para configurar ArgoCD local."
        return 2
    fi

    if ! kubectl -n "${namespace}" get application "${app}" >/dev/null 2>&1; then
        log_error "❌ ArgoCD app no disponible (${namespace}/${app}). Ejecuta: task cluster:up"
        return 2
    fi

    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warn "⚠️ Kubernetes/cluster no verificable desde kubectl (continuo por modo local)."
    fi

    if command -v argocd >/dev/null 2>&1; then
        log_info "✅ Preflight ArgoCD OK (CLI directa)."
        return 0
    fi

    if command -v devbox >/dev/null 2>&1; then
        if devbox run -- argocd version --client >/dev/null 2>&1; then
            log_info "✅ Preflight ArgoCD OK (CLI vía devbox run)."
            return 0
        fi
    fi

    log_warn "⚠️ ArgoCD CLI no disponible. Continuaré en modo kubectl (configuración idempotente + auto-sync)."
    return 0
}



promote_local_argocd_sync_by_tag_or_die() {
    local revision="${1:-}"
    local app="${2:-pmbok-backend-app}"
    local timeout="${3:-${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}}"
    local namespace="${DEVTOOLS_ARGOCD_NAMESPACE:-argocd}"
    local strict="${DEVTOOLS_E2E_ARGOCD_STRICT:-0}"

    # Estado observable por el caller para evitar "sync falso".
    PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED=0

    promote_local_argocd_cli() {
        if command -v argocd >/dev/null 2>&1; then
            argocd "$@"
            return $?
        fi
        if command -v devbox >/dev/null 2>&1; then
            devbox run -- argocd "$@"
            return $?
        fi
        return 127
    }

    promote_local_argocd_sync_via_kubectl_or_die() {
        local rev="$1"
        local app_name="$2"
        local ns="$3"
        local wait_secs="$4"
        local poll_secs="${DEVTOOLS_ARGOCD_POLL_SECS:-5}"

        if [[ ! "${wait_secs}" =~ ^[0-9]+$ ]] || (( wait_secs <= 0 )); then
            wait_secs=300
        fi
        if [[ ! "${poll_secs}" =~ ^[0-9]+$ ]] || (( poll_secs <= 0 )); then
            poll_secs=5
        fi

        if ! kubectl -n "$ns" patch application "$app_name" --type merge \
            -p "{\"operation\":{\"sync\":{\"revision\":\"${rev}\",\"prune\":true}}}" >/dev/null 2>&1; then
            return 1
        fi

        local deadline=$((SECONDS + wait_secs))
        while (( SECONDS <= deadline )); do
            local sync_status=""
            local health_status=""
            local phase=""
            local op_message=""
            local op_revision=""

            sync_status="$(kubectl -n "$ns" get application "$app_name" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
            health_status="$(kubectl -n "$ns" get application "$app_name" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
            phase="$(kubectl -n "$ns" get application "$app_name" -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)"
            op_message="$(kubectl -n "$ns" get application "$app_name" -o jsonpath='{.status.operationState.message}' 2>/dev/null || true)"
            op_revision="$(kubectl -n "$ns" get application "$app_name" -o jsonpath='{.status.operationState.operation.sync.revision}' 2>/dev/null || true)"

            if [[ "${phase:-}" == "Failed" || "${phase:-}" == "Error" ]]; then
                log_error "❌ ArgoCD sync por kubectl falló (${ns}/${app_name}, phase=${phase}): ${op_message:-sin mensaje}."
                return 1
            fi

            # Evita falso positivo: exigimos que la operación explícita haya terminado.
            if [[ "${phase:-}" == "Succeeded" && "${sync_status:-}" == "Synced" && "${health_status:-}" == "Healthy" ]]; then
                if [[ -n "${op_revision:-}" && "${op_revision}" != "${rev}" ]]; then
                    sleep "$poll_secs"
                    continue
                fi
                return 0
            fi

            sleep "$poll_secs"
        done

        log_error "❌ Timeout esperando sync por kubectl (${wait_secs}s) en ${ns}/${app_name}."
        return 1
    }

    promote_local_argocd_ensure_config_or_die() {
        local rev="$1"
        local app_name="$2"
        local ns="${DEVTOOLS_ARGOCD_NAMESPACE:-argocd}"

        kubectl -n "$ns" get application "$app_name" >/dev/null 2>&1 || {
            log_error "❌ No existe Application '${ns}/${app_name}'. Ejecuta: task cluster:up"
            return 2
        }

        kubectl -n "$ns" patch application "$app_name" --type merge \
            -p "{\"spec\":{\"source\":{\"targetRevision\":\"${rev}\"}}}" >/dev/null || {
            log_error "❌ No pude actualizar targetRevision en ${ns}/${app_name}."
            return 2
        }

        kubectl -n "$ns" patch application "$app_name" --type merge \
            -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null || {
            log_error "❌ No pude activar auto-sync en ${ns}/${app_name}."
            return 2
        }

        kubectl -n "$ns" annotate application "$app_name" argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
        return 0
    }

    [[ -n "${revision:-}" ]] || { log_error "❌ Revision GitOps vacía para sync ArgoCD."; return 2; }
    promote_local_is_valid_tag_name "${revision}" || {
        log_error "❌ Revision GitOps inválida '${revision}'. Permitidos: [0-9A-Za-z._+-]"
        return 2
    }
    if [[ ! "${revision}" =~ -rev\.([0-9]+)$ ]]; then
        log_error "❌ Guardrail: targetRevision debe terminar en '-rev.N' (recibido: ${revision})."
        return 2
    fi

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        local remote_tag_ok=0
        if declare -F promote_local_remote_tag_exists >/dev/null 2>&1; then
            if promote_local_remote_tag_exists "${revision}"; then
                remote_tag_ok=1
            fi
        fi
        if [[ "${remote_tag_ok}" == "1" ]]; then
            log_warn "⚗️ DRY-RUN: omito ArgoCD patch/sync; tag remoto confirmado (${revision})."
        else
            log_warn "⚗️ DRY-RUN: omito ArgoCD patch/sync; no confirmé tag remoto (${revision})."
        fi
        PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED=1
        return 0
    fi

    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "❌ Kubernetes CLI no disponible. Instala kubectl para sincronizar ArgoCD local."
        return 2
    fi

    if ! promote_local_ensure_remote_tag_or_die "${revision}" ""; then
        log_error "❌ Guardrail: el tag remoto requerido para ArgoCD no existe/publica correctamente: ${revision}."
        return 2
    fi

    if ! promote_local_argocd_ensure_config_or_die "$revision" "$app"; then
        return 2
    fi

    log_info "ArgoCD: revision configurada ${app} -> ${revision} (auto-sync habilitado)."

    if promote_local_argocd_cli --core app sync "$app"; then
        if ! promote_local_argocd_cli --core app wait "$app" --timeout "${timeout}" --health --sync; then
            log_error "❌ ArgoCD falló. Ejecuta: argocd --core app wait ${app} --timeout ${timeout} --health --sync"
            return 2
        fi
        log_success "ArgoCD: sync ${app} OK"
        return 0
    fi

    log_warn "ArgoCD CLI (--core) falló; intento fallback por kubectl en ${namespace}/${app}."
    if promote_local_argocd_sync_via_kubectl_or_die "$revision" "$app" "$namespace" "$timeout"; then
        log_success "ArgoCD: sync ${app} OK (fallback kubectl)"
        PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED=0
        return 0
    fi

    PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED=1
    if [[ "${strict}" == "1" ]]; then
        log_error "❌ ArgoCD CLI no disponible o falló el sync explícito (argocd_sync_skipped=1, strict=1)."
        return 2
    fi

    local applied_revision=""
    applied_revision="$(kubectl -n "$namespace" get application "$app" -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || true)"
    if [[ "${applied_revision:-}" == "${revision}" ]]; then
        log_warn "⚠️ ArgoCD sync omitido (argocd_sync_skipped=1). Queda targetRevision='${revision}' con auto-sync en ${namespace}/${app}."
    else
        log_warn "⚠️ ArgoCD sync omitido (argocd_sync_skipped=1). No pude confirmar targetRevision='${revision}' en ${namespace}/${app}."
    fi
    return 0
}



promote_local_argocd_revision_best_effort() {
    local app="${1:-pmbok-backend-app}"
    local namespace="${DEVTOOLS_ARGOCD_NAMESPACE:-argocd}"
    local rev=""

    if ! command -v kubectl >/dev/null 2>&1; then
        printf '%s\n' ""
        return 0
    fi

    rev="$(kubectl -n "${namespace}" get application "${app}" -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || true)"
    printf '%s\n' "${rev:-}"
    return 0
}

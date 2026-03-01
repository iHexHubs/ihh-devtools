#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/promote/strategies/dev-direct.sh
#
# Estrategia de promoción DIRECTA a DEV (opt-in / macro).
# Objetivo: usar SIEMPRE el "Jefe de Obra" (update_branch_to_sha_with_strategy)
# para heredar: fetch/reset canónico, push --force-with-lease y post-checks.
#
# Dependencias esperadas:
# - utils.sh, git-ops.sh (cargadas por el orquestador)
# - helpers/gh-interactions.sh (para __remote_head_sha, __watch_workflow_success..., etc.)

# ------------------------------------------------------------------------------
# Monitor: Post-Push Directo
# ------------------------------------------------------------------------------
promote_dev_direct_monitor() {
    # Args: pre_bot_sha (sha del push directo a dev), feature_branch (informativo)
    local pre_bot_sha="${1:-}"
    local feature_branch="${2:-}"

    [[ -n "${pre_bot_sha:-}" ]] || { log_error "dev-direct-monitor: falta SHA."; return 1; }

    log_info "🧠 DEV monitor (direct) iniciado (sha=${pre_bot_sha:0:7}${feature_branch:+, branch=$feature_branch})"

    # 1. Versionado (Bot) - Estado 2
    local rp_pr=""
    local rp_merge_sha=""
    local post_rp=0

    if repo_has_workflow_file "release-please"; then
        log_info "🤖 Release Please detectado. Esperando ejecución en GitHub Actions..."
        __watch_workflow_success_on_sha_or_die "release-please.yaml" "$pre_bot_sha" "dev" "Release Please" || return 1

        log_info "🤖 Verificando si el bot creó un PR de release..."
        rp_pr="$(wait_for_release_please_pr_number_optional || true)"

        if [[ "${rp_pr:-}" =~ ^[0-9]+$ ]]; then
            post_rp=1
            log_info "🤖 PR del bot detectado (#$rp_pr). Procesando..."

            # Merge sin borrar rama (la limpieza ocurre en promote staging)
            GH_PAGER=cat gh pr merge "$rp_pr" --auto --squash

            log_info "🔄 Esperando merge del PR del bot #$rp_pr..."
            rp_merge_sha="$(wait_for_pr_merge_and_get_sha "$rp_pr")"
            log_success "✅ PR bot mergeado. Nuevo SHA: ${rp_merge_sha:0:7}"

            log_info "ℹ️  La rama release-please--* se conserva hasta la promoción a Staging."
        else
            log_success "✅ Sin versionado pendiente (Bot no creó PR o no hay cambios de versión)."
        fi
    else
        log_success "✅ Este repo no usa release-please."
    fi

    # 2. Determinar el SHA Final (verdad absoluta desde remoto)
    local final_dev_sha
    final_dev_sha="$(__remote_head_sha "dev" "origin")"

    if [[ -z "${final_dev_sha:-}" ]]; then
        log_error "No pude resolver origin/dev final para capturar SHA final."
        return 1
    fi

    # 3. Build (CI) - Estado 3
    if repo_has_workflow_file "build-push"; then
        log_info "🏗️  Verificando Build & Push para el SHA final: ${final_dev_sha:0:7}"
        __watch_workflow_success_on_sha_or_die "build-push.yaml" "$final_dev_sha" "dev" "Build and Push" || return 1
    else
        log_success "✅ Sin build: este repo no tiene workflow build-push."
    fi

    # GitOps (no invasivo)
    local changed_paths
    changed_paths="$(git diff --name-only "${final_dev_sha}~1..${final_dev_sha}" 2>/dev/null || true)"
    maybe_trigger_gitops_update "dev" "$final_dev_sha" "$changed_paths"

    echo
    log_success "✅ DEV listo. SHA final: ${final_dev_sha:0:7}"
    log_info "🔎 Confirmación visual (git ls-remote --heads origin dev):"
    git ls-remote --heads origin dev 2>/dev/null || true
    echo

    echo "👉 Siguiente paso: git promote staging"
    return 0
}

# ------------------------------------------------------------------------------
# Main Strategy: Direct Promote (usando Jefe de Obra)
# ------------------------------------------------------------------------------
promote_to_dev_direct() {
    resync_submodules_hard

    # En el core existe ensure_clean_git (el *_or_die no está garantizado aquí)
    ensure_clean_git

    # 🔒 Solo permitido desde dev-update (canónico) o feature/dev-update (compat deprecada)
    local from="${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
    if [[ "$from" != "dev-update" && "$from" != "feature/dev-update" ]]; then
        die "⛔ DEV direct solo está permitido desde dev-update (feature/dev-update está deprecada)."
    fi

    local feature_branch
    feature_branch="$from"
    [[ -n "${feature_branch:-}" && "$feature_branch" != "(detached)" ]] || feature_branch="$(git branch --show-current 2>/dev/null || echo "")"
    feature_branch="$(echo "${feature_branch:-}" | tr -d '[:space:]')"
    [[ -n "${feature_branch:-}" ]] || die "No pude detectar la rama fuente (dev-update)."

    if ! command -v gh >/dev/null 2>&1; then
        log_error "Se requiere 'gh' para observar Actions/Issues en modo directo."
        exit 1
    fi

    banner "🧨 PROMOTE DEV (DIRECT / FORCE-WITH-LEASE via core)"
    log_info "Fuente: $feature_branch"

    # SHA fuente: preferimos el snapshot capturado por el bin (antes de cambiar de rama)
    local source_sha="${DEVTOOLS_PROMOTE_FROM_SHA:-}"
    if [[ -z "${source_sha:-}" ]]; then
        source_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    fi
    [[ -n "${source_sha:-}" ]] || die "No pude resolver SHA fuente para DEV direct."

    # Ejecutar fuerza estándar vía core (incluye tracking, reset, push --force-with-lease y verificación)
    local dev_after_sha=""
    dev_after_sha="$(update_branch_to_sha_with_strategy "dev" "$source_sha" "origin" "force")" || die "No pude actualizar 'dev' en modo directo."
    log_success "✅ Dev actualizado (core force-with-lease). SHA: ${dev_after_sha:0:7}"

    # Aterrizaje: quedarnos en dev (y además el trap del bin lo asegura)
    git checkout dev >/dev/null 2>&1 || true

    # Monitoreo post-push
    promote_dev_direct_monitor "$dev_after_sha" "$feature_branch"
    exit $?
}

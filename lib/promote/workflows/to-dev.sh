#!/usr/bin/env bash
# Promote workflow: to-dev
# Este módulo maneja la promoción a DEV:
# - promote_to_dev: Crea/Mergea PRs, gestiona release-please y actualiza dev.
# - (Opcional) Modo directo: Squash local + Push directo a dev (sin PR).
#
# Dependencias externas: utils.sh, git-ops.sh, checks.sh (cargadas por el orquestador principal)
# Dependencias internas: helpers/gh-interactions.sh, strategies/*.sh (cargadas dinámicamente aquí)

# ------------------------------------------------------------------------------
# Dynamic Imports (Refactorización Modular)
# ------------------------------------------------------------------------------
# Detectamos el directorio actual de forma robusta (Bash y Zsh compatible)
# ${BASH_SOURCE[0]:-$0} usa BASH_SOURCE si existe, o cae en $0 (que Zsh usa para el path al hacer source)
_CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_PROMOTE_LIB_ROOT="$(dirname "$_CURRENT_DIR")"

# 1. Cargar Helpers de GitHub/Git
if [[ -f "${_PROMOTE_LIB_ROOT}/helpers/gh-interactions.sh" ]]; then
    source "${_PROMOTE_LIB_ROOT}/helpers/gh-interactions.sh"
else
    echo "❌ Error: No se encontró helpers/gh-interactions.sh" >&2
    echo "   Buscado en: ${_PROMOTE_LIB_ROOT}/helpers/gh-interactions.sh" >&2
    exit 1
fi

# 2. Cargar Estrategia: Directa (No PR)
if [[ -f "${_PROMOTE_LIB_ROOT}/strategies/dev-direct.sh" ]]; then
    source "${_PROMOTE_LIB_ROOT}/strategies/dev-direct.sh"
else
    echo "❌ Error: No se encontró strategies/dev-direct.sh" >&2
    exit 1
fi

# 3. Cargar Estrategia: Monitor PR (Async/Sync)
if [[ -f "${_PROMOTE_LIB_ROOT}/strategies/dev-pr-monitor.sh" ]]; then
    source "${_PROMOTE_LIB_ROOT}/strategies/dev-pr-monitor.sh"
else
    echo "❌ Error: No se encontró strategies/dev-pr-monitor.sh" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Helpers Locales (Orquestación de procesos)
# ------------------------------------------------------------------------------

__resolve_promote_script() {
    local dot_dir=".devtools"
    # 1) Si viene del bin principal, SCRIPT_DIR existe y es confiable
    if [[ -n "${SCRIPT_DIR:-}" && -x "${SCRIPT_DIR}/git-promote.sh" ]]; then
        echo "${SCRIPT_DIR}/git-promote.sh"
        return 0
    fi

    # 2) Si estamos en un repo consumidor que tiene .devtools embebido
    if [[ -n "${REPO_ROOT:-}" && -x "${REPO_ROOT}/${dot_dir}/bin/git-promote.sh" ]]; then
        echo "${REPO_ROOT}/${dot_dir}/bin/git-promote.sh"
        return 0
    fi

    # 3) Si estamos dentro del repo .devtools (REPO_ROOT==.devtools)
    if [[ -n "${REPO_ROOT:-}" && -x "${REPO_ROOT}/bin/git-promote.sh" ]]; then
        echo "${REPO_ROOT}/bin/git-promote.sh"
        return 0
    fi

    # 4) Fallback
    echo "git-promote.sh"
}

__promote_dev_host_from_origin_url() {
    local remote_url="$1"
    local host=""

    # Parse sin regex de protocolo host://
    local url="${remote_url:-}"
    local sep="://"
    local p_ssh="ssh"
    local p_http="http"
    local p_https="https"

    url="${url#${p_ssh}${sep}}"
    url="${url#${p_https}${sep}}"
    url="${url#${p_http}${sep}}"
    [[ "$url" == git@* ]] && url="${url#git@}"
    # host es lo que hay antes de ':' o '/'
    host="${url%%[:/]*}"

    [[ -n "${host:-}" ]] || host="github.com"
    echo "$host"
}

promote_dev_precondition_error() {
    local message="$1"
    local branch_hint="$2"
    local host_hint="${3:-github.com}"

    log_error "❌ ${message}"
    log_error "Rama sin upstream: no hay CI para este SHA."
    log_error "Reintenta: git push -u origin HEAD:refs/heads/${branch_hint}"
    log_error "Verifica acceso: ssh -T git@${host_hint}"
    log_error "Verifica llave cargada: ssh-add -l"
    return 2
}

promote_dev_is_protected_branch() {
    if declare -F promote_is_protected_branch >/dev/null 2>&1; then
        promote_is_protected_branch "${1:-}"
        return $?
    fi

    local branch="${1:-}"
    [[ -n "${branch:-}" ]] || return 1

    local raw_patterns="${DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS:-dev|main|master|local|release/*}"
    local patterns="${raw_patterns//|/ }"
    patterns="${patterns//,/ }"

    local pattern=""
    for pattern in $patterns; do
        [[ -n "${pattern:-}" ]] || continue
        if [[ "$branch" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

promote_dev_preflight_docker_or_die() {
    local require_docker="${DEVTOOLS_PROMOTE_REQUIRE_DOCKER:-0}"
    if [[ "${require_docker}" != "1" ]]; then
        return 0
    fi

    if declare -F promote_preflight_docker_or_die >/dev/null 2>&1; then
        promote_preflight_docker_or_die
        return $?
    fi

    if ! command -v docker >/dev/null 2>&1 || ! docker ps >/dev/null 2>&1; then
        log_error "❌ Docker no está listo. Enciende Docker daemon/Docker Desktop o sudo systemctl start docker"
        return 2
    fi

    log_info "✅ Preflight Docker OK."
    return 0
}

promote_dev_argocd_optional_mode_enabled() {
    if [[ "${DEVTOOLS_PROMOTE_ARGOCD_REQUIRED:-0}" == "1" ]]; then
        return 1
    fi

    [[ "${DEVTOOLS_PROMOTE_ARGOCD_OPTIONAL:-0}" == "1"         || "${CI:-0}" == "1"         || "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" ]]
}

promote_dev_preflight_argocd_or_die() {
    local argocd_app="${DEVTOOLS_PROMOTE_ARGOCD_APP:-pmbok}"

    if declare -F promote_preflight_argocd_or_die >/dev/null 2>&1; then
        if promote_preflight_argocd_or_die "$argocd_app"; then
            return 0
        fi
        if promote_dev_argocd_optional_mode_enabled; then
            export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED=1
            log_warn "⚠️ ArgoCD no verificable; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        return 2
    fi

    if ! command -v argocd >/dev/null 2>&1; then
        if promote_dev_argocd_optional_mode_enabled; then
            export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED=1
            log_warn "⚠️ ArgoCD CLI no disponible; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."
        return 2
    fi

    if ! argocd account get-user-info >/dev/null 2>&1; then
        if promote_dev_argocd_optional_mode_enabled; then
            export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED=1
            log_warn "⚠️ ArgoCD sin login; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."
        return 2
    fi

    if command -v kubectl >/dev/null 2>&1; then
        if ! kubectl cluster-info >/dev/null 2>&1; then
            log_warn "⚠️ Kubernetes/cluster no verificable desde kubectl (continuo porque el flujo usa ArgoCD CLI)."
        fi
    else
        log_warn "⚠️ kubectl no disponible. Si aplica, valida cluster con: kubectl cluster-info"
    fi

    export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED=0
    log_info "✅ Preflight ArgoCD OK (app: ${argocd_app})."
    return 0
}

promote_dev_runtime_preflight_or_die() {
    local source_branch="${1:-}"

    export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED="${DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED:-0}"

    if ! promote_dev_preflight_docker_or_die; then
        return 2
    fi

    if promote_dev_is_protected_branch "$source_branch"; then
        log_info "📌 Rama fuente protegida '${source_branch}': se omite preflight ArgoCD."
        export DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED=1
        return 0
    fi

    if ! promote_dev_preflight_argocd_or_die; then
        return 2
    fi

    return 0
}

promote_dev_ensure_tag_remote_or_die() {

    local tag="${1:-}"
    local expected_sha="${2:-}"

    if declare -F promote_ensure_tag_remote_or_die >/dev/null 2>&1; then
        promote_ensure_tag_remote_or_die "$tag" "$expected_sha"
        return $?
    fi

    [[ -n "${tag:-}" ]] || { log_error "❌ Tag vacío para publish remoto."; return 2; }
    [[ -n "${expected_sha:-}" ]] || { log_error "❌ SHA vacío para tag remoto."; return 2; }

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️ DRY-RUN: omito creación/push de tag remoto (${tag})."
        return 0
    fi

    if ! git show-ref --verify --quiet "refs/tags/${tag}"; then
        if ! git tag -a "$tag" "$expected_sha" -m "chore(release): ${tag}"; then
            log_error "❌ No pude crear el tag local '${tag}'."
            return 2
        fi
        log_info "🏷️ Tag creado: ${tag}"
    else
        local existing_tag_sha=""
        existing_tag_sha="$(git rev-list -n 1 "${tag}" 2>/dev/null || true)"
        if [[ -z "${existing_tag_sha:-}" ]]; then
            log_error "❌ No pude resolver SHA de tag local existente '${tag}'."
            return 2
        fi
        if [[ "${existing_tag_sha}" != "${expected_sha}" ]]; then
            log_error "❌ TAG MISMATCH: tag=${tag} tag_sha=${existing_tag_sha} expected=${expected_sha}"
            return 2
        fi
        log_info "🏷️ Tag local ya existe y coincide con SHA esperado: ${tag}"
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push origin "refs/tags/${tag}"; then
        log_error "❌ No pude pushear el tag. Ejecuta: git push origin refs/tags/${tag}"
        return 2
    fi

    log_info "🏷️ Tag pusheado: ${tag}"
    return 0
}

promote_dev_sync_argocd_with_tag_or_die() {
    local tag="${1:-}"
    local argocd_app="${DEVTOOLS_PROMOTE_ARGOCD_APP:-pmbok}"
    local wait_timeout="${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}"

    if [[ "${DEVTOOLS_PROMOTE_DEV_ARGOCD_SKIPPED:-0}" == "1" ]]; then
        log_warn "⚠️ ArgoCD omitido por preflight opcional (CI/no interactivo)."
        return 0
    fi

    if declare -F promote_argocd_sync_by_tag_or_die >/dev/null 2>&1; then
        if promote_argocd_sync_by_tag_or_die "$tag" "$argocd_app" "$wait_timeout"; then
            return 0
        fi
        if promote_dev_argocd_optional_mode_enabled; then
            log_warn "⚠️ Falló ArgoCD set/sync; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        return 2
    fi

    [[ -n "${tag:-}" ]] || { log_error "❌ Tag vacío para sync ArgoCD."; return 2; }

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️ DRY-RUN: omito ArgoCD set/sync para ${argocd_app} -> ${tag}."
        return 0
    fi

    if ! command -v argocd >/dev/null 2>&1; then
        if promote_dev_argocd_optional_mode_enabled; then
            log_warn "⚠️ ArgoCD CLI no disponible; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."
        return 2
    fi

    log_info "ArgoCD: set revision ${argocd_app} -> ${tag}"
    if ! argocd app set "$argocd_app" --revision "$tag"; then
        if promote_dev_argocd_optional_mode_enabled; then
            log_warn "⚠️ ArgoCD set falló; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD falló. Ejecuta: argocd app set ${argocd_app} --revision ${tag}"
        return 2
    fi

    if ! argocd app sync "$argocd_app"; then
        if promote_dev_argocd_optional_mode_enabled; then
            log_warn "⚠️ ArgoCD sync falló; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD falló. Ejecuta: argocd app sync ${argocd_app}"
        return 2
    fi

    if ! argocd app wait "$argocd_app" --timeout "${wait_timeout}" --health --sync; then
        if promote_dev_argocd_optional_mode_enabled; then
            log_warn "⚠️ ArgoCD wait falló; continúo sin ArgoCD (CI/no interactivo)."
            return 0
        fi
        log_error "❌ ArgoCD falló. Ejecuta: argocd app wait ${argocd_app} --timeout ${wait_timeout} --health --sync"
        return 2
    fi

    log_success "ArgoCD: sync ${argocd_app} OK"
    return 0
}

DEVTOOLS_PROMOTE_GATE_REF=""

promote_dev_ensure_ci_ref_or_die() {
    # Args: source_branch source_sha
    local source_branch="${1:-}"
    local source_sha="${2:-}"
    DEVTOOLS_PROMOTE_GATE_REF=""

    local remote_url=""
    if ! remote_url="$(git remote get-url origin 2>/dev/null)"; then
        log_error "❌ No hay remote 'origin' o no es accesible."
        log_error "Verifica: git remote -v"
        log_error "Configura origin o usa: git push -u <remote> HEAD:<branch>"
        return 2
    fi

    local host_hint=""
    host_hint="$(__promote_dev_host_from_origin_url "$remote_url")"

    local has_upstream=1
    git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1 || has_upstream=0

    if [[ "$has_upstream" -eq 1 ]]; then
        local ahead_count=0
        ahead_count="$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo "0")"
        if [[ "${ahead_count}" =~ ^[0-9]+$ ]] && (( ahead_count > 0 )); then
            log_info "📤 Empujando rama fuente '${source_branch}' (${ahead_count} commit(s))..."
            GIT_TERMINAL_PROMPT=0 git push origin "${source_branch}" || {
                promote_dev_precondition_error \
                    "Falló push con upstream para '${source_branch}'." \
                    "${source_branch}" \
                    "${host_hint}"
                return 2
            }
        fi
        DEVTOOLS_PROMOTE_GATE_REF="${source_branch}"
        return 0
    fi

    if ! GIT_TERMINAL_PROMPT=0 git ls-remote --heads origin >/dev/null 2>&1; then
        log_error "❌ No hay remote 'origin' o no es accesible."
        log_error "Verifica: git remote -v"
        log_error "Configura origin o usa: git push -u <remote> HEAD:<branch>"
        return 2
    fi

    local short_sha=""
    short_sha="$(git rev-parse --short "${source_sha}" 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    local ts=""
    ts="$(date +%Y%m%d%H%M%S)"
    local tmp_branch="tmp/promote-${short_sha}-${ts}"

    local effective_branch="${source_branch}"
    if [[ -z "${source_branch:-}" || "${source_branch}" == "HEAD" || "${source_branch}" == "(detached)" ]]; then
        effective_branch="${tmp_branch}"
        log_warn "Rama fuente en detached HEAD. Publicando rama temporal '${effective_branch}' para asociar CI."
        GIT_TERMINAL_PROMPT=0 git push -u origin "HEAD:refs/heads/${effective_branch}" || {
            promote_dev_precondition_error \
                "Falló push de rama temporal '${effective_branch}'." \
                "${effective_branch}" \
                    "${host_hint}"
            return 2
        }
        DEVTOOLS_PROMOTE_GATE_REF="${effective_branch}"
        return 0
    fi

    log_warn "Rama '${source_branch}' sin upstream. Haciendo auto-push para habilitar CI en este SHA..."
    if GIT_TERMINAL_PROMPT=0 git push -u origin "HEAD:refs/heads/${source_branch}"; then
        DEVTOOLS_PROMOTE_GATE_REF="${source_branch}"
        return 0
    fi

    log_warn "No pude push a '${source_branch}'. Intentando fallback temporal '${tmp_branch}'..."
    if GIT_TERMINAL_PROMPT=0 git push -u origin "HEAD:refs/heads/${tmp_branch}"; then
        DEVTOOLS_PROMOTE_GATE_REF="${tmp_branch}"
        return 0
    fi

    promote_dev_precondition_error \
        "Falló auto-push para crear CI de la rama fuente." \
        "${source_branch}" \
        "${host_hint}"
    return 2
}

promote_dev_verify_target_advanced_or_die() {
    # Args: target_branch source_sha target_before_sha
    local target_branch="${1:-dev}"
    local source_sha="${2:-}"
    local target_before_sha="${3:-}"
    local target_after_sha=""

    [[ -n "${source_sha:-}" ]] || {
        log_error "❌ SOURCE SHA vacío al validar avance de ${target_branch}."
        return 2
    }

    target_after_sha="$(git rev-parse "${target_branch}" 2>/dev/null || true)"
    [[ -n "${target_after_sha:-}" ]] || {
        log_error "❌ No pude resolver SHA final de '${target_branch}'."
        return 2
    }

    if [[ -n "${target_before_sha:-}" && "${target_before_sha}" == "${target_after_sha}" ]]; then
        log_error "❌ NO-OP DETECTED: ${target_branch} no avanzó."
        log_error "   target_sha_before=${target_before_sha} target_sha_after=${target_after_sha} source_sha=${source_sha}"
        return 2
    fi

    if ! git merge-base --is-ancestor "${source_sha}" "${target_after_sha}" >/dev/null 2>&1; then
        log_error "❌ NO-OP DETECTED: ${target_branch} no contiene source."
        log_error "   target_sha_before=${target_before_sha:-unknown} target_sha_after=${target_after_sha} source_sha=${source_sha}"
        return 2
    fi

    echo "${target_after_sha}"
    return 0
}

promote_dev_verify_tag_matches_target_or_die() {
    # Args: tag expected_target_sha
    local tag="${1:-}"
    local expected_sha="${2:-}"
    local tag_sha=""

    [[ -n "${tag:-}" ]] || {
        log_error "❌ TAG vacío al verificar consistencia."
        return 2
    }
    [[ -n "${expected_sha:-}" ]] || {
        log_error "❌ expected_target_sha vacío al verificar tag ${tag}."
        return 2
    }

    tag_sha="$(git rev-list -n 1 "${tag}" 2>/dev/null || true)"
    [[ -n "${tag_sha:-}" ]] || {
        log_error "❌ No pude resolver SHA del tag ${tag}."
        return 2
    }

    if [[ "${tag_sha}" != "${expected_sha}" ]]; then
        log_error "❌ TAG MISMATCH: tag=${tag} tag_sha=${tag_sha} expected=${expected_sha}"
        return 2
    fi

    echo "${tag_sha}"
    return 0
}

promote_dev_emit_summary() {
    # Args:
    #  1 target
    #  2 source_branch
    #  3 source_sha
    #  4 target_before
    #  5 target_after
    #  6 moved (yes|no)
    #  7 tag
    #  8 tag_sha
    #  9 offline (0|1)
    # 10 noop (0|1)
    local target="${1:-dev}"
    local source_branch="${2:-unknown}"
    local source_sha="${3:-unknown}"
    local target_before="${4:-unknown}"
    local target_after="${5:-unknown}"
    local moved="${6:-no}"
    local tag="${7:--}"
    local tag_sha="${8:--}"
    local offline="${9:-0}"
    local noop="${10:-0}"

    log_info "PROMOTE SUMMARY: target=${target} source=${source_branch} source_sha=${source_sha} target_before=${target_before} target_after=${target_after} moved=${moved} tag=${tag} tag_sha=${tag_sha} offline=${offline} noop=${noop}"
}

# ==============================================================================
# 3. PROMOTE TO DEV (Main Entry Point)
# ==============================================================================
promote_to_dev() {
    resync_submodules_hard

    # NUEVO: garantizar aterrizaje final en DEV (lo ejecuta el trap del bin principal)
    export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="dev"

    # Fuente: rama donde se invocó el comando (capturada por el bin principal)
    local source_branch="${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
    if [[ -z "${source_branch:-}" || "${source_branch:-}" == "(detached)" ]]; then
        source_branch="$(git branch --show-current 2>/dev/null || echo "")"
    fi
    source_branch="$(echo "${source_branch:-}" | tr -d '[:space:]')"
    [[ -n "${source_branch:-}" ]] || die "No pude detectar rama fuente para promover a dev."
    local source_branch_original="$source_branch"

    # SHA fuente: preferimos el snapshot capturado por el bin (antes de cambiar de rama)
    local source_sha="${DEVTOOLS_PROMOTE_FROM_SHA:-}"
    if [[ -z "${source_sha:-}" ]]; then
        source_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    fi
    [[ -n "${source_sha:-}" ]] || die "No pude resolver SHA fuente."
    local target_before_sha=""
    target_before_sha="$(git rev-parse origin/dev 2>/dev/null || git rev-parse dev 2>/dev/null || true)"
    local target_after_sha="${target_before_sha:-unknown}"
    local moved="no"
    local final_tag_sha="-"
    local offline_flag="${DEVTOOLS_PROMOTE_OFFLINE:-0}"
    local noop_flag="0"

    local promote_dev_direct="${DEVTOOLS_PROMOTE_DEV_DIRECT:-0}"
    if [[ "${promote_dev_direct}" == "1" ]]; then
        [[ "${source_branch:-}" == "dev-update" ]] \
            || [[ "${source_branch:-}" == "feature/dev-update" ]] \
            || die "⛔ DEVTOOLS_PROMOTE_DEV_DIRECT=1 solo está permitido desde dev-update (feature/dev-update está deprecada)."
    fi

    echo
    log_info "🧩 PROMOCIÓN HACIA 'dev' (cero fricción)"
    log_info "    Fuente : ${source_branch} @${source_sha:0:7}"
    log_info "    Destino: dev"
    echo

    if [[ "${source_branch_original}" == "dev" ]]; then
        log_info "📌 Fuente ya está en 'dev': no hay cambios para promover."
        noop_flag="1"
        promote_dev_emit_summary "dev" "${source_branch_original}" "${source_sha}" "${target_before_sha:-unknown}" "${target_after_sha:-unknown}" "${moved}" "-" "-" "${offline_flag}" "${noop_flag}"
        log_info "📌 Resultado final: SUCCESS (mode=noop, source=dev, target=dev)."
        return 0
    fi

    if [[ "${DEVTOOLS_PROMOTE_OFFLINE:-0}" == "1" && "${DEVTOOLS_PROMOTE_DEV_OFFLINE_NOOP:-0}" == "1" ]]; then
        log_warn "⚠️ OFFLINE-NOOP activo: omito gate/push/argocd para promote dev."
        log_warn "⚠️ OFFLINE-NOOP ACTIVE: NO push, NO gate, NO argocd, NO tag update."
        noop_flag="1"
        target_after_sha="$(git rev-parse dev 2>/dev/null || true)"
        promote_dev_emit_summary "dev" "${source_branch_original}" "${source_sha}" "${target_before_sha:-unknown}" "${target_after_sha:-unknown}" "${moved}" "-" "-" "1" "${noop_flag}"
        log_info "📌 Resultado final: SUCCESS (offline_noop=1, gate_skipped=1, push_skipped=1, argocd_skipped=1)."
        return 0
    fi

    if [[ "${CI:-0}" == "1" ]]         && [[ "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" ]]         && [[ "${DEVTOOLS_PROMOTE_DEV_CI_NOOP:-1}" == "1" ]]; then
        log_warn "⚠️ CI-NOOP activo: omito gate/push/argocd para promote dev."
        noop_flag="1"
        target_after_sha="$(git rev-parse dev 2>/dev/null || true)"
        promote_dev_emit_summary "dev" "${source_branch_original}" "${source_sha}" "${target_before_sha:-unknown}" "${target_after_sha:-unknown}" "${moved}" "-" "-" "${offline_flag}" "${noop_flag}"
        log_info "📌 Resultado final: SUCCESS (ci_noop=1, gate_skipped=1, push_skipped=1, argocd_skipped=1)."
        return 0
    fi

    if ! promote_dev_runtime_preflight_or_die "$source_branch_original"; then
        return 2
    fi

    if [[ "${promote_dev_direct}" != "1" && "${DEVTOOLS_ALLOW_PROMOTE_DEV_FROM_NON_STAGING:-0}" != "1" ]]; then
        if [[ "${source_branch_original}" != "staging" ]]; then
            die "Promote a dev requiere rama fuente 'staging' (actual='${source_branch_original}'). Usa DEVTOOLS_ALLOW_PROMOTE_DEV_FROM_NON_STAGING=1 para override."
        fi
    fi

    if ! declare -F promote_next_tag_dev >/dev/null 2>&1 \
        || ! declare -F semver_parse_tag >/dev/null 2>&1; then
        die "No se encontraron helpers necesarios para calcular la version RC+build."
    fi
    if ! declare -F prepare_changelog_commit >/dev/null 2>&1; then
        die "No se encontró helper prepare_changelog_commit."
    fi

    GIT_TERMINAL_PROMPT=0 git fetch origin dev staging --prune >/dev/null 2>&1 || true
    local dev_before_sha=""
    local staging_head_sha=""
    dev_before_sha="$(git rev-parse origin/dev 2>/dev/null || true)"
    [[ -n "${dev_before_sha:-}" ]] || die "No pude resolver origin/dev para calcular rango de changelog."

    if [[ "${source_branch_original}" == "staging" ]]; then
        staging_head_sha="$source_sha"
    else
        staging_head_sha="$(git rev-parse origin/staging 2>/dev/null || git rev-parse staging 2>/dev/null || true)"
    fi
    [[ -n "${staging_head_sha:-}" ]] || die "No pude resolver staging para calcular rango de changelog."

    local range
    range="${dev_before_sha}..${staging_head_sha}"

    local suggested_tag final_tag
    suggested_tag="$(promote_next_tag_dev "$range")"
    final_tag="$suggested_tag"

    local override_tag="${DEVTOOLS_PROMOTE_TAG_OVERRIDE:-}"
    if [[ -n "${override_tag:-}" ]]; then
        final_tag="$override_tag"
        log_info "🏷️ Override de version por DEVTOOLS_PROMOTE_TAG_OVERRIDE: ${final_tag}"
    elif declare -F can_prompt >/dev/null 2>&1 && can_prompt; then
        local input_tag
        if have_gum_ui; then
            input_tag="$(gum input --value "$suggested_tag" --header "Version RC+build sugerida (Enter acepta)")"
        else
            printf "Version RC+build [%s]: " "$suggested_tag" > /dev/tty
            read -r input_tag < /dev/tty
        fi
        input_tag="${input_tag:-$suggested_tag}"
        final_tag="$input_tag"
    fi

    if [[ -z "${TAG_PREFIX:-}" && -z "${APP:-}" ]]; then
        if [[ "$final_tag" =~ ^([A-Za-z0-9._-]+)-v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            export TAG_PREFIX="${BASH_REMATCH[1]}"
        fi
    fi

    local parsed_ver parsed_rc parsed_build
    if ! semver_parse_tag "$final_tag" parsed_ver parsed_rc parsed_build; then
        die "Formato invalido. Usa [APP]-vX.Y.Z-rc.N+build.N (imagen: -build.N)."
    fi
    if [[ -z "${parsed_rc:-}" || -z "${parsed_build:-}" ]]; then
        die "Formato invalido. Usa [APP]-vX.Y.Z-rc.N+build.N (imagen: -build.N)."
    fi
    if [[ "${final_tag:-}" != "${suggested_tag:-}" ]]; then
        log_warn "La version elegida (${final_tag}) no coincide con la sugerida (${suggested_tag})."
    fi

    local image_tag
    if declare -F semver_to_image_tag >/dev/null 2>&1; then
        image_tag="$(semver_to_image_tag "$final_tag")"
        export DEVTOOLS_PROMOTE_IMAGE_TAG="$image_tag"
    fi

    local promote_tag_file
    promote_tag_file="$(promote_tag_file_path)"
    if ! promote_tag_write_cache "$final_tag" "$parsed_ver" "$parsed_rc" "$parsed_build" "dev" "to-dev" "$promote_tag_file"; then
        die "No pude escribir .promote_tag."
    fi
    log_info "🏷️ Tag guardado en: ${promote_tag_file}"
    log_info "CACHE DECISION: using tag=${final_tag} base=${parsed_ver} source=to-dev"

    local promote_component
    promote_component="$(resolve_promote_component "$range")"
    log_info "🧩 Componente changelog: ${promote_component}"
    log_info "🔎 CHANGELOG DEBUG: from_ref=${dev_before_sha} to_ref=${staging_head_sha} range=${range}"

    # Tag real: se crea/pushea al final, solo después de Push OK a dev.

    # ESTRATEGIA 1: Modo DIRECTO (sin PR feature->dev)
    if [[ "${promote_dev_direct}" == "1" ]]; then
        promote_to_dev_direct
        exit $?
    fi

    # Cargamos helpers del gate aquí para validarlo más adelante sobre dev (post-push).
    if ! declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        local checks_file="${_PROMOTE_LIB_ROOT}/workflows/checks.sh"
        if [[ -f "${checks_file}" ]]; then
            # shellcheck disable=SC1090
            source "${checks_file}" || die "No se pudo cargar workflows/checks.sh."
        fi
    fi
    if ! declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        die "No se encontró gate_required_workflows_on_sha_or_die (faltó source de workflows/checks.sh)."
    fi

    # Estrategia (Menú Universal): el bin la setea siempre, pero dejamos fallback seguro.
    local strategy="${DEVTOOLS_PROMOTE_STRATEGY:-}"
    [[ -n "${strategy:-}" ]] || strategy="ff-only"
    if [[ "$strategy" == "ff-only" || "$strategy" == "force" ]]; then
        log_warn "Para integrar CHANGELOG sin commit extra se requiere merge commit; ajustando estrategia ${strategy} -> merge-theirs."
        strategy="merge-theirs"
        export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
    fi

    # Aplicar estrategia sobre dev local; el push se hace luego del amend del changelog.
    local final_sha="" rc=0 dev_push_ok=0
    while true; do
        if final_sha="$(update_branch_to_sha_with_strategy "dev" "$source_sha" "origin" "$strategy" "0")"; then
            rc=0
        else
            rc=$?
        fi
        if [[ "$rc" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward NO es posible. Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc" -eq 0 ]] || die "No pude promover hacia 'dev' (strategy=${strategy}, rc=${rc})."
        break
    done

    log_success "✅ Promoción local en dev lista (sin push): strategy=${strategy}, sha=${final_sha:0:7}"

    log_info "🧪 Checkpoint: antes de prepare_changelog_commit (tag=${final_tag})"
    prepare_changelog_commit "$final_tag" "$range" "$promote_component"
    log_info "🧪 Checkpoint: después de prepare_changelog_commit"

    if [[ "${DEVTOOLS_CHANGELOG_UPDATED:-0}" == "1" ]]; then
        local changelog_file="${DEVTOOLS_CHANGELOG_FILE:-CHANGELOG.md}"
        log_info "🔎 CHANGELOG DEBUG: file=${changelog_file} range=${range}"
        git add "$changelog_file" || die "No pude agregar ${changelog_file}."
        git commit --amend --no-edit || die "No pude integrar changelog en el commit final."
        final_sha="$(git rev-parse HEAD 2>/dev/null || true)"
        [[ -n "${final_sha:-}" ]] || die "No pude resolver SHA tras integrar changelog."
    fi

    if [[ "$strategy" == "force" ]]; then
        push_branch_force "dev" "origin" || die "No pude pushear dev (force)."
    else
        GIT_TERMINAL_PROMPT=0 git push origin dev || die "No pude pushear dev."
    fi

    log_success "✅ Push OK: ${source_branch} -> origin/dev (strategy=${strategy}, sha=${final_sha:0:7})"
    dev_push_ok=1
    if ! target_after_sha="$(promote_dev_verify_target_advanced_or_die "dev" "$source_sha" "$target_before_sha")"; then
        return 2
    fi
    moved="yes"
    final_sha="${target_after_sha}"

    # Guard final: validar CI sobre el SHA real de dev, no sobre la rama fuente local.
    gate_required_workflows_on_sha_or_die "$final_sha" "dev" "dev" \
        || die "Gate por SHA falló para dev (${final_sha:0:7}). Abortando promote a dev."

    # Tag + GitOps ArgoCD (solo ramas fuente no protegidas)
    if [[ "$dev_push_ok" -eq 1 ]]; then
        if ! promote_dev_ensure_tag_remote_or_die "$final_tag" "$final_sha"; then
            return 2
        fi
        if ! final_tag_sha="$(promote_dev_verify_tag_matches_target_or_die "$final_tag" "$final_sha")"; then
            return 2
        fi

        if promote_dev_is_protected_branch "$source_branch_original"; then
            log_info "📌 Rama fuente protegida '${source_branch_original}': se omite ArgoCD (set/sync)."
        else
            if ! promote_dev_sync_argocd_with_tag_or_die "$final_tag"; then
                return 2
            fi
        fi
    fi

    # CONFIRMACIÓN VISUAL (tú la verificas con ls-remote; aquí queda impreso)
    echo
    log_info "🔎 Confirmación visual (git ls-remote --heads origin dev):"
    local remote_line
    remote_line="$(GIT_TERMINAL_PROMPT=0 git ls-remote --heads origin dev 2>/dev/null | head -n 1 || true)"
    if [[ -n "${remote_line:-}" ]]; then
        echo "   ${remote_line}"
    else
        log_warn "No pude obtener ls-remote para origin/dev (¿red/credenciales?)."
    fi
    echo

    promote_dev_emit_summary "dev" "${source_branch_original}" "${source_sha}" "${target_before_sha:-unknown}" "${target_after_sha:-unknown}" "${moved}" "${final_tag:-"-"}" "${final_tag_sha:-"-"}" "${offline_flag}" "${noop_flag}"

    # Monitor opcional por flag/env
    local want_monitor="${GIT_PROMOTE_MONITOR:-${DEVTOOLS_PROMOTE_MONITOR:-0}}"
    if [[ "${want_monitor}" == "1" ]]; then
        if ! command -v gh >/dev/null 2>&1; then
            die "Se requiere 'gh' para ejecutar el monitor (actívalo instalando gh o desactiva GIT_PROMOTE_MONITOR)."
        fi
        promote_dev_monitor "" ""
        exit $?
    fi

    exit 0
}

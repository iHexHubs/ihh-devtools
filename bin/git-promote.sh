#!/usr/bin/env bash
# Punto de entrada principal para promociones de código.
#
# Orquesta la carga de librerías, validaciones de entorno y ejecución de workflows.

set -e

# ==============================================================================
# DISPATCH DE CONTEXTO (repo raíz -> script correcto)
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
source "${LIB_DIR}/core/dispatch.sh"
devtools_dispatch_if_needed "$@"

# ==============================================================================
# 0.0 DEFAULTS (set -u safe)
# ==============================================================================
# Si no está seteada, por defecto NO forzamos guard canónico extra
export DEVTOOLS_FORCE_CANONICAL_REFS="${DEVTOOLS_FORCE_CANONICAL_REFS:-0}"
export DEVTOOLS_SKIP_CANONICAL_CHECK="${DEVTOOLS_SKIP_CANONICAL_CHECK:-0}"

# ==============================================================================
# 0. BOOTSTRAP & CARGA DE LIBRERÍAS
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMOTE_ENTRY_DIR="${PROMOTE_ENTRY_DIR:-${REPO_ROOT:-$PWD}}"

# Cargar utilidades core (logging, ui, guards)
source "${LIB_DIR}/core/utils.sh"
source "${LIB_DIR}/core/git-ops.sh"
source "${LIB_DIR}/release-flow.sh"

# Definir ruta de librerías de promoción
PROMOTE_LIB="${LIB_DIR}/promote"

if [[ -f "${PROMOTE_LIB}/workflows/checks.sh" ]]; then
    # shellcheck source=../lib/promote/workflows/checks.sh
    source "${PROMOTE_LIB}/workflows/checks.sh"
fi

git_entry() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR \
        command git -C "${PROMOTE_ENTRY_DIR:-${REPO_ROOT:-$PWD}}" "$@"
}

ensure_local_checkout() {
    local local_branch="local"
    local current_root=""
    local sync_to_origin=0
    local quiet_ui_mode=0
    current_root="$(git_entry rev-parse --show-toplevel 2>/dev/null || pwd)"
    if declare -F ui_is_quiet_mode >/dev/null 2>&1 && ui_is_quiet_mode; then
        quiet_ui_mode=1
    fi

    log_info "🔧 ensure_local_checkout(): aterrizando en rama final 'local' (alineada a origin/local cuando exista)..."
    if [[ "$quiet_ui_mode" -eq 1 ]]; then
        local worktrees_count="0"
        worktrees_count="$(git_entry worktree list 2>/dev/null | wc -l | tr -d '[:space:]')"
        log_info "ℹ️ Git env: repo_root=${REPO_ROOT:-<unset>} rama_pre=$(git_entry branch --show-current 2>/dev/null || echo '?') worktrees=${worktrees_count:-0}"
        log_info "ℹ️ Target=${TARGET_ENV:-?} | Source SHA=${DEVTOOLS_PROMOTE_FROM_SHA:-<unset>}"
    else
        log_info "🔎 promote target: ${TARGET_ENV:-?} args: ${TARGET_ENV:-} ${REST_ARGS[*]:-}"
        log_info "🔎 PWD(wrapper)=$(pwd)"
        log_info "🔎 REPO_ROOT=${REPO_ROOT:-<unset>}"
        log_info "🔎 GIT_* en workflow: $(env | grep -E '^GIT_' | tr '\n' ' ' || true)"
        log_info "🔎 git-dir(entry): $(git_entry rev-parse --git-dir 2>/dev/null || echo '?')"
        log_info "🔎 rama(entry) PRE: $(git_entry branch --show-current 2>/dev/null || echo '?')"
        log_info "🔎 worktrees(entry):"
        git_entry worktree list 2>/dev/null || true
    fi

    # Limpieza defensiva: worktrees temporales huérfanos que bloquean refs/heads/local.
    local wt_path=""
    local wt_branch=""
    while IFS= read -r line; do
        case "${line}" in
            worktree\ *)
                wt_path="${line#worktree }"
                ;;
            branch\ *)
                wt_branch="${line#branch }"
                if [[ -n "${wt_path:-}" && "${wt_path}" != "${current_root}" ]]; then
                    case "${wt_path}" in
                        /tmp/eco-promote-validate*|/tmp/eco-validate-*)
                            log_warn "🧹 Cleanup stale worktree temporal: ${wt_path} (${wt_branch:-sin-branch})"
                            git_entry worktree remove --force "${wt_path}" >/dev/null 2>&1 || true
                            rm -rf "${wt_path}" >/dev/null 2>&1 || true
                            ;;
                        *)
                            if [[ "${wt_branch}" == "refs/heads/${local_branch}" ]]; then
                                log_warn "⚠️ '${local_branch}' está en worktree externo (${wt_path}). Continuo sin forzar checkout."
                            fi
                            ;;
                    esac
                fi
                ;;
        esac
    done < <(git_entry worktree list --porcelain 2>/dev/null || true)
    git_entry worktree prune >/dev/null 2>&1 || true

    if git_entry show-ref --verify --quiet "refs/heads/${local_branch}"; then
        git_entry checkout "${local_branch}" >/dev/null 2>&1 || true
        if git_entry show-ref --verify --quiet "refs/remotes/origin/${local_branch}"; then
            sync_to_origin=1
        fi
    elif git_entry show-ref --verify --quiet "refs/remotes/origin/${local_branch}"; then
        ensure_local_branch_tracks_remote "${local_branch}" "origin" >/dev/null 2>&1 || true
        git_entry checkout "${local_branch}" >/dev/null 2>&1 || true
        sync_to_origin=1
    elif git_entry show-ref --verify --quiet "refs/heads/dev"; then
        git_entry checkout -b "${local_branch}" dev >/dev/null 2>&1 || true
    else
        git_entry checkout -b "${local_branch}" >/dev/null 2>&1 || true
    fi

    if [[ "${sync_to_origin}" == "1" ]]; then
        git_entry fetch origin "${local_branch}" >/dev/null 2>&1 || true
        if git_entry reset --hard "origin/${local_branch}" >/dev/null 2>&1; then
            log_info "🔄 '${local_branch}' quedó alineada a origin/${local_branch}."
        else
            log_warn "⚠️ No pude alinear '${local_branch}' con origin/${local_branch}; continúo."
        fi
    fi

    # Garantizar continuidad cuando promote local optimiza y no publica origin/local.
    # Si el source_sha actual no está en local tras la alineación, lo reintegramos.
    if [[ -n "${DEVTOOLS_PROMOTE_FROM_SHA:-}" ]] \
        && git_entry rev-parse --verify "${DEVTOOLS_PROMOTE_FROM_SHA}^{commit}" >/dev/null 2>&1; then
        if ! git_entry merge-base --is-ancestor "${DEVTOOLS_PROMOTE_FROM_SHA}" HEAD >/dev/null 2>&1; then
            log_info "📦 Integrando código fresco en '${local_branch}' (optimización CI detectada)..."
            if git_entry merge --ff-only "${DEVTOOLS_PROMOTE_FROM_SHA}" >/dev/null 2>&1; then
                log_info "✅ '${local_branch}' integra source_sha=${DEVTOOLS_PROMOTE_FROM_SHA:0:7} (ff-only)."
            elif git_entry reset --hard "${DEVTOOLS_PROMOTE_FROM_SHA}" >/dev/null 2>&1; then
                log_warn "⚠️ '${local_branch}' requirió reset a source_sha=${DEVTOOLS_PROMOTE_FROM_SHA:0:7} para continuidad."
            else
                log_warn "⚠️ No pude integrar source_sha=${DEVTOOLS_PROMOTE_FROM_SHA:0:7} en '${local_branch}'."
            fi
        fi
    fi

    log_info "🔎 rama(entry) POST: $(git_entry branch --show-current 2>/dev/null || echo '?')"
}

# Cargar estrategias de versión
source "${PROMOTE_LIB}/version-strategy.sh"

# Helpers comunes (incluye maybe_delete_source_branch)
# Nota: es seguro cargarlo aquí; usa log_* / ask_yes_no ya disponibles.
if [[ -f "${PROMOTE_LIB}/workflows/common.sh" ]]; then
    source "${PROMOTE_LIB}/workflows/common.sh"
fi

# ==============================================================================
# 1. CONTEXTO + LANDING TRAP (restaurar o aterrizar + borrar rama fuente)
# ==============================================================================
export DEVTOOLS_PROMOTE_FROM_BRANCH="${DEVTOOLS_PROMOTE_FROM_BRANCH:-$(git branch --show-current 2>/dev/null || echo "")}"
export DEVTOOLS_PROMOTE_FROM_BRANCH="$(echo "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" | tr -d '[:space:]')"
[[ -n "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" ]] || export DEVTOOLS_PROMOTE_FROM_BRANCH="(detached)"
export DEVTOOLS_PROMOTE_FROM_SHA="${DEVTOOLS_PROMOTE_FROM_SHA:-$(git rev-parse HEAD 2>/dev/null || true)}"
export PROMOTE_SOURCE_BRANCH="${PROMOTE_SOURCE_BRANCH:-${DEVTOOLS_PROMOTE_FROM_BRANCH:-}}"
export PROMOTE_SOURCE_SHA="${PROMOTE_SOURCE_SHA:-${DEVTOOLS_PROMOTE_FROM_SHA:-}}"
log_info "🧬 promote source: branch=${PROMOTE_SOURCE_BRANCH:-?} sha=${PROMOTE_SOURCE_SHA:-?}"

__promote_cache_file="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.promote_tag"
if [[ -f "${__promote_cache_file}" ]]; then
    __cache_tag="$(sed -n 's/^tag=//p' "${__promote_cache_file}" | head -n1 || true)"
    __cache_base="$(sed -n 's/^base=//p' "${__promote_cache_file}" | head -n1 || true)"
    __cache_source="$(sed -n 's/^source=//p' "${__promote_cache_file}" | head -n1 || true)"
    log_info "PROMOTE CACHE: path=${__promote_cache_file} present=yes tag=${__cache_tag:-<none>} base=${__cache_base:-<none>} source=${__cache_source:-<none>}"
else
    log_info "PROMOTE CACHE: path=${__promote_cache_file} present=no"
fi

# Landing override (vacío = restaurar rama original)
export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="${DEVTOOLS_LAND_ON_SUCCESS_BRANCH:-}"

cleanup_on_exit() {
    local exit_code=$?
    trap - EXIT INT TERM

    # Doctor no debe intentar borrar ramas ni aterrizar raro
    if [[ "${TARGET_ENV:-}" == "doctor" ]]; then
        exit "$exit_code"
    fi

    # ÉXITO: aterrizar primero y luego preguntar borrado (para cumplir "quedarme en destino")
    if [[ "$exit_code" -eq 0 ]]; then
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            exit 0
        fi
        local landed_ok=0
        # 1) aterrizar en rama destino si aplica
        if [[ -n "${DEVTOOLS_LAND_ON_SUCCESS_BRANCH:-}" ]]; then
            ui_info "🛬 Finalizando flujo (éxito): quedando en '${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}'..."
            if ! git checkout "${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}" >/dev/null 2>&1; then
                # Intentar tracking si existe en origin
                ensure_local_branch_tracks_remote "${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}" "origin" >/dev/null 2>&1 || true
                git checkout "${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}" >/dev/null 2>&1 || true
            fi
            local cur_branch
            cur_branch="$(git branch --show-current 2>/dev/null || echo "")"
            if [[ "$cur_branch" == "${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}" ]]; then
                landed_ok=1
            else
                log_warn "No pude aterrizar en '${DEVTOOLS_LAND_ON_SUCCESS_BRANCH}'. Omitiendo borrado de rama origen."
            fi
        fi

        # 2) preguntar borrado de rama origen (dev/local y si aterrizó bien)
        if [[ "$landed_ok" -eq 1 ]] \
            && [[ "${TARGET_ENV:-}" == "dev" || "${TARGET_ENV:-}" == "local" ]] \
            && declare -F maybe_delete_source_branch >/dev/null 2>&1; then
            maybe_delete_source_branch "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
        fi

        exit 0
    fi

    # FALLO/CANCEL: restaurar rama inicial
    ui_error "⛔ ABORTADO (seguridad): promote finalizó con error (rc=${exit_code})."
    ui_warn "↩️ Cleanup: restaurando rama original '${DEVTOOLS_PROMOTE_FROM_BRANCH:-}'."
    if declare -F git_restore_branch_safely >/dev/null 2>&1; then
        git_restore_branch_safely "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
    else
        ui_warn "Finalizando script. Volviendo a ${DEVTOOLS_PROMOTE_FROM_BRANCH:-}..."
        git checkout "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" >/dev/null 2>&1 || true
    fi

    exit "$exit_code"
}

trap 'cleanup_on_exit' EXIT INT TERM

# ==============================================================================
# 2. PARSEO DE ARGUMENTOS
# ==============================================================================
# Soporte simple para flags globales antes del comando
while [[ "$1" == -* ]]; do
    case "$1" in
        -y|--yes)
            export DEVTOOLS_ASSUME_YES=1
            shift
            ;;
        -n|--dry-run)
            export DEVTOOLS_DRY_RUN=1
            shift
            ;;
        --debug)
            export DEVTOOLS_DEBUG=1
            set -x
            shift
            ;;
        *)
            echo "Opción desconocida: $1"
            exit 1
            ;;
    esac
done

TARGET_ENV="${1:-}"
shift || true

REST_ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            export DEVTOOLS_DRY_RUN=1
            shift
            ;;
        *)
            REST_ARGS+=("$1")
            shift
            ;;
    esac
done

# Validar argumento requerido
if [[ -z "$TARGET_ENV" ]]; then
    ui_header "Git Promote - Gestor de Ciclo de Vida"
    echo "Uso: git promote [-y | --yes] [-n | --dry-run] [TARGET]"
    echo ""
    echo "Targets disponibles:"
    echo "  dev                 : Promocionar a DEV (actualiza origin/dev)"
    echo "  local               : Promocionar a LOCAL (usa origin/local por defecto)"
    echo "  staging             : Promocionar a STAGING (dev -> origin/staging)"
    echo "  prod                : Promocionar a PROD (staging -> origin/main)"
    echo "  dev-update [src]    : Integrar rama fuente hacia origin/dev-update (o usa: git promote <rama>)"
    echo "  hotfix [name|finish]: Crear/finalizar hotfix (hotfix/* -> main + dev)"
    echo "  doctor              : Verificar estado del repo (diagnóstico)"
    echo ""
    echo "Notas:"
    echo "  - Menú de seguridad ES OBLIGATORIO (excepto doctor)."
    echo "  - Si no hay TTY/UI (CI), define:"
    echo "      DEVTOOLS_PROMOTE_STRATEGY=merge-theirs|ff-only|merge|force"
    exit 1
fi


# ==============================================================================
# 3. PRE-FLIGHT DE SEGURIDAD (OBLIGATORIO) + MENÚ UNIVERSAL (OBLIGATORIO)
# ==============================================================================
# Regla: "Primero seguridad, luego el menú".
# Este bloque corre SIEMPRE (excepto en doctor/diagnóstico) antes de tocar ramas.
# - Valida que estamos en un repo.
# - Valida que origin existe y apunta a github.com.
# - (Opcional/recomendado) hace fetch estricto para no operar con refs viejas.
# Luego muestra el 🧯 MENÚ DE SEGURIDAD y define DEVTOOLS_PROMOTE_STRATEGY.

if [[ "${TARGET_ENV:-}" != "doctor" ]]; then
    # --------------------------------------------------------------------------
    # 3.1 PRE-FLIGHT (SEGURIDAD PRIMERO)
    # --------------------------------------------------------------------------
    ensure_repo_or_die
    if [[ "${DEVTOOLS_DRY_RUN:-0}" != "1" ]]; then
        ensure_origin_is_github_com_or_die

        if [[ "${DEVTOOLS_PROMOTE_OFFLINE_OK:-0}" == "1" ]]; then
            export DEVTOOLS_PROMOTE_OFFLINE=1
            log_warn "⚠️  OFFLINE: POSIBLE DESFASADO. Usando SOLO refs/tags locales."

            # Override en OFFLINE: no hacer fetch; usar refs locales disponibles
            ensure_local_branch_tracks_remote() {
                local branch="$1"
                local remote="${2:-origin}"

                if git show-ref --verify --quiet "refs/heads/${branch}"; then
                    return 0
                fi
                if git show-ref --verify --quiet "refs/remotes/${remote}/${branch}"; then
                    git checkout -b "$branch" "${remote}/${branch}" >/dev/null 2>&1 || return 1
                    return 0
                fi
                return 1
            }
        else
            # Fetch preferido (si falla por red, degradamos de forma explícita según target).
            fetch_rc=0
            git fetch origin --prune || fetch_rc=$?
            if [[ "$fetch_rc" -ne 0 ]]; then
                log_warn "FETCH FAILED: remote=origin rc=${fetch_rc} target=${TARGET_ENV:-?}"
                if [[ "${TARGET_ENV:-}" == "local" ]]; then
                    export DEVTOOLS_PROMOTE_OFFLINE=1
                    if [[ -z "${DEVTOOLS_PROMOTE_P0_MODE:-}" ]]; then
                        export DEVTOOLS_PROMOTE_P0_MODE="noop"
                    fi
                    log_warn "⚠️  Fetch falló; promote local continúa OFFLINE (mode=${DEVTOOLS_PROMOTE_P0_MODE})."
                elif [[ "${TARGET_ENV:-}" == "dev" ]] \
                    && [[ "${CI:-0}" == "1" || "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" || "${DEVTOOLS_ASSUME_YES:-0}" == "1" ]]; then
                    export DEVTOOLS_PROMOTE_OFFLINE=1
                    if [[ "${DEVTOOLS_PROMOTE_DEV_OFFLINE_NOOP:-0}" == "1" ]]; then
                        log_warn "⚠️  Fetch falló; promote dev continúa en modo OFFLINE-NOOP (opt-in explícito)."
                        log_warn "OFFLINE-NOOP ACTIVE: NO push, NO gate, NO argocd, NO tag update (si aplica)."
                    else
                        die "Fetch falló para promote dev en modo no interactivo. Reintenta con red o define DEVTOOLS_PROMOTE_DEV_OFFLINE_NOOP=1 para NOOP explícito."
                    fi
                else
                    die "Fetch falló. Activa DEVTOOLS_PROMOTE_OFFLINE_OK=1 para continuar sin red."
                fi
            fi
        fi

        # --------------------------------------------------------------------------
        # 3.2 MENÚ DE SEGURIDAD UNIVERSAL (OBLIGATORIO)
        # --------------------------------------------------------------------------
        export DEVTOOLS_PROMOTE_STRATEGY

        # Función definida en lib/core/utils.sh que muestra el menú con emojis
        DEVTOOLS_PROMOTE_STRATEGY="$(promote_choose_strategy_or_die)"

        # Confirmación extra para la opción ☢️ (Solo si no estamos en modo --yes)
        if [[ "$DEVTOOLS_PROMOTE_STRATEGY" == "force" && "${DEVTOOLS_ASSUME_YES:-0}" != "1" ]]; then
            echo
            log_warn "☢️ Elegiste FORCE UPDATE. Esto puede reescribir historia en ramas remotas."
            if ! ask_yes_no "¿Confirmas continuar con FORCE UPDATE?"; then
                die "Abortado por seguridad."
            fi
        fi

        # Feedback visual de la elección
        if [[ "${DEVTOOLS_ASSUME_YES:-0}" != "1" ]]; then
            log_info "✅ Estrategia seleccionada: $DEVTOOLS_PROMOTE_STRATEGY"
        fi
    else
        log_info "⚗️  Simulacion (--dry-run): no se haran cambios."
    fi
fi


# ==============================================================================
# 4. ENRUTAMIENTO (Router)
# ==============================================================================

case "$TARGET_ENV" in
    dev)
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="dev"
        source "${PROMOTE_LIB}/workflows/to-dev.sh"
        promote_to_dev
        ;;

    local)
        # Default: flujo LOCAL usa origin/local como base si existe
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="local"
        source "${PROMOTE_LIB}/workflows/to-local.sh"
        set +e
        ( promote_to_local )
        rc=$?
        set -e

        # Flujo local finalizado de forma intencional sin promover (exit/pr):
        # - no post-push
        # - no ensure_local_checkout
        # - no landing forzado por trap
        if [[ "$rc" -eq 42 || "$rc" -eq 43 ]]; then
            export DEVTOOLS_LAND_ON_SUCCESS_BRANCH=""
            exit 0
        fi

        local_ok=0

        if [[ "$rc" -eq 0 ]]; then
            local_ok=1
        elif [[ "${DEVTOOLS_PROMOTE_OFFLINE:-0}" == "1" ]]; then
            if git show-ref --verify --quiet "refs/heads/local"; then
                last_msg="$(git log -1 --format=%s local 2>/dev/null || true)"
                if printf '%s' "$last_msg" | grep -q '^chore(local):'; then
                    log_warn "⚠️  OFFLINE: posible fallo de push a origin/local."
                    log_warn "El commit quedó listo en la rama local."
                    echo "Para pushear cuando vuelva la red:"
                    echo "  git checkout local"
                    echo "  git push origin local"
                    local_ok=1
                    rc=0
                fi
            fi
        fi

        if [[ "$local_ok" -eq 1 ]]; then
            if [[ -f "${LIB_DIR}/ci-workflow.sh" ]]; then
                # Reusar el mismo flujo post-push de verificación de entorno.
                # Usa base 'local' para evitar PRs accidentales a ramas protegidas.
                source "${LIB_DIR}/ci-workflow.sh"

                set +e
                (
                    post_push_log="$(mktemp /tmp/promote-local-post-push.XXXXXX.log)"
                    chmod 600 "$post_push_log"
                    cleanup_local_post_push_log() {
                        rm -f "${post_push_log}" >/dev/null 2>&1 || true
                    }
                    trap cleanup_local_post_push_log EXIT

                    set +e
                    POST_PUSH_FLOW=true run_post_push_flow "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" "local" >"${post_push_log}" 2>&1
                    post_push_rc=$?
                    set -e

                    if [[ "$post_push_rc" -eq 0 ]]; then
                        if declare -F render_local_finish_summary >/dev/null 2>&1; then
                            render_local_finish_summary
                        else
                            echo "✅ Promoción local: cierre limpio completado."
                        fi
                        exit 0
                    fi

                    echo "❌ Post-push local falló."
                    echo "📄 Log: ${post_push_log}"
                    tail -n 80 "${post_push_log}" || true
                    exit "$post_push_rc"
                )
                post_push_rc=$?
                set -e
                if [[ "$post_push_rc" -ne 0 ]]; then
                    rc="$post_push_rc"
                fi
            fi

            ensure_local_checkout
        fi

        exit "$rc"
        ;;

    staging)
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="staging"
        source "${PROMOTE_LIB}/workflows/to-staging.sh"
        promote_to_staging
        ;;

    prod)
        # prod = entorno; la rama real es main
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="main"
        source "${PROMOTE_LIB}/workflows/to-prod.sh"
        promote_to_prod
        ;;

    dev-update|feature/dev-update)
        # Workflow de utilidad para squash local hacia la rama de integración
        # Cargar módulo dev-update (asumimos que existe o está en to-dev utils)
        source "${PROMOTE_LIB}/workflows/dev-update.sh"
        
        # En éxito: aterrizar en dev-update (rama promovida)
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="dev-update"
        
        # Si NO se pasó rama fuente, usamos la rama actual (DEVTOOLS_PROMOTE_FROM_BRANCH)
        # Esto hace que: `git promote dev-update` (o `git promote feature/dev-update`) funcione sin sorpresas.
        src_branch="${REST_ARGS[0]:-}"
        if [[ -z "${src_branch:-}" ]]; then
            src_branch="${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
            log_info "ℹ️  No se indicó rama fuente. Usando tu rama actual: ${src_branch}"
        fi

        # Guardias: evitar intentos absurdos (fuente inválida)
        case "${src_branch:-}" in
            ""|"(detached)"|dev-update|dev|main|staging)
                die "⛔ Rama fuente inválida para dev-update: '${src_branch}'. Usa una rama de trabajo (no protegida) como fuente."
                ;;
        esac

        promote_dev_update_squash "${src_branch}"
        ;;

    feature/*)
        # Alias directo para squashear una feature
        source "${PROMOTE_LIB}/workflows/dev-update.sh"
        # En éxito: aterrizar en dev-update (rama promovida)
        export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="dev-update"
        promote_dev_update_squash "$TARGET_ENV"
        ;;

    hotfix)
        source "${PROMOTE_LIB}/workflows/hotfix.sh"
        promote_hotfix_start "${REST_ARGS[0]:-}"
        ;;

    doctor)
        source "${LIB_DIR}/checks/doctor.sh"
        run_doctor
        ;;

    *)
        # Si es una rama (local o remota), la tratamos como fuente hacia dev-update (flujo único).
        if git show-ref --verify --quiet "refs/heads/${TARGET_ENV}" || git show-ref --verify --quiet "refs/remotes/origin/${TARGET_ENV}"; then
            source "${PROMOTE_LIB}/workflows/dev-update.sh"
            export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="dev-update"
            promote_dev_update_apply "${TARGET_ENV}"
        else
            ui_error "Target no reconocido: $TARGET_ENV"
            exit 1
        fi
        ;;
esac

exit 0

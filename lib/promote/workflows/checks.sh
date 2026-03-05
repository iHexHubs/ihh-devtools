#!/usr/bin/env bash
# Promote workflow helpers: checks
# CHECKS.SH = ÚNICA FUENTE DE VERDAD (validaciones por SHA)
# - Tabla de estado por workflow requerido
# - Gate por SHA (PENDING con retry corto)
# - Smart pick para --watch (FAILURE > IN_PROGRESS)
# Este módulo contiene las funciones de verificación y espera (polling):
# - wait_for_release_please_pr_number_or_die
# - wait_for_tag_on_sha_or_die
# - wait_for_workflow_success_on_ref_or_sha_or_die
#
# Dependencias: Se asume que utils.sh (logging, is_tty) está cargado por el orquestador.

# ==============================================================================
# HELPERS: Checks y Esperas (Polling)
# ==============================================================================

print_tags_at_sha() {
    local sha_full="$1"
    local label="${2:-tags@sha}"
    [[ -n "${sha_full:-}" ]] || return 0
    GIT_TERMINAL_PROMPT=0 git fetch origin --tags --force >/dev/null 2>&1 || true
    local tags
    tags="$(git tag --points-at "$sha_full" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    if [[ -n "${tags:-}" ]]; then
        log_info "🏷️  ${label}: ${tags}"
    else
        log_info "🏷️  ${label}: (none)"
    fi
}

print_run_link() {
    local run_id="$1"
    local label="${2:-run}"
    [[ -n "${run_id:-}" ]] || return 0
    local url
    url="$(GH_PAGER=cat gh run view "$run_id" --json htmlURL --jq '.htmlURL' 2>/dev/null || true)"
    if [[ -n "${url:-}" && "${url:-null}" != "null" ]]; then
        log_info "🔗 ${label} URL: ${url}"
    fi
}

watch_workflow_run_or_die() {
    # Args: run_id, label, timeout, interval
    local run_id="$1"
    local label="${2:-workflow}"
    local timeout="${3:-1800}"
    local interval="${4:-10}"
    local elapsed=0

    [[ -n "${run_id:-}" ]] || { log_error "Falta run_id para observar ${label}."; return 1; }

    if ! command -v gh >/dev/null 2>&1; then
        log_error "No se encontró 'gh'. No puedo observar ${label}."
        return 1
    fi

    if is_tty; then
        log_info "📺 Mostrando progreso en vivo del run_id=$run_id (GitHub Actions)..."
        if GH_PAGER=cat gh run watch "$run_id" --exit-status; then
            log_success "🏗️  ${label} OK (run_id=$run_id)"
            return 0
        fi
        log_error "${label} falló (run_id=$run_id)"
        return 1
    fi

    while true; do
        local status conclusion
        status="$(GH_PAGER=cat gh run view "$run_id" --json status --jq '.status' 2>/dev/null || echo "")"
        conclusion="$(GH_PAGER=cat gh run view "$run_id" --json conclusion --jq '.conclusion' 2>/dev/null || echo "")"

        if [[ "$status" == "completed" ]]; then
            if [[ "$conclusion" == "success" ]]; then
                log_success "🏗️  ${label} OK (run_id=$run_id)"
                return 0
            fi
            log_error "${label} falló (run_id=$run_id, conclusion=$conclusion)"
            return 1
        fi

        if (( elapsed >= timeout )); then
            log_error "Timeout esperando a que termine ${label} (run_id=$run_id)"
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

watch_workflow_run_if_any() {
    # Args: run_id, label, timeout, interval
    local run_id="$1"
    local label="${2:-watch}"
    local timeout="${3:-1800}"
    local interval="${4:-10}"

    [[ -n "${run_id:-}" ]] || return 0
    is_tty || return 0
    command -v gh >/dev/null 2>&1 || return 0

    echo
    log_info "📺 ${label}"
    watch_workflow_run_or_die "$run_id" "$label" "$timeout" "$interval" || true
    echo
    return 0
}

wait_for_release_please_pr_number_or_die() {
    # Espera a que aparezca un PR head release-please--* hacia base dev
    local timeout="${DEVTOOLS_RP_PR_WAIT_TIMEOUT_SECONDS:-900}"
    local interval="${DEVTOOLS_RP_PR_WAIT_POLL_SECONDS:-5}"
    local elapsed=0

    # Si timeout=0, no esperamos (comportamiento útil para repos donde el bot puede no abrir PR)
    if [[ "${timeout}" == "0" ]]; then
        return 1
    fi

    while true; do
        local pr_number
        pr_number="$(
          GH_PAGER=cat gh pr list --base dev --state open --json number,headRefName --jq \
          '.[] | select(.headRefName | startswith("release-please--")) | .number' 2>/dev/null | head -n 1
        )"

        # Solo aceptamos números (evita propagar mensajes/ruido como "pr_number")
        if [[ "${pr_number:-}" =~ ^[0-9]+$ ]]; then
            echo "$pr_number"
            return 0
        fi

        if (( elapsed >= timeout )); then
            log_error "Timeout esperando PR release-please--* hacia dev." >&2
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

wait_for_tag_on_sha_or_die() {
    # Args: sha_full, pattern_regex, label
    local sha_full="$1"
    local pattern="$2"
    local label="${3:-tag}"
    local timeout="${DEVTOOLS_TAG_WAIT_TIMEOUT_SECONDS:-900}"
    local interval="${DEVTOOLS_TAG_WAIT_POLL_SECONDS:-5}"
    local elapsed=0

    log_info "🏷️  Esperando ${label} en SHA ${sha_full:0:7} (pattern: ${pattern})..."

    while true; do
        GIT_TERMINAL_PROMPT=0 git fetch origin --tags --force >/dev/null 2>&1 || true
        local found
        found="$(git tag --points-at "$sha_full" 2>/dev/null | grep -E "$pattern" | head -n 1 || true)"
        if [[ -n "${found:-}" ]]; then
            log_success "🏷️  Tag detectado: $found"
            echo "$found"
            return 0
        fi

        if (( elapsed >= timeout )); then
            log_error "Timeout esperando ${label} en SHA ${sha_full:0:7}"
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

wait_for_workflow_success_on_ref_or_sha_or_die() {
    # Args: workflow_file, sha_full, optional ref (branch/tag)
    local wf_file="$1"
    local sha_full="$2"
    local ref="${3:-}"
    local label="${4:-workflow}"
    local timeout="${DEVTOOLS_BUILD_WAIT_TIMEOUT_SECONDS:-1800}"
    local interval="${DEVTOOLS_BUILD_WAIT_POLL_SECONDS:-10}"
    local elapsed=0

    if [[ "${DEVTOOLS_SKIP_WAIT_BUILD:-0}" == "1" ]]; then
        log_warn "DEVTOOLS_SKIP_WAIT_BUILD=1 -> Omitiendo espera de ${label}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_error "No se encontró 'gh'. No puedo verificar ${label} en GitHub Actions."
        return 1
    fi

    log_info "🏗️  Esperando ${label} (${wf_file}) en SHA ${sha_full:0:7}..."

    local run_id=""

    while true; do
        local list_out=""
        local list_rc=0
        local list_err=""
        if [[ -n "${ref:-}" ]]; then
            list_out="$(
                GH_PAGER=cat gh run list --workflow "$wf_file" --branch "$ref" -L 30 \
                --json databaseId,headSha,status,conclusion \
                --jq ".[] | select(.headSha==\"$sha_full\") | .databaseId" 2>&1
            )"
            list_rc=$?
            if [[ "$list_rc" -ne 0 ]]; then
                list_err="$(printf '%s\n' "${list_out}" | head -n 2 | tr '\n' ' ')"
                log_error "No pude consultar runs de ${wf_file} en ref=${ref} (rc=${list_rc}): ${list_err}"
                return 1
            fi
            run_id="$(printf '%s\n' "${list_out}" | head -n 1)"
        fi

        if [[ -z "${run_id:-}" ]]; then
            list_out="$(
                GH_PAGER=cat gh run list --workflow "$wf_file" -L 30 \
                --json databaseId,headSha,status,conclusion \
                --jq ".[] | select(.headSha==\"$sha_full\") | .databaseId" 2>&1
            )"
            list_rc=$?
            if [[ "$list_rc" -ne 0 ]]; then
                list_err="$(printf '%s\n' "${list_out}" | head -n 2 | tr '\n' ' ')"
                log_error "No pude consultar runs de ${wf_file} (rc=${list_rc}): ${list_err}"
                return 1
            fi
            run_id="$(printf '%s\n' "${list_out}" | head -n 1)"
        fi

        if [[ -n "${run_id:-}" ]]; then
            break
        fi

        if (( elapsed >= timeout )); then
            log_error "Timeout esperando que aparezca un run de ${wf_file} para SHA ${sha_full:0:7}"
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    # Link del run (para no ir a la web a ciegas)
    print_run_link "$run_id" "${label} (run_id=${run_id})"
    watch_workflow_run_or_die "$run_id" "$label" "$timeout" "$interval"
}

# ==============================================================================
# GUARDIA DE INTEGRIDAD: Validación de Working Tree Limpio
# ------------------------------------------------------------------------------
# Acción: Verifica si hay cambios locales (staged o unstaged).
# Efecto: Aborta la ejecución (exit 1) si el repositorio está "sucio".
# Razón: La promoción aplastante sobreescribe el estado actual; un repo limpio
#        garantiza que no se pierda código sin commitear.
# ==============================================================================
if ! declare -F ensure_clean_git_or_die >/dev/null 2>&1; then
    ensure_clean_git_or_die() {
        if ! declare -F ensure_clean_git >/dev/null 2>&1; then
            local dot_dir=".devtools"
            log_error "❌ Error: falta ensure_clean_git. Carga ${dot_dir}/lib/core/git-ops.sh antes de checks.sh."
            exit 1
        fi
        ensure_clean_git "$@"
    }
fi

# ==============================================================================
# CONFIG: Workflows requeridos (centralizado en <vendor_dir>/config/workflows.conf)
# ==============================================================================

resolve_workflows_conf_file() {
    local dot_dir=".devtools"
    # 1) Si estamos dentro del repo vendorizado (REPO_ROOT == vendor_dir)
    local root="${REPO_ROOT:-.}"
    if [[ -f "${root}/config/workflows.conf" ]]; then
        echo "${root}/config/workflows.conf"
        return 0
    fi

    # 2) Si estamos en un superproyecto que contiene vendor_dir (WORKSPACE_ROOT)
    if [[ -n "${WORKSPACE_ROOT:-}" && -f "${WORKSPACE_ROOT}/${dot_dir}/config/workflows.conf" ]]; then
        echo "${WORKSPACE_ROOT}/${dot_dir}/config/workflows.conf"
        return 0
    fi

    # 3) Fallback: cwd + vendor_dir/config
    if [[ -f "${dot_dir}/config/workflows.conf" ]]; then
        echo "${dot_dir}/config/workflows.conf"
        return 0
    fi

    return 1
}

print_workflows_conf_guidance() {
    local dot_dir=".devtools"
    local resolved="${1:-}"
    echo "   Archivo esperado: ${dot_dir}/config/workflows.conf"
    if [[ -n "${resolved:-}" ]]; then
        echo "   Archivo resuelto: ${resolved}"
    else
        echo "   Archivo resuelto: (no encontrado)"
    fi
    echo "   Tip: revisa REPO_ROOT (${REPO_ROOT:-<vacío>}) y WORKSPACE_ROOT (${WORKSPACE_ROOT:-<vacío>})."
    echo "   Ejemplo (copy/paste):"
    cat <<'EOF'
REQUIRED_WORKFLOWS_DEV=(
  "release-please.yaml"
  "build-push.yaml"
  "pipeline-ci.yaml"
)
REQUIRED_WORKFLOWS_LOCAL=()
EOF
}

load_workflows_conf_or_die() {
    local f=""
    f="$(resolve_workflows_conf_file 2>/dev/null || true)"

    if [[ -z "${f:-}" || ! -f "$f" ]]; then
        log_error "❌ Error: No se encontró workflows.conf."
        print_workflows_conf_guidance "$f"
        return 1
    fi

    # Respetar set -u del caller (temporalmente lo apagamos para source seguro)
    local nounset_was_on=0
    case "$-" in *u*) nounset_was_on=1 ;; esac
    set +u
    # shellcheck disable=SC1090
    source "$f"
    (( nounset_was_on )) && set -u

    export DEVTOOLS_WORKFLOWS_CONF_FILE="$f"
    return 0
}

load_required_workflows_dev_or_die() {
    load_workflows_conf_or_die || return 1

    if ! declare -p REQUIRED_WORKFLOWS_DEV >/dev/null 2>&1; then
        log_error "❌ workflows.conf no define REQUIRED_WORKFLOWS_DEV."
        print_workflows_conf_guidance "${DEVTOOLS_WORKFLOWS_CONF_FILE:-}"
        return 1
    fi

    if [[ "${#REQUIRED_WORKFLOWS_DEV[@]}" -eq 0 ]]; then
        log_error "❌ REQUIRED_WORKFLOWS_DEV está vacío."
        print_workflows_conf_guidance "${DEVTOOLS_WORKFLOWS_CONF_FILE:-}"
        return 1
    fi

    return 0
}

load_required_workflows_local_or_warn() {
    load_workflows_conf_or_die || return 1

    if ! declare -p REQUIRED_WORKFLOWS_LOCAL >/dev/null 2>&1; then
        log_warn "⚠️ workflows.conf no define REQUIRED_WORKFLOWS_LOCAL. Omitiendo gate por SHA para promote local."
        REQUIRED_WORKFLOWS_LOCAL=()
    fi

    return 0
}

gate_validate_required_workflows_exist_locally_or_die() {
    local -a workflows=( "$@" )
    local repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local missing=()
    local wf=""

    for wf in "${workflows[@]}"; do
        [[ -n "${wf:-}" ]] || continue
        if [[ ! -f "${repo_root}/.github/workflows/${wf}" ]]; then
            missing+=( "${wf}" )
        fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
        local missing_csv=""
        missing_csv="$(IFS=', '; echo "${missing[*]}")"
        log_error "❌ Gate inválido: no existe(n) workflow(s) requerido(s) en ${repo_root}/.github/workflows: ${missing_csv}"
        log_error "👉 Corrige config/workflows.conf (REQUIRED_WORKFLOWS_*) o habilita esos workflows antes de promover."
        return 1
    fi

    return 0
}

# ==============================================================================
# API: obtener meta de un workflow para un SHA exacto (status + conclusion + run_id)
# ==============================================================================

__wf_meta_for_sha_once() {
    # Args: wf_file sha_full ref(optional)
    local wf_file="$1"
    local sha_full="$2"
    local ref="${3:-}"

    [[ -n "${wf_file:-}" && -n "${sha_full:-}" ]] || return 1

    local line=""
    local raw=""
    local query_rc=0
    if [[ -n "${ref:-}" ]]; then
        raw="$(
            GH_PAGER=cat gh run list --workflow "$wf_file" --branch "$ref" -L 50 \
            --json databaseId,headSha,status,conclusion \
            --jq ".[] | select(.headSha==\"$sha_full\") | \"\(.databaseId)|\(.status)|\(.conclusion // \"\")\"" \
            2>&1
        )"
        query_rc=$?
    else
        raw="$(
            GH_PAGER=cat gh run list --workflow "$wf_file" -L 50 \
            --json databaseId,headSha,status,conclusion \
            --jq ".[] | select(.headSha==\"$sha_full\") | \"\(.databaseId)|\(.status)|\(.conclusion // \"\")\"" \
            2>&1
        )"
        query_rc=$?
    fi

    if [[ "$query_rc" -ne 0 ]]; then
        DEVTOOLS_GATE_LAST_GH_ERROR="$(printf '%s\n' "${raw}" | head -n 2 | tr '\n' ' ')"
        return 2
    fi

    line="$(printf '%s\n' "${raw}" | head -n 1)"
    [[ -n "${line:-}" ]] || return 1
    echo "$line"
    return 0
}

# ==============================================================================
# GATE: workflows requeridos por SHA (tabla + PENDING retry + smart pick)
# ==============================================================================

# Output global para “smart watch”
DEVTOOLS_GATE_SELECTED_RUN_ID=""
DEVTOOLS_GATE_SELECTED_WORKFLOW=""
DEVTOOLS_GATE_SELECTED_REASON=""
DEVTOOLS_GATE_MISSING_COUNT=0
DEVTOOLS_GATE_TOTAL_COUNT=0
DEVTOOLS_GATE_IN_PROGRESS_COUNT=0
DEVTOOLS_GATE_FAILED_COUNT=0
DEVTOOLS_GATE_MISSING_WORKFLOWS=()
DEVTOOLS_GATE_LAST_GH_ERROR=""

gate_fail_on_annotations_enabled() {
    local value="${GATE_FAIL_ON_ANNOTATIONS:-${DEVTOOLS_GATE_FAIL_ON_ANNOTATIONS:-0}}"
    [[ "$value" == "1" ]]
}

gate_auto_dispatch_on_no_run_enabled() {
    local value="${DEVTOOLS_GATE_AUTO_DISPATCH_ON_NO_RUN:-1}"
    [[ "$value" == "1" ]]
}

gate_is_offline_mode_enabled() {
    [[ "${DEVTOOLS_PROMOTE_OFFLINE_OK:-0}" == "1" || "${DEVTOOLS_OFFLINE:-0}" == "1" || "${OFFLINE:-0}" == "1" ]]
}

gate_try_dispatch_missing_workflows_once() {
    local ref="${1:-}"
    shift || true
    local -a workflows=( "$@" )

    gate_auto_dispatch_on_no_run_enabled || return 1
    [[ -n "${ref:-}" ]] || return 1
    command -v gh >/dev/null 2>&1 || return 1
    gate_is_offline_mode_enabled && return 1
    [[ "${#workflows[@]}" -gt 0 ]] || return 1

    local wf=""
    local dispatched=0
    local dispatch_out=""
    local dispatch_rc=0
    local dispatch_err=""
    for wf in "${workflows[@]}"; do
        [[ -n "${wf:-}" ]] || continue
        log_warn "⏳ Auto-disparo: workflow faltante ${wf} en ref ${ref}."
        dispatch_out="$(GH_PAGER=cat gh workflow run "${wf}" --ref "${ref}" 2>&1)"
        dispatch_rc=$?
        if [[ "$dispatch_rc" -eq 0 ]]; then
            log_info "✅ Workflow disparado: ${wf} (ref=${ref})."
            dispatched=1
        else
            dispatch_err="$(printf '%s\n' "${dispatch_out}" | head -n 2 | tr '\n' ' ')"
            log_warn "No pude disparar ${wf} (rc=${dispatch_rc}): ${dispatch_err}"
        fi
    done

    [[ "$dispatched" -eq 1 ]]
}

gate_annotations_count_for_run() {
    local run_id="$1"
    [[ -n "${run_id:-}" ]] || { echo "0"; return 0; }
    command -v gh >/dev/null 2>&1 || { echo "0"; return 0; }

    # Campo opcional en GH CLI; si no existe, se asume 0 para no romper compatibilidad.
    local count=""
    count="$(
        GH_PAGER=cat gh run view "$run_id" --json annotations --jq '(.annotations // []) | length' 2>/dev/null \
            || true
    )"
    [[ "${count:-}" =~ ^[0-9]+$ ]] || count="0"
    echo "$count"
}

gate_required_workflows_on_sha() {
    # Args: sha_full ref workflows...
    local sha_full="$1"
    local ref="$2"
    shift 2
    local -a workflows=( "$@" )

    local tries="${DEVTOOLS_GATE_PENDING_TRIES:-3}"
    local interval="${DEVTOOLS_GATE_PENDING_POLL_SECONDS:-10}"

    DEVTOOLS_GATE_SELECTED_RUN_ID=""
    DEVTOOLS_GATE_SELECTED_WORKFLOW=""
    DEVTOOLS_GATE_SELECTED_REASON=""
    DEVTOOLS_GATE_MISSING_COUNT=0
    DEVTOOLS_GATE_TOTAL_COUNT="${#workflows[@]}"
    DEVTOOLS_GATE_IN_PROGRESS_COUNT=0
    DEVTOOLS_GATE_FAILED_COUNT=0
    DEVTOOLS_GATE_MISSING_WORKFLOWS=()

    [[ -n "${sha_full:-}" ]] || { log_error "gate: falta sha"; return 1; }
    [[ "${#workflows[@]}" -gt 0 ]] || { log_error "gate: no workflows"; return 1; }

    echo
    echo "┌───────────────────────────────────────────────────────────────"
    echo "│ 🔎 Gate por SHA: ${sha_full:0:7}  (ref=${ref})"
    [[ -n "${DEVTOOLS_WORKFLOWS_CONF_FILE:-}" ]] && echo "│ config: ${DEVTOOLS_WORKFLOWS_CONF_FILE}"
    echo "├───────────────────────────────┬──────────────┬───────────────"
    echo "│ Workflow                      │ Estado       │ Conclusión"
    echo "├───────────────────────────────┼──────────────┼───────────────"

    local all_ok=1
    local wf
    for wf in "${workflows[@]}"; do
        local meta=""
        local meta_rc=1
        local i=0
        while (( i < tries )); do
            meta="$(__wf_meta_for_sha_once "$wf" "$sha_full" "$ref" 2>/dev/null)"
            meta_rc=$?
            if [[ "$meta_rc" -eq 0 && -n "${meta:-}" ]]; then
                break
            fi
            if [[ "$meta_rc" -eq 2 ]]; then
                break
            fi
            i=$((i+1))
            (( i < tries )) && sleep "$interval"
        done

        local run_id="" status="" conclusion="" state_icon="" state_txt=""

        if [[ "$meta_rc" -eq 2 ]]; then
            state_icon="❌"
            status="ERROR"
            conclusion="gh api"
            all_ok=0
            DEVTOOLS_GATE_FAILED_COUNT=$((DEVTOOLS_GATE_FAILED_COUNT + 1))
            log_error "No pude consultar runs de ${wf} (ref=${ref:-n/a}): ${DEVTOOLS_GATE_LAST_GH_ERROR:-error desconocido}"
        elif [[ -z "${meta:-}" ]]; then
            # No run todavía: PENDING (bloquea)
            state_icon="⏳"
            status="PENDING"
            conclusion="(no run)"
            all_ok=0
            DEVTOOLS_GATE_MISSING_COUNT=$((DEVTOOLS_GATE_MISSING_COUNT + 1))
            DEVTOOLS_GATE_MISSING_WORKFLOWS+=( "$wf" )
        else
            IFS='|' read -r run_id status conclusion <<< "$meta"
            conclusion="${conclusion:-}"

            if [[ "$status" != "completed" ]]; then
                state_icon="⏳"
                status="${status:-IN_PROGRESS}"
                conclusion="${conclusion:-}"
                all_ok=0
                DEVTOOLS_GATE_IN_PROGRESS_COUNT=$((DEVTOOLS_GATE_IN_PROGRESS_COUNT + 1))
                # pick 2: IN_PROGRESS si no hay failure elegido
                if [[ -z "${DEVTOOLS_GATE_SELECTED_RUN_ID:-}" ]]; then
                    DEVTOOLS_GATE_SELECTED_RUN_ID="$run_id"
                    DEVTOOLS_GATE_SELECTED_WORKFLOW="$wf"
                    DEVTOOLS_GATE_SELECTED_REASON="in_progress"
                fi
            else
                if [[ "$conclusion" == "success" ]]; then
                    # Por defecto no bloquea por annotations cuando el run terminó success.
                    if gate_fail_on_annotations_enabled; then
                        local annotations_count=0
                        annotations_count="$(gate_annotations_count_for_run "$run_id")"
                        if [[ "${annotations_count:-0}" =~ ^[0-9]+$ ]] && (( annotations_count > 0 )); then
                            state_icon="❌"
                            status="completed"
                            conclusion="success+annotations(${annotations_count})"
                            all_ok=0
                            DEVTOOLS_GATE_FAILED_COUNT=$((DEVTOOLS_GATE_FAILED_COUNT + 1))
                            if [[ "${DEVTOOLS_GATE_SELECTED_REASON:-}" != "failure" ]]; then
                                DEVTOOLS_GATE_SELECTED_RUN_ID="$run_id"
                                DEVTOOLS_GATE_SELECTED_WORKFLOW="$wf"
                                DEVTOOLS_GATE_SELECTED_REASON="failure"
                            fi
                        else
                            state_icon="✅"
                            status="completed"
                            conclusion="success"
                        fi
                    else
                        state_icon="✅"
                        status="completed"
                        conclusion="success"
                    fi
                else
                    state_icon="❌"
                    status="completed"
                    conclusion="${conclusion:-unknown}"
                    all_ok=0
                    DEVTOOLS_GATE_FAILED_COUNT=$((DEVTOOLS_GATE_FAILED_COUNT + 1))
                    # pick 1: FAILURE siempre gana
                    if [[ "${DEVTOOLS_GATE_SELECTED_REASON:-}" != "failure" ]]; then
                        DEVTOOLS_GATE_SELECTED_RUN_ID="$run_id"
                        DEVTOOLS_GATE_SELECTED_WORKFLOW="$wf"
                        DEVTOOLS_GATE_SELECTED_REASON="failure"
                    fi
                fi
            fi
        fi

        printf "│ %-29s │ %-12s │ %-13s\n" "$wf" "${state_icon} ${status}" "${conclusion}"
    done

    echo "└───────────────────────────────┴──────────────┴───────────────"

    if [[ "$all_ok" -eq 1 ]]; then
        log_success "✅ Gate OK (todos los workflows requeridos están SUCCESS para este SHA)."
        return 0
    fi

    log_error "🚨 Gate ROJO (faltan runs o hay fallos para este SHA)."
    if (( DEVTOOLS_GATE_MISSING_COUNT > 0 )); then
        local missing_csv=""
        missing_csv="$(IFS=', '; echo "${DEVTOOLS_GATE_MISSING_WORKFLOWS[*]}")"
        log_error "Faltan ${DEVTOOLS_GATE_MISSING_COUNT}/${DEVTOOLS_GATE_TOTAL_COUNT} workflows: ${missing_csv}"
    fi
    if [[ -n "${DEVTOOLS_GATE_SELECTED_RUN_ID:-}" ]]; then
        print_run_link "${DEVTOOLS_GATE_SELECTED_RUN_ID}" "watch candidate (${DEVTOOLS_GATE_SELECTED_WORKFLOW})"
    fi
    return 1
}

gate_watch_selected_run_if_any() {
    # Usa el smart pick del gate. No aborta el proceso si falla.
    local label="[AUTO-WATCH] ${DEVTOOLS_GATE_SELECTED_WORKFLOW} (reason=${DEVTOOLS_GATE_SELECTED_REASON})"
    watch_workflow_run_if_any \
        "${DEVTOOLS_GATE_SELECTED_RUN_ID:-}" \
        "$label" \
        "${DEVTOOLS_BUILD_WAIT_TIMEOUT_SECONDS:-1800}" \
        "${DEVTOOLS_BUILD_WAIT_POLL_SECONDS:-10}"
}

gate_required_workflows_on_sha_or_die() {
    # Args: sha_full, ref(optional), scope(optional: dev|staging|prod|hotfix|local)
    local sha_full="$1"
    local ref="${2:-}"
    local scope="${3:-dev}"
    local timeout="${DEVTOOLS_GATE_WAIT_TIMEOUT_SECONDS:-${DEVTOOLS_BUILD_WAIT_TIMEOUT_SECONDS:-900}}"
    local interval="${DEVTOOLS_GATE_WAIT_POLL_SECONDS:-${DEVTOOLS_BUILD_WAIT_POLL_SECONDS:-10}}"
    local no_run_dispatch_attempted=0

    [[ -n "${sha_full:-}" ]] || { log_error "gate-by-sha: falta sha"; return 1; }

    if [[ "${DEVTOOLS_SKIP_WAIT_BUILD:-0}" == "1" ]]; then
        log_warn "DEVTOOLS_SKIP_WAIT_BUILD=1 -> Omitiendo espera de gate por SHA."
        return 0
    fi

    local -a workflows=()
    case "$scope" in
        local)
            load_required_workflows_local_or_warn || return 1
            workflows=( "${REQUIRED_WORKFLOWS_LOCAL[@]}" )
            if [[ "${#workflows[@]}" -eq 0 ]]; then
                log_warn "⚠️ REQUIRED_WORKFLOWS_LOCAL vacío: omitiendo gate por SHA para promote local."
                return 0
            fi
            ;;
        *)
            load_required_workflows_dev_or_die || return 1
            local scope_upper env_key
            scope_upper="$(echo "$scope" | tr '[:lower:]' '[:upper:]')"
            env_key="REQUIRED_WORKFLOWS_${scope_upper}"

            if declare -p "${env_key}" >/dev/null 2>&1; then
                # shellcheck disable=SC2034
                local -a scoped_workflows=()
                eval "scoped_workflows=(\"\${${env_key}[@]}\")"
                if [[ "${#scoped_workflows[@]}" -gt 0 ]]; then
                    workflows=( "${scoped_workflows[@]}" )
                else
                    log_warn "⚠️ ${env_key} vacío: usando REQUIRED_WORKFLOWS_DEV."
                    workflows=( "${REQUIRED_WORKFLOWS_DEV[@]}" )
                fi
            else
                workflows=( "${REQUIRED_WORKFLOWS_DEV[@]}" )
            fi
            ;;
    esac

    gate_validate_required_workflows_exist_locally_or_die "${workflows[@]}" || return 1

    [[ "${timeout}" =~ ^[0-9]+$ ]] || timeout=1800
    [[ "${interval}" =~ ^[0-9]+$ ]] || interval=10
    (( interval >= 1 )) || interval=1

    local deadline=$((SECONDS + timeout))
    while true; do
        local rc=0
        if gate_required_workflows_on_sha "$sha_full" "$ref" "${workflows[@]}"; then
            rc=0
        else
            rc=$?
        fi
        if [[ "$rc" -eq 0 ]]; then
            return 0
        fi

        if [[ "${DEVTOOLS_GATE_FAIL_FAST_ON_FAILURE:-1}" == "1" ]] && (( DEVTOOLS_GATE_FAILED_COUNT > 0 )); then
            log_error "❌ Gate en failure para ${sha_full:0:7} (ref=${ref:-n/a}). Fail-fast activado."
            return 1
        fi

        if [[ "${DEVTOOLS_GATE_FAIL_FAST_ON_NO_RUN:-1}" == "1" ]] \
            && (( DEVTOOLS_GATE_MISSING_COUNT == DEVTOOLS_GATE_TOTAL_COUNT )) \
            && [[ -z "${DEVTOOLS_GATE_SELECTED_RUN_ID:-}" ]]; then
            if [[ "$no_run_dispatch_attempted" -eq 0 ]] \
                && gate_try_dispatch_missing_workflows_once "${ref}" "${DEVTOOLS_GATE_MISSING_WORKFLOWS[@]}"; then
                no_run_dispatch_attempted=1
                log_warn "⏳ Gate sin runs: reintentando después de auto-disparo."
                sleep "$interval"
                continue
            fi
            local missing_csv=""
            missing_csv="$(IFS=', '; echo "${DEVTOOLS_GATE_MISSING_WORKFLOWS[*]}")"
            log_error "❌ Gate sin runs para ${sha_full:0:7} (ref=${ref:-n/a}): ${missing_csv}"
            log_error "👉 Acción: dispara workflow manual (gh workflow run <wf> --ref ${ref:-<rama>}) o ajusta REQUIRED_WORKFLOWS_*."
            log_error "👉 Para desactivar fail-fast temporalmente: DEVTOOLS_GATE_FAIL_FAST_ON_NO_RUN=0."
            return 1
        fi

        # Si hay run en progreso/fallo, observar y luego recalcular con data fresca.
        if [[ -n "${DEVTOOLS_GATE_SELECTED_RUN_ID:-}" ]]; then
            gate_watch_selected_run_if_any || true
            if gate_required_workflows_on_sha "$sha_full" "$ref" "${workflows[@]}"; then
                rc=0
            else
                rc=$?
            fi
            if [[ "$rc" -eq 0 ]]; then
                return 0
            fi
        fi

        if (( SECONDS >= deadline )); then
            break
        fi

        if (( DEVTOOLS_GATE_MISSING_COUNT > 0 )); then
            local missing_csv=""
            missing_csv="$(IFS=', '; echo "${DEVTOOLS_GATE_MISSING_WORKFLOWS[*]}")"
            log_warn "⏳ Gate pendiente: faltan ${DEVTOOLS_GATE_MISSING_COUNT}/${DEVTOOLS_GATE_TOTAL_COUNT} workflows (${missing_csv}). Reintentando..."
        else
            log_warn "⏳ Gate por SHA sigue ROJO. Reintentando..."
        fi
        sleep "$interval"
    done

    local final_rc=0
    if gate_required_workflows_on_sha "$sha_full" "$ref" "${workflows[@]}"; then
        final_rc=0
    else
        final_rc=$?
    fi
    if [[ "$final_rc" -eq 0 ]]; then
        return 0
    fi
    log_error "Gate por SHA falló tras esperar ${timeout}s."
    return 1

    return 0
}

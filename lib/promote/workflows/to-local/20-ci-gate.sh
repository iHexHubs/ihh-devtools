#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_ensure_checks_loaded() {
    if declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        return 0
    fi

    local checks_file=""
    checks_file="${SCRIPT_DIR}/checks.sh"
    if [[ -f "$checks_file" ]]; then
        # shellcheck disable=SC1090
        source "$checks_file"
    fi

    if declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        return 0
    fi

    local msg="No se encontró gate_required_workflows_on_sha_or_die (faltó source de workflows/checks.sh)."
    if declare -F die >/dev/null 2>&1; then
        die "$msg"
    fi
    echo "$msg" >&2
    return 1
}

# Carga eager del wiring para tests/source directo; no falla duro si aún no está disponible.
promote_local_ensure_checks_loaded >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# Helpers: task_exists / leer previous tag canónico / asegurar minikube / rev.N
# ------------------------------------------------------------------------------


promote_local_run_act_with_progress() {
    local act_cmd="$1"
    local act_image_hint="${DEVTOOLS_ACT_IMAGE_HINT:-catthehacker/ubuntu:full-latest}"

    if ! can_prompt; then
        log_info "⏳ Act puede tardar la primera vez descargando la imagen ${act_image_hint}. Para ver progreso: docker pull ${act_image_hint}"
    fi

    # El progreso real de pull se muestra dentro de task ci:act (docker pull explícito).
    run_cmd "$act_cmd"
    return $?
}



promote_local_confirm_standard_validation() {
    local confirm_msg="Se ejecutará build nativo + Act. Si todo sale bien, se creará el tag y se publicará en GitHub con sufijo rev.N. ¿Continuar?"

    if can_prompt; then
        cat >/dev/tty <<'EOF'
Se ejecutará: build nativo + Act.
  - build nativo: task ci + task app:devbox:ci
  - act: task ci:act
Si todo sale bien, se creará el tag y se publicará en GitHub con sufijo rev.N.
EOF
        printf '\n' >/dev/tty
    fi

    if declare -F ui_confirm_default_yes >/dev/null 2>&1; then
        ui_confirm_default_yes "$confirm_msg"
        return $?
    fi

    return 0
}

promote_local_ui_log_path() {
    local step="${1:-step}"
    if [[ -z "${PROMOTE_LOCAL_UI_LOG_DIR:-}" || ! -d "${PROMOTE_LOCAL_UI_LOG_DIR:-}" ]]; then
        PROMOTE_LOCAL_UI_LOG_DIR="$(mktemp -d "/tmp/promote-local-ui.XXXXXX")"
    fi
    export PROMOTE_LOCAL_UI_LOG_DIR
    printf '%s\n' "${PROMOTE_LOCAL_UI_LOG_DIR}/${step}.log"
}



promote_local_ui_render_progress_panel() {
    [[ "${PROMOTE_LOCAL_UI_PROGRESS_ACTIVE:-0}" == "1" ]] || return 0

    local build_state="${PROMOTE_LOCAL_UI_STATE_BUILD:-pending}"
    local act_state="${PROMOTE_LOCAL_UI_STATE_ACT:-pending}"
    local tag_state="${PROMOTE_LOCAL_UI_STATE_TAG:-pending}"
    local build_percent=""
    local act_percent=""
    local tag_percent=""

    build_percent="$(promote_local_ui_percent_for_state "$build_state" "${PROMOTE_LOCAL_UI_PERCENT_BUILD:-0}")"
    act_percent="$(promote_local_ui_percent_for_state "$act_state" "${PROMOTE_LOCAL_UI_PERCENT_ACT:-0}")"
    tag_percent="$(promote_local_ui_percent_for_state "$tag_state" "${PROMOTE_LOCAL_UI_PERCENT_TAG:-0}")"

    if declare -F ui_render_progress_panel >/dev/null 2>&1 && declare -F ui_update_progress_panel >/dev/null 2>&1; then
        if [[ "${PROMOTE_LOCAL_UI_PANEL_DRAWN:-0}" == "1" ]]; then
            ui_update_progress_panel 3 "build nativo" "$build_percent" "$build_state" "act" "$act_percent" "$act_state" "tag" "$tag_percent" "$tag_state"
        else
            ui_render_progress_panel "build nativo" "$build_percent" "$build_state" "act" "$act_percent" "$act_state" "tag" "$tag_percent" "$tag_state"
            PROMOTE_LOCAL_UI_PANEL_DRAWN=1
            export PROMOTE_LOCAL_UI_PANEL_DRAWN
        fi
    else
        printf 'build nativo: %s (%s%%)\n' "$build_state" "$build_percent"
        printf 'act:          %s (%s%%)\n' "$act_state" "$act_percent"
        printf 'tag:          %s (%s%%)\n' "$tag_state" "$tag_percent"
    fi
}



promote_local_ui_percent_for_state() {
    local state="${1:-pending}"
    local current="${2:-0}"

    [[ "${current}" =~ ^[0-9]+$ ]] || current=0

    case "$state" in
        pending) printf '%s\n' "0" ;;
        running)
            (( current < 1 )) && current=1
            (( current > 90 )) && current=90
            printf '%s\n' "$current"
            ;;
        done|failed) printf '%s\n' "100" ;;
        *) printf '%s\n' "0" ;;
    esac
}



promote_local_ui_set_state() {
    local step="$1"
    local state="$2"
    local percent="${3:-}"

    if [[ -z "${percent:-}" ]]; then
        case "$step" in
            build) percent="$(promote_local_ui_percent_for_state "$state" "${PROMOTE_LOCAL_UI_PERCENT_BUILD:-0}")" ;;
            act) percent="$(promote_local_ui_percent_for_state "$state" "${PROMOTE_LOCAL_UI_PERCENT_ACT:-0}")" ;;
            tag) percent="$(promote_local_ui_percent_for_state "$state" "${PROMOTE_LOCAL_UI_PERCENT_TAG:-0}")" ;;
            *) return 1 ;;
        esac
    fi

    case "$step" in
        build)
            PROMOTE_LOCAL_UI_STATE_BUILD="$state"
            PROMOTE_LOCAL_UI_PERCENT_BUILD="$percent"
            ;;
        act)
            PROMOTE_LOCAL_UI_STATE_ACT="$state"
            PROMOTE_LOCAL_UI_PERCENT_ACT="$percent"
            ;;
        tag)
            PROMOTE_LOCAL_UI_STATE_TAG="$state"
            PROMOTE_LOCAL_UI_PERCENT_TAG="$percent"
            ;;
        *) return 1 ;;
    esac

    export PROMOTE_LOCAL_UI_STATE_BUILD PROMOTE_LOCAL_UI_STATE_ACT PROMOTE_LOCAL_UI_STATE_TAG
    export PROMOTE_LOCAL_UI_PERCENT_BUILD PROMOTE_LOCAL_UI_PERCENT_ACT PROMOTE_LOCAL_UI_PERCENT_TAG
    promote_local_ui_render_progress_panel
    return 0
}



promote_local_ui_print_failure_summary() {
    local step_name="$1"
    local log_file="$2"

    log_error "❌ Falló ${step_name}."
    if [[ -f "${log_file:-}" ]]; then
        log_error "📄 Log: ${log_file}"
        echo "----- Últimas 40 líneas -----"
        tail -n 40 "$log_file" || true
        echo "-----------------------------"
    fi
}



promote_local_ui_estimated_percent() {
    local start_ts="${1:-0}"
    local min_pct="${2:-0}"
    local max_pct="${3:-90}"
    local now_ts="0"
    local elapsed="0"
    local delta="0"
    local estimated="0"

    [[ "${min_pct}" =~ ^[0-9]+$ ]] || min_pct=0
    [[ "${max_pct}" =~ ^[0-9]+$ ]] || max_pct=90
    (( max_pct < min_pct )) && max_pct="$min_pct"

    now_ts="$(date +%s)"
    [[ "${now_ts}" =~ ^[0-9]+$ ]] || now_ts=0
    [[ "${start_ts}" =~ ^[0-9]+$ ]] || start_ts=0
    elapsed=$((now_ts - start_ts))
    (( elapsed < 0 )) && elapsed=0

    # Aproximación suave: +3% cada ~2s, hasta el techo del step.
    delta=$((elapsed * 3 / 2))
    estimated=$((min_pct + delta))
    (( estimated > max_pct )) && estimated=max_pct
    (( estimated < min_pct )) && estimated=min_pct
    printf '%s\n' "$estimated"
}



promote_local_ui_parse_act_percent_from_log() {
    local log_file="${1:-}"
    [[ -n "${log_file:-}" && -f "${log_file}" ]] || {
        printf '%s\n' "0"
        return 0
    }

    tail -n 200 "$log_file" 2>/dev/null | awk '
        function to_bytes(v, u) {
            if (u == "B") return v
            if (u == "kB" || u == "KB") return v * 1024
            if (u == "MB") return v * 1024 * 1024
            if (u == "GB") return v * 1024 * 1024 * 1024
            return v
        }
        {
            if (match($0, /([0-9]{1,3})%/, m)) {
                p = m[1] + 0
                if (p > pct) pct = p
            }
            if (match($0, /([0-9.]+)(kB|KB|MB|GB|B)[[:space:]]*\/[[:space:]]*([0-9.]+)(kB|KB|MB|GB|B)/, m)) {
                cur = to_bytes(m[1] + 0, m[2])
                tot = to_bytes(m[3] + 0, m[4])
                if (tot > 0) {
                    p2 = int((cur / tot) * 100)
                    if (p2 > pct) pct = p2
                }
            }
        }
        END {
            if (pct < 0) pct = 0
            if (pct > 100) pct = 100
            print pct + 0
        }
    '
}



promote_local_ui_run_cmd_for_step() {
    local step="$1"
    local cmd="$2"
    local log_file="$3"
    local mode="${4:-time}"
    local min_pct="${5:-0}"
    local max_pct="${6:-90}"
    local cmd_pid=""
    local rc=0
    local start_ts=0
    local progress=0
    local parsed_pct=0
    local scaled_pct=0
    local errexit_was_on=0

    [[ -n "${step:-}" && -n "${cmd:-}" && -n "${log_file:-}" ]] || return 2
    [[ "${min_pct}" =~ ^[0-9]+$ ]] || min_pct=0
    [[ "${max_pct}" =~ ^[0-9]+$ ]] || max_pct=90
    (( max_pct < min_pct )) && max_pct="$min_pct"

    promote_local_ui_set_state "$step" "running" "$min_pct"

    (set -o pipefail; eval "$cmd") >>"$log_file" 2>&1 &
    cmd_pid=$!
    start_ts="$(date +%s)"

    if [[ -t 1 ]]; then
        while kill -0 "$cmd_pid" 2>/dev/null; do
            sleep 2
            progress="$(promote_local_ui_estimated_percent "$start_ts" "$min_pct" "$max_pct")"

            if [[ "$mode" == "act" ]]; then
                parsed_pct="$(promote_local_ui_parse_act_percent_from_log "$log_file")"
                if [[ "${parsed_pct}" =~ ^[0-9]+$ ]]; then
                    scaled_pct=$((min_pct + (parsed_pct * (max_pct - min_pct)) / 100))
                    if (( scaled_pct > progress )); then
                        progress="$scaled_pct"
                    fi
                fi
            fi
            promote_local_ui_set_state "$step" "running" "$progress"
        done
    fi

    case "$-" in
        *e*) errexit_was_on=1 ;;
    esac
    set +e
    wait "$cmd_pid"
    rc=$?
    if [[ "$errexit_was_on" -eq 1 ]]; then
        set -e
    fi

    if [[ "$rc" -eq 0 ]]; then
        promote_local_ui_set_state "$step" "running" "$max_pct"
        return 0
    fi

    promote_local_ui_set_state "$step" "failed" "100"
    return "$rc"
}



promote_local_run_standard_validation_quiet() {
    local native_repo_cmd="$1"
    local native_app_cmd="$2"
    local act_cmd="$3"
    local build_log=""
    local act_log=""

    PROMOTE_LOCAL_UI_PROGRESS_ACTIVE=1
    PROMOTE_LOCAL_UI_STATE_BUILD="pending"
    PROMOTE_LOCAL_UI_STATE_ACT="pending"
    PROMOTE_LOCAL_UI_STATE_TAG="pending"
    PROMOTE_LOCAL_UI_PERCENT_BUILD="0"
    PROMOTE_LOCAL_UI_PERCENT_ACT="0"
    PROMOTE_LOCAL_UI_PERCENT_TAG="0"
    PROMOTE_LOCAL_UI_PANEL_DRAWN="0"
    export PROMOTE_LOCAL_UI_PROGRESS_ACTIVE PROMOTE_LOCAL_UI_STATE_BUILD PROMOTE_LOCAL_UI_STATE_ACT PROMOTE_LOCAL_UI_STATE_TAG
    export PROMOTE_LOCAL_UI_PERCENT_BUILD PROMOTE_LOCAL_UI_PERCENT_ACT PROMOTE_LOCAL_UI_PERCENT_TAG PROMOTE_LOCAL_UI_PANEL_DRAWN

    build_log="$(promote_local_ui_log_path "build")"
    act_log="$(promote_local_ui_log_path "act")"
    : >"$build_log"
    : >"$act_log"

    promote_local_ui_render_progress_panel

    if ! promote_local_ui_run_cmd_for_step "build" "$native_repo_cmd" "$build_log" "time" "0" "45"; then
        promote_local_ui_print_failure_summary "build nativo (task ci)" "$build_log"
        return 1
    fi
    if ! promote_local_ui_run_cmd_for_step "build" "$native_app_cmd" "$build_log" "time" "45" "90"; then
        promote_local_maybe_print_app_ci_db_help "$build_log"
        promote_local_ui_print_failure_summary "build nativo (task app:devbox:ci)" "$build_log"
        return 1
    fi
    promote_local_ui_set_state "build" "done" "100"

    if ! promote_local_ui_run_cmd_for_step "act" "$act_cmd" "$act_log" "act" "0" "90"; then
        promote_local_ui_print_failure_summary "act" "$act_log"
        return 1
    fi
    promote_local_ui_set_state "act" "done" "100"
    return 0
}



promote_local_maybe_print_app_ci_db_help() {
    local log_file="${1:-}"

    [[ -n "${log_file:-}" && -f "${log_file}" ]] || return 0
    if ! grep -Eqi 'connection refused|127\.0\.0\.1:5432|port 5432|psycopg\.OperationalError|django\.db\.utils\.OperationalError|could not connect to server' "$log_file"; then
        return 0
    fi

    log_error "❌ Devbox CI falló por DB no disponible (localhost:5432)."
    cat <<'EOF'
👉 Para levantar servicios:
   task app:devbox:docker:up
👉 Para verificar:
   docker ps | grep -i postgres
👉 Para bajar:
   task app:devbox:docker:down
EOF
}



promote_local_run_app_ci_with_help() {
    local app_cmd="$1"
    local log_file=""

    log_file="$(mktemp "/tmp/promote-local-app-ci.XXXXXX.log")"
    if (set -o pipefail; run_cmd "$app_cmd" 2>&1 | tee "$log_file"); then
        rm -f "$log_file" >/dev/null 2>&1 || true
        return 0
    fi

    promote_local_maybe_print_app_ci_db_help "$log_file"
    rm -f "$log_file" >/dev/null 2>&1 || true
    return 1
}



promote_local_detect_changes() {
    local base_ref="$1"
    local source_sha="$2"

    local backend_changed=0
    local frontend_changed=0

    local base_commit=""
    if [[ -n "${base_ref:-}" ]]; then
        base_commit="$(git merge-base "$base_ref" "$source_sha" 2>/dev/null || true)"
    fi

    if [[ -z "${base_commit:-}" ]]; then
        log_warn "No pude resolver base para diff. Asumo cambios en backend y frontend."
        echo "backend=1"
        echo "frontend=1"
        return 0
    fi

    local diff_files=""
    diff_files="$(git diff --name-only "$base_commit" "$source_sha" 2>/dev/null || true)"

    if echo "$diff_files" | grep -q "^apps/pmbok/backend/"; then
        backend_changed=1
    fi
    if echo "$diff_files" | grep -q "^apps/pmbok/frontend/"; then
        frontend_changed=1
    fi

    echo "backend=${backend_changed}"
    echo "frontend=${frontend_changed}"
}



promote_local_choose_validation_level() {
    local forced_level="${DEVTOOLS_LOCAL_VALIDATION_LEVEL:-}"
    local menu_mode="${DEVTOOLS_LOCAL_VALIDATION_MENU:-}"

    if [[ -n "${forced_level:-}" ]]; then
        export PROMOTE_LOCAL_UI_MODE="${PROMOTE_LOCAL_UI_MODE:-0}"
        printf '%s\n' "${forced_level}"
        return 0
    fi

    if [[ "${menu_mode}" != "legacy" ]]; then
        if promote_local_confirm_standard_validation; then
            export PROMOTE_LOCAL_UI_MODE=1
            if can_prompt; then
                printf '%s\n' "✅ Confirmado: se ejecutará Gate Estándar." >/dev/tty
            fi
            printf '%s\n' "standard"
        else
            export PROMOTE_LOCAL_UI_MODE=0
            if can_prompt; then
                printf '%s\n' "ℹ️ Cancelado por el usuario." >/dev/tty
            fi
            printf '%s\n' "exit"
        fi
        return 0
    fi

    local options=(
        "✅ Gate Estándar (Nativo + Act)"
        "🔍 Solo Nativo (Rápido)"
        "🎬 Solo Act (GH Actions)"
        "👀 Abrir K9s (ui:local)"
        "📘 ¿Qué hace cada opción?"
        "📨 Finalizar y Crear PR"
        "🚪 Salir (Seguir trabajando)"
    )
    local selected=""

    if ! can_prompt; then
        export PROMOTE_LOCAL_UI_MODE=0
        printf '%s\n' "exit"
        return 0
    fi

    if command -v gum >/dev/null 2>&1 && have_gum_ui; then
        selected="$(gum choose --header "Selecciona un nivel de validación:" "${options[@]}")"
    else
        echo "Selecciona un nivel de validación:" >/dev/tty
        echo "1) ${options[0]}" >/dev/tty
        echo "2) ${options[1]}" >/dev/tty
        echo "3) ${options[2]}" >/dev/tty
        echo "4) ${options[3]}" >/dev/tty
        echo "5) ${options[4]}" >/dev/tty
        echo "6) ${options[5]}" >/dev/tty
        echo "7) ${options[6]}" >/dev/tty
        local answer=""
        read -r -p "Opción [1-7]: " answer </dev/tty || answer="7"
        case "${answer:-}" in
            1) selected="${options[0]}" ;;
            2) selected="${options[1]}" ;;
            3) selected="${options[2]}" ;;
            4) selected="${options[3]}" ;;
            5) selected="${options[4]}" ;;
            6) selected="${options[5]}" ;;
            *) selected="${options[6]}" ;;
        esac
    fi

    case "$selected" in
        "✅ Gate Estándar (Nativo + Act)")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "standard"
            ;;
        "🔍 Solo Nativo (Rápido)")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "native"
            ;;
        "🎬 Solo Act (GH Actions)")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "act"
            ;;
        "👀 Abrir K9s (ui:local)")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "k9s"
            ;;
        "📘 ¿Qué hace cada opción?")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "help"
            ;;
        "📨 Finalizar y Crear PR")
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "pr"
            ;;
        *)
            export PROMOTE_LOCAL_UI_MODE=0
            printf '%s\n' "exit"
            ;;
    esac
}



promote_local_print_validation_help() {
    cat <<'EOF'
✅ Gate Estándar (Nativo + Act): ejecuta task ci, task app:devbox:ci y task ci:act (recomendado).
🔍 Solo Nativo (Rápido): ejecuta task ci y task app:devbox:ci.
🎬 Solo Act (GH Actions): ejecuta solo task ci:act.
👀 Abrir K9s (ui:local): abre task ui:local o k9s para inspección.
📨 Finalizar y Crear PR: crea PR y termina sin promover local.
🚪 Salir: termina sin tocar la rama local.
EOF
}



promote_local_resolve_pr_base() {
    if git show-ref --verify --quiet "refs/heads/main" || git show-ref --verify --quiet "refs/remotes/origin/main"; then
        printf '%s\n' "main"
        return 0
    fi
    if [[ -n "${PR_BASE_BRANCH:-}" ]]; then
        printf '%s\n' "${PR_BASE_BRANCH}"
        return 0
    fi
    if git show-ref --verify --quiet "refs/heads/dev" || git show-ref --verify --quiet "refs/remotes/origin/dev"; then
        printf '%s\n' "dev"
        return 0
    fi
    printf '%s\n' "main"
}



promote_local_create_pr_or_die() {
    local head_branch="$1"
    local base_branch=""
    base_branch="$(promote_local_resolve_pr_base)"

    if declare -F do_create_pr_flow >/dev/null 2>&1; then
        do_create_pr_flow "$head_branch" "$base_branch" || die "No pude crear el PR (${head_branch} -> ${base_branch})."
        return 0
    fi

    local script_dir=""
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
    local pr_script="${script_dir}/bin/git-pr.sh"
    if [[ -x "$pr_script" ]]; then
        BASE_BRANCH="$base_branch" "$pr_script" || die "No pude crear el PR con git-pr.sh (${head_branch} -> ${base_branch})."
        return 0
    fi

    die "No encontré do_create_pr_flow ni bin/git-pr.sh para crear PR."
}



promote_local_run_validation_level() {
    local level="$1"
    local source_branch="${2:-}"
    local native_repo_cmd="task ci"
    local native_app_cmd="task app:devbox:ci"
    local act_cmd="task ci:act"

    case "$level" in
        standard)
            command -v task >/dev/null 2>&1 || die "Gate Estándar requiere 'task' instalado."
            task_exists "ci" || die "Gate Estándar requiere task 'ci'."
            task_exists "app:devbox:ci" || die "Gate Estándar requiere task 'app:devbox:ci'."
            task_exists "ci:act" || die "Gate Estándar requiere task 'ci:act'."
            if [[ "${PROMOTE_LOCAL_UI_MODE:-0}" == "1" ]]; then
                promote_local_run_standard_validation_quiet "$native_repo_cmd" "$native_app_cmd" "$act_cmd" || return 1
            else
                log_info "✅ Gate Estándar: ejecutando ${native_repo_cmd}"
                run_cmd "$native_repo_cmd" || return 1
                log_info "✅ Gate Estándar: ejecutando ${native_app_cmd}"
                promote_local_run_app_ci_with_help "$native_app_cmd" || return 1
                log_info "✅ Gate Estándar: ejecutando ${act_cmd}"
                promote_local_run_act_with_progress "$act_cmd" || return 1
            fi
            return 0
            ;;
        native)
            command -v task >/dev/null 2>&1 || die "Validación nativa requiere 'task' instalado."
            task_exists "ci" || die "No existe task 'ci'."
            task_exists "app:devbox:ci" || die "No existe task 'app:devbox:ci'."
            log_info "🔍 Solo Nativo: ejecutando ${native_repo_cmd}"
            run_cmd "$native_repo_cmd" || return 1
            log_info "🔍 Solo Nativo: ejecutando ${native_app_cmd}"
            promote_local_run_app_ci_with_help "$native_app_cmd" || return 1
            return 0
            ;;
        act)
            command -v task >/dev/null 2>&1 || die "Validación Act requiere 'task' instalado."
            task_exists "ci:act" || die "No existe task 'ci:act'."
            log_info "🎬 Solo Act: ejecutando ${act_cmd}"
            promote_local_run_act_with_progress "$act_cmd" || return 1
            return 0
            ;;
        k9s)
            if command -v task >/dev/null 2>&1 && task_exists "ui:local"; then
                run_cmd "task ui:local"
                return 11
            fi
            if command -v k9s >/dev/null 2>&1; then
                run_cmd "k9s"
                return 11
            fi
            log_warn "No encontré 'task ui:local' ni 'k9s'."
            return 11
            ;;
        help)
            promote_local_print_validation_help
            return 11
            ;;
        pr)
            [[ -n "${source_branch:-}" ]] || source_branch="$(git branch --show-current 2>/dev/null || true)"
            [[ -n "${source_branch:-}" ]] || die "No pude detectar rama fuente para crear PR."
            promote_local_create_pr_or_die "$source_branch"
            return 12
            ;;
        exit)
            return 10
            ;;
        *)
            die "Nivel de validación no soportado: ${level}"
            ;;
    esac
}

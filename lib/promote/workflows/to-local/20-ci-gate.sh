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
        printf '%s\n' "${DEVTOOLS_LOCAL_VALIDATION_LEVEL:-exit}"
        return 0
    fi

    if have_gum_ui; then
        selected="$(gum choose --header "Selecciona un nivel de validación:" "${options[@]}")"
    else
        echo "Selecciona un nivel de validación:"
        echo "1) ${options[0]}"
        echo "2) ${options[1]}"
        echo "3) ${options[2]}"
        echo "4) ${options[3]}"
        echo "5) ${options[4]}"
        echo "6) ${options[5]}"
        echo "7) ${options[6]}"
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
        "✅ Gate Estándar (Nativo + Act)") printf '%s\n' "standard" ;;
        "🔍 Solo Nativo (Rápido)") printf '%s\n' "native" ;;
        "🎬 Solo Act (GH Actions)") printf '%s\n' "act" ;;
        "👀 Abrir K9s (ui:local)") printf '%s\n' "k9s" ;;
        "📘 ¿Qué hace cada opción?") printf '%s\n' "help" ;;
        "📨 Finalizar y Crear PR") printf '%s\n' "pr" ;;
        *) printf '%s\n' "exit" ;;
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
            log_info "✅ Gate Estándar: ejecutando ${native_repo_cmd}"
            run_cmd "$native_repo_cmd" || return 1
            log_info "✅ Gate Estándar: ejecutando ${native_app_cmd}"
            run_cmd "$native_app_cmd" || return 1
            log_info "✅ Gate Estándar: ejecutando ${act_cmd}"
            run_cmd "$act_cmd" || return 1
            return 0
            ;;
        native)
            command -v task >/dev/null 2>&1 || die "Validación nativa requiere 'task' instalado."
            task_exists "ci" || die "No existe task 'ci'."
            task_exists "app:devbox:ci" || die "No existe task 'app:devbox:ci'."
            log_info "🔍 Solo Nativo: ejecutando ${native_repo_cmd}"
            run_cmd "$native_repo_cmd" || return 1
            log_info "🔍 Solo Nativo: ejecutando ${native_app_cmd}"
            run_cmd "$native_app_cmd" || return 1
            return 0
            ;;
        act)
            command -v task >/dev/null 2>&1 || die "Validación Act requiere 'task' instalado."
            task_exists "ci:act" || die "No existe task 'ci:act'."
            log_info "🎬 Solo Act: ejecutando ${act_cmd}"
            run_cmd "$act_cmd" || return 1
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

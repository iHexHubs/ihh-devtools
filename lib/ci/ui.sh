#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/ci/ui.sh

# ==============================================================================
# LÓGICA DE UI (Renderizado del Dashboard)
# ==============================================================================

# Helper de seguridad: detecta si gum está disponible si no se cargó utils.sh
if ! declare -F have_gum_ui >/dev/null 2>&1; then
    have_gum_ui() { command -v gum >/dev/null; }
fi

# Render “bonito” del estado de entorno (activo + alternativas)
render_env_status_panel() {
    local -a active_envs=()
    local -a runtime_suggestions=()
    local -a validation_suggestions=()

    # Activos (Funciones vienen de detection.sh)
    if detect_devbox_active; then
        active_envs+=("🧰 Devbox (toolchain)")
    fi
    if detect_compose_active; then
        active_envs+=("🐳 Docker Compose (Traefik)")
    fi
    if detect_minikube_active; then
        active_envs+=("☸️  Minikube GitOps")
    fi

    # Sugerencias de activación (runtime)
    if ! detect_compose_active; then
        if task_exists "local:up"; then
            runtime_suggestions+=("🐳 Activar Compose:   task local:up")
        elif task_exists "local:check"; then
            runtime_suggestions+=("🐳 Compose (check):   task local:check")
        fi
    fi

    if ! detect_minikube_active; then
        # Preferimos el alias “cluster:up” porque es el contrato del root Taskfile
        if task_exists "cluster:up"; then
            runtime_suggestions+=("☸️  Activar Minikube:  task cluster:up")
        elif task_exists "local:cluster:up"; then
            runtime_suggestions+=("☸️  Activar Minikube:  task local:cluster:up")
        fi
    fi

    # Sugerencias rápidas de logs cuando Compose está activo (Traefik/runtime)
    if detect_compose_active; then
        if task_exists "local:logs:traefik"; then
            runtime_suggestions+=("📄 Logs Traefik:       task local:logs:traefik")
        fi
        if task_exists "local:logs"; then
            runtime_suggestions+=("📄 Logs Compose:       task local:logs")
        fi
        if task_exists "local:logs:backend"; then
            runtime_suggestions+=("📄 Logs Backend:       task local:logs:backend")
        fi
        if task_exists "local:logs:frontend"; then
            runtime_suggestions+=("📄 Logs Frontend:      task local:logs:frontend")
        fi
        if task_exists "local:logs:db"; then
            runtime_suggestions+=("📄 Logs DB:            task local:logs:db")
        fi

        # Fallback manual (por si no existe local:logs:traefik todavía)
        if ! task_exists "local:logs:traefik" && command -v docker >/dev/null 2>&1; then
            runtime_suggestions+=("📄 Logs Traefik:       docker compose -f devops/local/compose.yml logs -f --tail=200 traefik")
        fi
    fi

    # Sugerencia de observabilidad (k9s) para ver logs / pods
    if task_exists "ui:local"; then
        runtime_suggestions+=("👀 Ver logs en K9s:   task ui:local")
    elif command -v k9s >/dev/null 2>&1; then
        runtime_suggestions+=("👀 Ver logs en K9s:   k9s")
    fi

    # Sugerencias de validación (no-runtime, pero útiles para “probar build/calidad”)
    # Las variables NATIVE_CI_CMD, etc., se setean en detection.sh
    [[ -n "${NATIVE_CI_CMD:-}" ]] && validation_suggestions+=("🔍 CI nativo:         ${NATIVE_CI_CMD}")
    [[ -n "${ACT_CI_CMD:-}" ]]    && validation_suggestions+=("🎬 CI con Act:        ${ACT_CI_CMD}")
    [[ -n "${K8S_HEADLESS_CMD:-}" ]] && validation_suggestions+=("🤖 K8s headless:      ${K8S_HEADLESS_CMD}")
    [[ -n "${K8S_FULL_CMD:-}" ]]     && validation_suggestions+=("🚀 K8s full:          ${K8S_FULL_CMD}")

    # Construir strings
    local active_txt
    if [[ "${#active_envs[@]}" -gt 0 ]]; then
        active_txt="$(printf "%s\n" "${active_envs[@]}")"
    else
        active_txt="(Ninguno)"
    fi

    local runtime_txt
    if [[ "${#runtime_suggestions[@]}" -gt 0 ]]; then
        runtime_txt="$(printf "%s\n" "${runtime_suggestions[@]}")"
    else
        runtime_txt="(No hay sugerencias de runtime detectables)"
    fi

    local validation_txt
    if [[ "${#validation_suggestions[@]}" -gt 0 ]]; then
        validation_txt="$(printf "%s\n" "${validation_suggestions[@]}")"
    else
        validation_txt="(No se detectaron comandos de validación)"
    fi

    # Render UI (gum si está disponible, fallback texto)
    if have_gum_ui; then
        echo
        gum style \
            --border rounded --padding "1 2" --margin "0 0" \
            "🧭 Entornos de trabajo" \
            "" \
            "Activo(s):" \
            "$active_txt" \
            "" \
            "Puedes activar:" \
            "$runtime_txt" \
            "" \
            "Validaciones disponibles:" \
            "$validation_txt"
        echo
    else
        echo
        echo "════════════════════════════════════════════════════"
        echo "🧭 Entornos de trabajo"
        echo "════════════════════════════════════════════════════"
        echo "Activo(s):"
        echo "$active_txt" | sed 's/^/  - /'
        echo
        # Si no hay runtime activo, mostramos mensaje claro
        if ! detect_compose_active && ! detect_minikube_active; then
            echo "⚠️  No tienes un entorno de runtime activo para probar build/smoke."
            echo "   Activa uno para continuar:"
            echo "$runtime_txt" | sed 's/^/  • /'
        else
            echo "Puedes activar:"
            echo "$runtime_txt" | sed 's/^/  • /'
        fi
        echo
        echo "Validaciones disponibles:"
        echo "$validation_txt" | sed 's/^/  • /'
        echo "════════════════════════════════════════════════════"
        echo
    fi
}

# Resumen breve para cierre de promote local (sin spam).
render_local_finish_summary() {
    local repo_root ports_file gateway_port dash_port
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    ports_file="${repo_root}/.env.local.ports"
    gateway_port=""
    dash_port=""

    if [[ -f "${ports_file}" ]]; then
        gateway_port="$(grep -E '^GATEWAY_HTTP_PORT=' "${ports_file}" | cut -d= -f2 | tr -d '[:space:]' | head -n 1)"
        dash_port="$(grep -E '^TRAEFIK_DASHBOARD_PORT=' "${ports_file}" | cut -d= -f2 | tr -d '[:space:]' | head -n 1)"
    fi
    [[ -n "${gateway_port:-}" ]] || gateway_port="18080"
    [[ -n "${dash_port:-}" ]] || dash_port="8090"

    echo "✅ Resumen final (local)"
    echo "   - Gateway: http://127.0.0.1:${gateway_port}/"
    echo "   - Dashboard Traefik: http://127.0.0.1:${dash_port}/dashboard/"
    echo "   - ArgoCD: https://argocd.localhost:8443"

    local apps_log
    apps_log="$(mktemp /tmp/promote-local-apps.XXXXXX.log 2>/dev/null || true)"
    if [[ -z "${apps_log:-}" ]]; then
        echo "   - Apps: ver con 'task local:app:list'"
        return 0
    fi

    local errexit_was_on=0
    case "$-" in
        *e*) errexit_was_on=1 ;;
    esac
    set +e
    task --exit-code local:app:list >"${apps_log}" 2>&1
    local apps_rc=$?
    if [[ "$errexit_was_on" -eq 1 ]]; then
        set -e
    fi

    if [[ "$apps_rc" -eq 0 ]]; then
        local app_lines
        app_lines="$(grep -E '^[[:space:]]*-[[:space:]]+[^:]+:[[:space:]]+(running|down)' "${apps_log}" 2>/dev/null || true)"
        if [[ -n "${app_lines:-}" ]]; then
            echo "   - Apps:"
            while IFS= read -r line; do
                line="$(echo "$line" | sed 's/^[[:space:]]*//')"
                echo "     ${line}"
            done <<< "${app_lines}"
        else
            echo "   - Apps: ver con 'task local:app:list'"
        fi
    else
        echo "   - Apps: ver con 'task local:app:list'"
    fi

    rm -f "${apps_log}" >/dev/null 2>&1 || true
}

# Panel adicional de diagnóstico CI (offline-safe, sin llamadas de red)
render_ci_diagnostic_panel() {
    local tty_state="no"
    if declare -F is_tty >/dev/null 2>&1; then
        if is_tty; then tty_state="sí"; fi
    elif [[ -t 1 ]]; then
        tty_state="sí"
    fi

    # Refrescamos detección local para mostrar comandos vigentes.
    if declare -F detect_ci_tools >/dev/null 2>&1; then
        detect_ci_tools >/dev/null 2>&1 || true
    fi

    local repo_root="${REPO_ROOT:-<vacío>}"
    local workspace_root="${WORKSPACE_ROOT:-<vacío>}"
    local ci_flag="${CI:-<vacío>}"
    local gha_flag="${GITHUB_ACTIONS:-<vacío>}"
    local nonint_flag="${DEVTOOLS_NONINTERACTIVE:-<vacío>}"
    local offline_flag="(sin flag)"
    if [[ -n "${DEVTOOLS_PROMOTE_OFFLINE_OK:-}" || -n "${DEVTOOLS_PROMOTE_OFFLINE:-}" || -n "${OFFLINE_OK:-}" ]]; then
        offline_flag="DEVTOOLS_PROMOTE_OFFLINE_OK=${DEVTOOLS_PROMOTE_OFFLINE_OK:-<vacío>} DEVTOOLS_PROMOTE_OFFLINE=${DEVTOOLS_PROMOTE_OFFLINE:-<vacío>} OFFLINE_OK=${OFFLINE_OK:-<vacío>}"
    fi

    local root taskfile_found
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    if [[ -f "${root}/Taskfile.yaml" ]]; then
        taskfile_found="${root}/Taskfile.yaml"
    else
        taskfile_found="(no encontrado)"
    fi

    local gh_state="no" act_state="no" task_state="no" docker_state="no" kubectl_state="no" minikube_state="no"
    command -v gh >/dev/null 2>&1 && gh_state="sí"
    command -v act >/dev/null 2>&1 && act_state="sí"
    command -v task >/dev/null 2>&1 && task_state="sí"
    command -v docker >/dev/null 2>&1 && docker_state="sí"
    command -v kubectl >/dev/null 2>&1 && kubectl_state="sí"
    command -v minikube >/dev/null 2>&1 && minikube_state="sí"

    local native_cmd="${NATIVE_CI_CMD:-"(no detectado)"}"
    local act_cmd="${ACT_CI_CMD:-"(no detectado)"}"
    local k8s_headless_cmd="${K8S_HEADLESS_CMD:-"(no detectado)"}"
    local k8s_full_cmd="${K8S_FULL_CMD:-"(no detectado)"}"

    local can_rich_ui=0
    if have_gum_ui; then
        if declare -F is_tty >/dev/null 2>&1; then
            is_tty && can_rich_ui=1
        elif [[ -t 1 ]]; then
            can_rich_ui=1
        fi
    fi

    if [[ "$can_rich_ui" -eq 1 ]]; then
        gum style \
            --border rounded --padding "1 2" --margin "0 0" \
            -- \
            "🧪 Diagnóstico CI (local)" \
            "" \
            "Flags:" \
            "- is_tty: ${tty_state}" \
            "- CI=${ci_flag} | GITHUB_ACTIONS=${gha_flag} | DEVTOOLS_NONINTERACTIVE=${nonint_flag}" \
            "- OFFLINE: ${offline_flag}" \
            "- REPO_ROOT=${repo_root}" \
            "- WORKSPACE_ROOT=${workspace_root}" \
            "" \
            "Herramientas:" \
            "- gh=${gh_state} act=${act_state} task=${task_state} docker=${docker_state} kubectl=${kubectl_state} minikube=${minikube_state}" \
            "" \
            "Comandos detectados:" \
            "- NATIVE_CI_CMD: ${native_cmd}" \
            "- ACT_CI_CMD: ${act_cmd}" \
            "- K8S_HEADLESS_CMD: ${k8s_headless_cmd}" \
            "- K8S_FULL_CMD: ${k8s_full_cmd}" \
            "" \
            "Taskfile: ${taskfile_found}"
        echo
    else
        echo "────────────────────────────────────────────────────"
        echo "🧪 Diagnóstico CI (local)"
        echo "Flags:"
        echo "  - is_tty: ${tty_state}"
        echo "  - CI=${ci_flag} | GITHUB_ACTIONS=${gha_flag} | DEVTOOLS_NONINTERACTIVE=${nonint_flag}"
        echo "  - OFFLINE: ${offline_flag}"
        echo "  - REPO_ROOT=${repo_root}"
        echo "  - WORKSPACE_ROOT=${workspace_root}"
        echo "Herramientas:"
        echo "  - gh=${gh_state} act=${act_state} task=${task_state} docker=${docker_state} kubectl=${kubectl_state} minikube=${minikube_state}"
        echo "Comandos detectados:"
        echo "  - NATIVE_CI_CMD: ${native_cmd}"
        echo "  - ACT_CI_CMD: ${act_cmd}"
        echo "  - K8S_HEADLESS_CMD: ${k8s_headless_cmd}"
        echo "  - K8S_FULL_CMD: ${k8s_full_cmd}"
        echo "Taskfile: ${taskfile_found}"
        echo "────────────────────────────────────────────────────"
        echo
    fi
}

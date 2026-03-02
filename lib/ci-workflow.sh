#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/ci-workflow.sh

# ==============================================================================
# 0. IMPORTS & BOOTSTRAP
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar módulos refactorizados
source "${SCRIPT_DIR}/ci/detection.sh"
source "${SCRIPT_DIR}/ci/ui.sh"
source "${SCRIPT_DIR}/ci/actions.sh"

# Ejecutar detección inicial al cargar
detect_ci_tools

# ==============================================================================
# Helpers de Menú (Reutilizables)
# ==============================================================================
ci_ensure_ui_fallbacks() {
    # [SAFETY] Fallback de UI: Define funciones dummy si styles.sh no cargó
    if ! declare -F ui_step_header >/dev/null 2>&1; then
        ui_step_header() { echo -e "\n>>> $1"; }
        ui_success() { echo "✅ $1"; }
        ui_error() { echo "❌ $1"; }
        ui_warn() { echo "⚠️  $1"; }
        ui_info() { echo "ℹ️  $1"; }
        ask_yes_no() {
            local prompt="$1"
            read -r -p "$prompt [y/N] " response
            [[ "$response" =~ ^[yY] ]]
        }
        # Helper simple para ejecutar comandos si run_cmd no existe
        if ! declare -F run_cmd >/dev/null 2>&1; then
            run_cmd() { eval "$@"; }
        fi
    fi
}

ci_get_native_cmd() {
    if [[ -n "${DEVTOOLS_CI_NATIVE_CMD_OVERRIDE:-}" ]]; then
        echo "${DEVTOOLS_CI_NATIVE_CMD_OVERRIDE}"
        return 0
    fi
    echo "${NATIVE_CI_CMD:-}"
}

ci_build_validation_menu() {
    CI_OPT_GATE="✅ Gate Estándar (Nativo + Act)"
    CI_OPT_NATIVE="🔍 Solo Nativo (Rápido)"
    CI_OPT_ACT="🎬 Solo Act (GH Actions)"
    CI_OPT_COMPOSE="🐳 Chequeo Compose (Integración)"
    CI_OPT_K8S="☸️  K8s Pro (Compilar -> Desplegar -> Smoke)"
    CI_OPT_K8S_FULL="🚀 Pipeline Completo (Interactivo)"
    CI_OPT_START_MINIKUBE="🟢 Activar Minikube (cluster:up)"
    CI_OPT_K9S="👀 Abrir K9s (ui:local)"
    CI_OPT_HELP="📘 ¿Qué hace cada opción?"
    CI_OPT_PR="📨 Finalizar y Crear PR"
    CI_OPT_SKIP="🚪 Salir (Seguir trabajando)"

    CI_MENU_CHOICES=()

    local native_cmd
    native_cmd="$(ci_get_native_cmd)"

    if [[ -n "${native_cmd:-}" && -n "${ACT_CI_CMD:-}" ]]; then
        CI_MENU_CHOICES+=("$CI_OPT_GATE")
    fi
    [[ -n "${native_cmd:-}" ]] && CI_MENU_CHOICES+=("$CI_OPT_NATIVE")
    [[ -n "${ACT_CI_CMD:-}" ]] && CI_MENU_CHOICES+=("$CI_OPT_ACT")
    [[ -n "${COMPOSE_CI_CMD:-}" ]] && CI_MENU_CHOICES+=("$CI_OPT_COMPOSE")
    [[ -n "${K8S_HEADLESS_CMD:-}" ]] && CI_MENU_CHOICES+=("$CI_OPT_K8S")
    [[ -n "${K8S_FULL_CMD:-}" ]] && CI_MENU_CHOICES+=("$CI_OPT_K8S_FULL")

    if ! detect_minikube_active && task_exists "cluster:up"; then
        CI_MENU_CHOICES+=("$CI_OPT_START_MINIKUBE")
    fi
    if task_exists "ui:local" || command -v k9s >/dev/null 2>&1; then
        CI_MENU_CHOICES+=("$CI_OPT_K9S")
    fi

    CI_MENU_CHOICES+=("$CI_OPT_HELP")
    CI_MENU_CHOICES+=("$CI_OPT_PR")
    CI_MENU_CHOICES+=("$CI_OPT_SKIP")
}

ci_render_validation_menu_header() {
    local head="$1"

    ci_ensure_ui_fallbacks
    render_env_status_panel
    if declare -F render_ci_diagnostic_panel >/dev/null 2>&1; then
        render_ci_diagnostic_panel
    fi

    echo
    ui_step_header "🕵️  RINCÓN DEL DETECTIVE: Calidad de Código"
    echo "   Rama actual: $head"
    echo
}

ci_prompt_validation_menu() {
    ci_build_validation_menu

    local selected=""
    if command -v gum >/dev/null 2>&1 && have_gum_ui; then
        selected=$(gum choose --header "Selecciona un nivel de validación:" "${CI_MENU_CHOICES[@]}")
    else
        echo "Selecciona opción:"
        select opt in "${CI_MENU_CHOICES[@]}"; do selected="$opt"; break; done
    fi

    echo "$selected"
}

ci_is_skip_option() {
    [[ -z "${1:-}" || "$1" == "${CI_OPT_SKIP:-}" ]]
}

ci_is_validation_option() {
    case "$1" in
        "${CI_OPT_GATE:-}"|"${CI_OPT_NATIVE:-}"|"${CI_OPT_ACT:-}"|"${CI_OPT_COMPOSE:-}"|"${CI_OPT_K8S:-}"|"${CI_OPT_K8S_FULL:-}")
            return 0
            ;;
    esac
    return 1
}

ci_selection_uses_native() {
    case "$1" in
        "${CI_OPT_GATE:-}"|"${CI_OPT_NATIVE:-}")
            return 0
            ;;
    esac
    return 1
}

ci_run_validation_option() {
    local selected="$1"
    local head="$2"
    local base="$3"
    local mode="${4:-post}"

    local native_cmd
    native_cmd="$(ci_get_native_cmd)"

    selected="${selected//$'\r'/}"
    selected="${selected%"${selected##*[![:space:]]}"}"

    case "$selected" in
        "${CI_OPT_GATE:-}")
            echo "▶️  Ejecutando Gate Estándar..."
            if [[ -n "${native_cmd:-}" ]]; then
                if run_cmd "$native_cmd"; then
                    echo
                else
                    ui_error "❌ Falló CI Nativo."
                    return 1
                fi
            fi
            if run_cmd "$ACT_CI_CMD"; then
                ui_success "✅ Gate completado."
                CI_GATE_PASSED=1
                echo
                if [[ "$mode" != "pre" ]]; then
                    if ask_yes_no "¿Quieres crear el PR ahora?"; then
                        do_create_pr_flow "$head" "$base"
                    fi
                fi
            else
                ui_error "❌ Falló CI Act."
                return 1
            fi
            ;;

        "${CI_OPT_NATIVE:-}")
            [[ -n "${native_cmd:-}" ]] || return 1
            run_cmd "$native_cmd"
            ;;

        "${CI_OPT_ACT:-}")
            run_cmd "$ACT_CI_CMD"
            ;;

        "${CI_OPT_COMPOSE:-}")
            echo "▶️  Verificando entorno Compose..."
            run_cmd "$COMPOSE_CI_CMD"
            ;;

        "${CI_OPT_K8S:-}")
            echo "▶️  Ejecutando Pipeline K8s Local (Headless)..."
            run_cmd "$K8S_HEADLESS_CMD"
            ;;

        "${CI_OPT_K8S_FULL:-}")
            echo "▶️  Ejecutando Pipeline Full (Bloqueará la terminal)..."

            run_cmd "$K8S_FULL_CMD"
            local rc=$?

            if [[ "$rc" != "0" && "$rc" != "130" && "$rc" != "143" ]]; then
                ui_error "❌ Pipeline full falló con código $rc"
                return "$rc"
            else
                echo
                ui_info "🛑 Pipeline finalizado/interrumpido (rc=$rc)."
            fi

            echo
            ui_warn "🔌 Has desconectado los túneles del Pipeline."
            echo
            ui_info "Si cerraste por error o quieres seguir navegando, puedo reabrirlos por ti."
            ui_info "Comando manual: task cluster:connect"
            echo

            while ask_yes_no "¿Quieres volver a abrir los túneles ahora?"; do
                echo "🔌 Reconectando..."
                run_cmd "task cluster:connect"
                echo
                ui_warn "🔌 Túneles cerrados nuevamente."
            done
            ui_info "👌 Entendido. Túneles cerrados definitivamente."
            ;;

        "${CI_OPT_START_MINIKUBE:-}")
            run_cmd "task cluster:up"
            return 11
            ;;

        "${CI_OPT_K9S:-}")
            if task_exists "ui:local"; then
                run_cmd "task ui:local"
            else
                run_cmd "k9s"
            fi
            return 11
            ;;

        "${CI_OPT_HELP:-}")
            if command -v gum >/dev/null 2>&1 && have_gum_ui; then
                gum style --border rounded --padding "1 2" \
                    "📘 Ayuda rápida" \
                    "" \
                    "✅ Gate Estándar: corre CI nativo + CI con Act (recomendado antes de PR)" \
                    "🔍 Solo Nativo: corre tests rápidos sin simular GitHub Actions" \
                    "🎬 Solo Act: corre el workflow real de GitHub Actions en local" \
                    "🐳 Chequeo Compose: valida que Compose/Traefik responde (entorno dev)" \
                    "☸️  K8s Pro: compilar+desplegar+pruebas smoke en Minikube (sin túneles)" \
                    "🚀 Pipeline Completo: despliega y abre túneles (Ctrl+C para salir)" \
                    "" \
                    "Tip: Usa 👀 K9s para ver pods/logs fácilmente."
            else
                echo "📘 Ayuda rápida:"
                echo "  - ✅ Gate Estándar: CI nativo + Act (recomendado antes de PR)"
                echo "  - 🔍 Solo Nativo: tests rápidos sin simular GH Actions"
                echo "  - 🎬 Solo Act: workflow real GH Actions en local"
                echo "  - 🐳 Chequeo Compose: valida entorno Compose/Traefik"
                echo "  - ☸️  K8s Pro: compilar+desplegar+pruebas smoke en Minikube (sin UI)"
                echo "  - 🚀 Pipeline Completo: despliega y abre túneles (Ctrl+C para salir)"
                echo "  - Tip: usa K9s para logs/pods."
            fi
            return 11
            ;;

        "${CI_OPT_PR:-}")
            if [[ "$mode" == "pre" ]]; then
                ui_warn "PR no disponible en preflight."
                return 11
            fi
            # [PROCESS] Enforzar Gate antes de PR
            if [[ "${REQUIRE_GATE_BEFORE_PR:-true}" == "true" && "${CI_GATE_PASSED:-0}" != "1" && "${DEVTOOLS_ALLOW_PR_WITHOUT_GATE:-0}" != "1" ]]; then
                ui_warn "🔒 Para crear PR debes pasar el Gate (Nativo + Act)."
                echo "   Esto asegura que no subamos código roto."
                echo 
                if ask_yes_no "¿Ejecutar Gate ahora?"; then
                    if run_cmd "$native_cmd" && run_cmd "$ACT_CI_CMD"; then
                        CI_GATE_PASSED=1
                        ui_success "Gate superado. Procediendo al PR..."
                    else
                        ui_error "No se pasó el Gate. PR abortado."
                        return 1
                    fi
                else
                    ui_info "PR cancelado. (Usa DEVTOOLS_ALLOW_PR_WITHOUT_GATE=1 si es urgente)."
                    return 1
                fi
            fi
            do_create_pr_flow "$head" "$base"
            ;;

        "${CI_OPT_SKIP:-}"|"" )
            echo "👌 Omitido."
            return 10
            ;;
        *)
            ui_warn "Opción no reconocida: '${selected}'."
            return 11
            ;;
    esac

    return 0
}

# ==============================================================================
# 1. FLUJO POST-PUSH (Orquestador del Menú)
# ==============================================================================

run_post_push_flow() {
    local head="$1"
    local base="$2"

    # Fuente de verdad de fallback UI (DRY)
    ci_ensure_ui_fallbacks

    # Dependencias de utils.sh (check de TTY)
    if ! command -v is_tty >/dev/null; then 
        is_tty() { [ -t 1 ]; }
    fi

    [[ "$POST_PUSH_FLOW" == "true" ]] || return 0

    local non_interactive_reason=""
    if [[ "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" || "${CI:-}" == "1" || "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "1" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        non_interactive_reason="CI/GITHUB_ACTIONS/DEVTOOLS_NONINTERACTIVE"
    elif ! is_tty; then
        non_interactive_reason="sin TTY"
    fi
    if [[ -n "${non_interactive_reason:-}" ]]; then
        ui_info "Modo no interactivo (${non_interactive_reason}): se omite menú de Calidad de Código."
        if declare -F render_ci_diagnostic_panel >/dev/null 2>&1; then
            render_ci_diagnostic_panel
        fi
        return 0
    fi
    
    # Mostrar menú en cualquier rama NO protegida
    case "$head" in
        dev|staging|main) return 0 ;;
        *) : ;;
    esac

    # --- 1. Re-detectar herramientas (frescura) ---
    # Limpiamos variables para forzar re-evaluación en detection.sh
    unset NATIVE_CI_CMD ACT_CI_CMD COMPOSE_CI_CMD K8S_HEADLESS_CMD K8S_FULL_CMD
    detect_ci_tools
    CI_GATE_PASSED=0

    # --- 2. Mostrar Dashboard + Menú ---
    ci_render_validation_menu_header "$head"

    # IMPORTANT: evitar subshell-loss de CI_OPT_* (ci_prompt_validation_menu corre en $(...))
    ci_build_validation_menu
    local selected
    selected="$(ci_prompt_validation_menu)"
    selected="${selected//$'\r'/}"
    selected="${selected%"${selected##*[![:space:]]}"}"
    if ci_is_skip_option "$selected"; then
        echo "👌 Omitido."
        return 0
    fi

    ci_run_validation_option "$selected" "$head" "$base" "post"
    local rc=$?
    if [[ "$rc" -eq 10 || "$rc" -eq 11 ]]; then
        return 0
    fi
    return "$rc"
}

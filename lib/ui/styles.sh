#!/usr/bin/env bash
# Estilos UI compartidos.

# ==============================================================================
# PALETA DE COLORES (Basado en tu script original)
# ==============================================================================
COLOR_PRIMARY="212"    # Rosa/Magenta (Títulos, Bordes)
COLOR_SUCCESS="76"     # Verde (Éxito)
COLOR_WARN="220"       # Amarillo (Advertencias, Info importante)
COLOR_ERROR="196"      # Rojo (Errores, Alertas críticas)
COLOR_INFO="99"        # Púrpura (Información general, instrucciones)

# Códigos ANSI para fallback (Modo No-Interactivo / Sin Gum)
ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"
ANSI_BLUE="\033[34m"
ANSI_MAGENTA="\033[35m"

# ==============================================================================
# 0. FIX: AUTOSUFICIENCIA (No asumir que utils.sh fue cargado)
# ==============================================================================
# Solución: Si `have_gum_ui` no existe (porque alguien sourceó styles.sh sin utils.sh),
# definimos un fallback local para evitar "command not found" y mantener robustez.
if ! declare -F have_gum_ui >/dev/null 2>&1; then
    have_gum_ui() {
        [[ -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1
    }
fi

# (Opcional) cache de estado, útil si quieres evitar recomputar en cada llamada.
# No reemplaza `have_gum_ui`, solo expone un flag por conveniencia.
if have_gum_ui; then
    UI_GUM_ENABLED=1
else
    UI_GUM_ENABLED=0
fi

# ==============================================================================
# 1. ELEMENTOS ESTRUCTURALES (Banners y Headers)
# ==============================================================================

# Banner principal del setup.
show_setup_banner() {
    if have_gum_ui; then
        clear
        gum style \
            --foreground "$COLOR_PRIMARY" --border-foreground "$COLOR_PRIMARY" --border double \
            --align center --width 50 --margin "1 2" --padding "2 4" \
            "BIENVENIDO A DEVTOOLS SETUP" \
            "Asistente de configuración de entorno"
        echo ""
        gum style --foreground "$COLOR_INFO" "Configuraremos identidad y seguridad paso a paso."
        echo ""
    else
        # Fallback Text-Only
        echo -e "${ANSI_MAGENTA}"
        echo "══════════════════════════════════════════════════"
        echo "   BIENVENIDO A DEVTOOLS SETUP"
        echo "   Asistente de configuración de entorno"
        echo "══════════════════════════════════════════════════"
        echo -e "${ANSI_RESET}"
        echo "Iniciando configuración..."
        echo ""
    fi
}

# Títulos de pasos (Ej: "1. Autenticación con GitHub")
ui_step_header() {
    echo ""
    if have_gum_ui; then
        gum style --foreground "$COLOR_PRIMARY" --bold "$1"
    else
        echo -e "${ANSI_MAGENTA}${ANSI_BOLD}>>> $1${ANSI_RESET}"
    fi
}

# Cajas de Alerta (Ej: "ACCESO DENEGADO" o "LISTO")
# Uso: ui_alert_box "TÍTULO" "Mensaje línea 1" "Mensaje línea 2" ...
ui_alert_box() {
    local color="$COLOR_PRIMARY"
    local title="$1"
    shift
    
    # Fallback colors map
    local ansi_color="$ANSI_MAGENTA"

    # Soporta: ui_alert_box "196" "TITULO" ...  (color primero)
    if [[ "$title" =~ ^[0-9]+$ ]]; then
        color="$title"
        title="${1:-}"
        shift || true
    # Soporta: ui_alert_box "TITULO" "196" ...  (color segundo)
    elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
        color="$1"
        shift
    else
        # Si es un error/alerta crítica (detectado por palabras clave), usamos rojo
        if [[ "$title" == *"DENEGADO"* || "$title" == *"ERROR"* ]]; then
            color="$COLOR_ERROR"
            ansi_color="$ANSI_RED"
        elif [[ "$title" == *"LISTO"* || "$title" == *"COMPLETADA"* ]]; then
            color="$COLOR_PRIMARY"
            ansi_color="$ANSI_GREEN"
        fi
    fi

    if have_gum_ui; then
        gum style \
            --border double --border-foreground "$color" --foreground "$color" \
            --padding "1 2" --align center \
            "$title" "$@"
    else
        # Fallback Box ASCII
        echo ""
        echo -e "${ansi_color}╔════════════════════════════════════════════════╗${ANSI_RESET}"
        echo -e "${ansi_color}║ $title${ANSI_RESET}"
        echo -e "${ansi_color}╠════════════════════════════════════════════════╣${ANSI_RESET}"
        for line in "$@"; do
            echo -e "${ansi_color}║ $line${ANSI_RESET}"
        done
        echo -e "${ansi_color}╚════════════════════════════════════════════════╝${ANSI_RESET}"
        echo ""
    fi
}

# ==============================================================================
# 1.1. NUEVO: CARDS / PANELES (DevX: estado de entorno + recomendaciones)
# ==============================================================================
# Uso:
#   ui_card "Título" "Línea 1" "Línea 2" ...
# Nota: No depende de utils.sh; usa have_gum_ui.
ui_card() {
    local title="$1"
    shift

    if have_gum_ui; then
        gum style \
            --border rounded --border-foreground "$COLOR_PRIMARY" \
            --padding "1 2" \
            "$title" \
            "$@"
    else
        echo ""
        echo -e "${ANSI_MAGENTA}${ANSI_BOLD}${title}${ANSI_RESET}"
        for line in "$@"; do
            echo -e "${ANSI_BLUE}${line}${ANSI_RESET}"
        done
        echo ""
    fi
}

# ==============================================================================
# 2. MENSAJES DE LOGGING (Reemplazan a log_success, log_warn, etc.)
# ==============================================================================

ui_success() { 
    if have_gum_ui; then gum style --foreground "$COLOR_SUCCESS" "✅ $1";
    else echo -e "${ANSI_GREEN}✅ $1${ANSI_RESET}"; fi
}

ui_warn() { 
    if have_gum_ui; then gum style --foreground "$COLOR_WARN"    "⚠️  $1";
    else echo -e "${ANSI_YELLOW}⚠️  $1${ANSI_RESET}"; fi
}

ui_error() { 
    if have_gum_ui; then gum style --foreground "$COLOR_ERROR"   "❌ $1";
    else echo -e "${ANSI_RED}❌ $1${ANSI_RESET}"; fi
}

ui_info() { 
    if have_gum_ui; then gum style --foreground "$COLOR_INFO"    "ℹ️  $1";
    else echo -e "${ANSI_BLUE}ℹ️  $1${ANSI_RESET}"; fi
}

# Texto resaltado simple (para instrucciones como URLs)
ui_text_highlight() { 
    if have_gum_ui; then gum style --foreground "$COLOR_WARN" "$1";
    else echo -e "${ANSI_YELLOW}$1${ANSI_RESET}"; fi
}

# Link o texto primario (ejemplo: "👉 Visita la documentación")
ui_link() { 
    if have_gum_ui; then gum style --foreground "$COLOR_PRIMARY" "$1";
    else echo -e "${ANSI_BLUE}$1${ANSI_RESET}"; fi
}

# ==============================================================================
# 3. COMPONENTES INTERACTIVOS Y UTILIDADES
# ==============================================================================

# Spinner para procesos largos
# Uso: ui_spinner "Texto de carga..." comando_a_ejecutar
ui_spinner() {
    local title="$1"
    shift
    
    if have_gum_ui; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        # Fallback: Ejecuta el comando directamente mostrando el título antes
        echo -e "${ANSI_BLUE}⏳ $title${ANSI_RESET}"
        "$@"
    fi
}

# Mostrar bloque de código (para la llave pública)
# Uso: echo "contenido" | ui_code_block
ui_code_block() {
    if have_gum_ui; then
        gum format -t code
    else
        echo "----------------------------------------"
        cat
        echo "----------------------------------------"
    fi
}

# Línea divisoria (opcional, para separar secciones visualmente)
ui_separator() {
    if have_gum_ui; then
        gum style --foreground "$COLOR_INFO" "────────────────────────────────────────"
    else
        echo "----------------------------------------"
    fi
}

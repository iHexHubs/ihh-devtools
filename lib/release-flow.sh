#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/release-flow.sh

# ==============================================================================
# CONFIGURACIÓN DE VERSIONADO
# ==============================================================================
# Archivo fuente de verdad (La raíz del proyecto se asume un nivel arriba de .devtools o en root)
# Intentamos localizar el archivo VERSION relativo a la posición de este script
if [[ -f "${SCRIPT_DIR}/../../VERSION" ]]; then
    VERSION_FILE="${SCRIPT_DIR}/../../VERSION"
elif [[ -f "VERSION" ]]; then
    VERSION_FILE="VERSION"
else
    # Fallback si no encuentra nada
    VERSION_FILE="VERSION"
fi

# ==============================================================================
# FASE 1 (NUEVO): NORMALIZACIÓN ROBUSTA DE ROOT + VERSION_FILE
# ==============================================================================
# Objetivo:
# - Evitar depender de SCRIPT_DIR heredado del caller (frágil).
# - Usar siempre el VERSION del repo actual (REPO_ROOT/VERSION) cuando exista.
# - Mantener backward-compat: si REPO_ROOT no está disponible, inferirlo.
#
# REPO_ROOT debe venir exportado desde core/config.sh, pero lo inferimos si falta.
# Nota: NO eliminamos la lógica previa; solo la hacemos "source of truth" al final.
if [[ -z "${REPO_ROOT:-}" ]]; then
    export REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

# Directorio real de este archivo (no del script que lo sourcea)
__THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar helpers SemVer
if [[ -f "${__THIS_DIR}/core/semver.sh" ]]; then
    # shellcheck disable=SC1090
    source "${__THIS_DIR}/core/semver.sh"
else
    echo "❌ No se encontro core/semver.sh" >&2
    return 1 2>/dev/null || exit 1
fi

# Cargar helpers de resumen de commits
if [[ -f "${__THIS_DIR}/core/commit-summary.sh" ]]; then
    # shellcheck disable=SC1090
    source "${__THIS_DIR}/core/commit-summary.sh"
else
    echo "❌ No se encontro core/commit-summary.sh" >&2
    return 1 2>/dev/null || exit 1
fi

# Si existe el VERSION en la raíz del repo actual, es la fuente de verdad.
if [[ -f "${REPO_ROOT}/VERSION" ]]; then
    VERSION_FILE="${REPO_ROOT}/VERSION"
# Fallback: si el repo está embebido en un superrepo y por alguna razón REPO_ROOT no apunta bien,
# intentamos con la lógica histórica relativa al directorio de ESTE archivo.
elif [[ -f "${__THIS_DIR}/../../VERSION" ]]; then
    VERSION_FILE="${__THIS_DIR}/../../VERSION"
# Fallback: ruta relativa al cwd (comportamiento histórico)
elif [[ -f "VERSION" ]]; then
    VERSION_FILE="VERSION"
else
    # Fallback final si no encuentra nada
    VERSION_FILE="VERSION"
fi

# ==============================================================================
# 1. HELPERS DE VERSIONADO (SEMVER / RC)
# ==============================================================================

get_current_version() {
    local raw normalized
    if [ -f "$VERSION_FILE" ]; then
        # Lee el archivo, quita espacios en blanco
        raw="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
    else
        # Si no existe, iniciamos en 0.0.0
        raw="0.0.0"
    fi

    if normalized="$(semver_normalize "$raw")"; then
        echo "$normalized"
    else
        echo "$raw"
    fi
}

# Lógica pura de SemVer basada en Conventional Commits
# MODIFICADO: Garantiza que cualquier cambio suba al menos el Patch.
calculate_next_version() {
    semver_next_from_commits "$1"
}

# [FIX] Corregido para iniciar en 1 si no hay RCs previos para ESTA versión
next_rc_number() {
    semver_next_rc "$1"
}

next_build_number() {
    semver_next_build "$1" "$2"
}

valid_tag() {
    semver_valid_tag_ref "$1"
}

get_last_stable_tag() {
    semver_last_stable_tag_or_bootstrap
}

# ==============================================================================
# 2. HELPERS DE RELEASE NOTES (CAPTURA Y FORMATO)
# ==============================================================================

capture_release_notes() {
    local outfile="$1"

    # Integración con GUM (UI moderna)
    if command -v gum >/dev/null 2>&1; then
        gum write \
            --width 120 \
            --height 25 \
            --placeholder "Pega aqui las notas de lanzamiento (Markdown). Guarda y cierra para continuar..." \
            > "$outfile"
        return 0
    fi

    # Fallback: Editor de texto del sistema (vim, nano, etc.)
    if [[ -n "${EDITOR:-}" ]]; then
        "${EDITOR}" "$outfile"
        return 0
    fi

    # Fallback final: Entrada estándar
    echo "Pega las notas de lanzamiento (Markdown). Termina con Ctrl-D:"
    cat > "$outfile"
}

prepend_release_notes_header() {
    local outfile="$1"
    local header="$2"
    # Fuerza un encabezado consistente al inicio del archivo
    {
        echo "$header"
        echo ""
        cat "$outfile"
    } > "${outfile}.final"
    mv "${outfile}.final" "$outfile"
}

# ==============================================================================
# 3. GENERADOR DE PROMPTS PARA IA (RELEASE MANAGER)
# ==============================================================================

generate_ai_prompt() {
    local from_branch=$1
    local to_branch=$2
    local diff_stat
    local commit_log
    local summary_counts
    local summary_grouped
    
    # Asumimos que log_info y colores vienen de utils.sh
    if command -v log_info >/dev/null; then
        log_info "🤖 Generando prompt para notas de lanzamiento..."
    else
        echo "🤖 Generando prompt para notas de lanzamiento..."
    fi
    
    # Intentamos ser resilientes con ramas remotas
    diff_stat=$(git diff --stat "$to_branch..$from_branch" 2>/dev/null || echo "No hay diferencias disponibles")
    commit_log=$(git log --pretty=format:"- %s (%an)" "$to_branch..$from_branch" 2>/dev/null \
        | grep -Ev '^- chore\\(release\\):[[:space:]]*actualizar changelog' \
        || echo "No hay registro disponible")
    summary_counts=$(commit_summary_counts "$to_branch..$from_branch" 2>/dev/null || echo "Sin commits")
    summary_grouped=$(commit_summary_grouped "$to_branch..$from_branch" 0 2>/dev/null || echo "Sin commits")
    
    cat <<EOF
--------------------------------------------------------------------------------
COPIA ESTE PROMPT PARA TU IA:
--------------------------------------------------------------------------------
Actua como responsable de lanzamientos experto.
Genera unas notas de lanzamiento profesionales en Markdown para la version que estamos desplegando.

Contexto:
- Origen: $from_branch
- Destino: $to_branch

Resumen por tipo (conteo):
$summary_counts

Resumen por tipo y scope (completo):
$summary_grouped

Cambios (commits):
$commit_log

Archivos afectados:
$diff_stat

Instrucciones:
1. Agrupa los cambios por tipo (Funciones, Correcciones, Mantenimiento).
2. Destaca lo más importante para el usuario final.
3. Usa un tono tecnico pero claro.
--------------------------------------------------------------------------------
EOF
    
    echo "--------------------------------------------------------------------------------"
    read -r -p "Presiona ENTER cuando hayas copiado el prompt para continuar..."
}

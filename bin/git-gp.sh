#!/usr/bin/env bash
# Push helper con guardas de flujo.
set -euo pipefail
IFS=$'\n\t'
#  "El bug es este"
# ==============================================================================
# DISPATCHER DE CONTEXTO (repo raíz -> script correcto)......
# ==============================================================================
if [[ "${DEVTOOLS_DISPATCH_DONE:-0}" != "1" ]]; then
    __read_vendor_dir_from_contract() {
        local contract_file="$1"
        [[ -f "$contract_file" ]] || return 0
        awk '
            function clean(v) {
                gsub(/["\047]/, "", v)
                sub(/[[:space:]]+#.*/, "", v)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                return v
            }
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next }
            in_paths && /^[^[:space:]]/ { in_paths=0 }
            in_paths && /^[[:space:]]*vendor_dir:[[:space:]]*/ {
                line=$0
                sub(/^[[:space:]]*vendor_dir:[[:space:]]*/, "", line)
                print clean(line)
                exit
            }
            /^[[:space:]]*vendor_dir:[[:space:]]*/ {
                line=$0
                sub(/^[[:space:]]*vendor_dir:[[:space:]]*/, "", line)
                print clean(line)
                exit
            }
        ' "$contract_file" 2>/dev/null || true
    }

    __self_path="${BASH_SOURCE[0]}"
    __self_real="$(cd "$(dirname "${__self_path}")" && pwd)/$(basename "${__self_path}")"
    __repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    __script_name="$(basename "${__self_path}")"
    __dispatch_target=""
    __vendor_dir="$(__read_vendor_dir_from_contract "${__repo_root}/devtools.repo.yaml")"

    if [[ -n "${__vendor_dir:-}" ]]; then
        __vendor_dir="${__vendor_dir#./}"
        __vendor_dir="${__vendor_dir%/}"
    fi

    __candidates=("${__repo_root}/bin/${__script_name}")
    if [[ -n "${__vendor_dir:-}" ]]; then
        __candidates+=("${__repo_root}/${__vendor_dir}/bin/${__script_name}")
    fi

    for __candidate in "${__candidates[@]}"; do
        [[ -f "${__candidate}" ]] || continue
        __candidate_real="$(cd "$(dirname "${__candidate}")" && pwd)/$(basename "${__candidate}")"
        if [[ "${__candidate_real}" != "${__self_real}" ]]; then
            __dispatch_target="${__candidate}"
            break
        fi
        __dispatch_target="${__candidate}"
        break
    done

    [[ -n "${__dispatch_target:-}" ]] || { echo "❌ No encontré ${__script_name} para dispatch (REPO_ROOT=${__repo_root})." >&2; exit 127; }
    export DEVTOOLS_DISPATCH_REPO_ROOT="${__repo_root}"
    export DEVTOOLS_DISPATCH_TO="${__dispatch_target}"
    if [[ "${__dispatch_target}" != "${__self_real}" ]]; then
        if [[ "${DEVTOOLS_DEBUG_DISPATCH:-0}" == "1" ]]; then
            echo "ℹ️  DISPATCH_REPO_ROOT=${DEVTOOLS_DISPATCH_REPO_ROOT}"
            echo "ℹ️  DISPATCH_TO=${DEVTOOLS_DISPATCH_TO}"
        fi
        export DEVTOOLS_DISPATCH_DONE=1
        exec bash "${__dispatch_target}" "$@"
    fi
fi

# ==============================================================================
# 1. BOOTSTRAP DE LIBRERÍAS
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/core/utils.sh"       # Logs (log_info, log_warn)
source "${LIB_DIR}/git-context.sh" # Lógica de extracción de diffs y tickets
source "${LIB_DIR}/ai-prompts.sh"  # Templates de Prompts para la IA

# ==============================================================================
# 2. RECOLECCIÓN DE DATOS (CONTEXTO).
# ==============================================================================
log_info "🤖 La IA está analizando tus cambios y archivos nuevos..."

BRANCH_NAME=$(git branch --show-current)

# Usamos la función de la librería git-context.sh
CHANGES=$(get_full_context_diff)

# Validación: Si no hay nada que commitear, avisamos y salimos
if [ -z "$CHANGES" ]; then
    log_warn "No detecté cambios pendientes (staged, unstaged o untracked)."
    log_info "Tip: Haz cambios en algún archivo antes de pedir ayuda a la IA."
    exit 0
fi

# Detectamos ticket desde el nombre de la rama
DETECTED_ISSUE=$(get_detected_issue "$BRANCH_NAME")

if [ -n "$DETECTED_ISSUE" ]; then
    log_info "ℹ️  Detecté el Ticket #$DETECTED_ISSUE en la rama."
fi

# ==============================================================================
# 3. GENERACIÓN DEL PROMPT
# ==============================================================================

# Generamos el texto usando la librería ai-prompts.sh y lo enviamos a stdout.
generate_gp_prompt "$BRANCH_NAME" "$DETECTED_ISSUE" "$CHANGES"

# (Opcional) Mensaje final para guiar al usuario
echo
log_info "Copia el bloque de arriba y pégalo en tu IA de confianza."

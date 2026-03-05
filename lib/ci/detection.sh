#!/usr/bin/env bash
# Detección de herramientas CI y runtime.

__devtools_ci_detection_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/contract.sh
source "${__devtools_ci_detection_dir}/../core/contract.sh"

# ==============================================================================
# LÓGICA DE DETECCIÓN (Auto-Discovery Robusto)
# ==============================================================================

# Cache por proceso para evitar ejecutar `task --list` en cada task_exists().
DEVTOOLS_TASK_LIST_CACHE="${DEVTOOLS_TASK_LIST_CACHE:-}"
DEVTOOLS_TASK_LIST_CACHE_LOADED="${DEVTOOLS_TASK_LIST_CACHE_LOADED:-0}"

load_task_list_cache() {
    if [[ "${DEVTOOLS_TASK_LIST_CACHE_LOADED:-0}" == "1" ]]; then
        return 0
    fi

    if ! command -v task >/dev/null 2>&1; then
        DEVTOOLS_TASK_LIST_CACHE=""
        DEVTOOLS_TASK_LIST_CACHE_LOADED=1
        return 0
    fi

    # OFFLINE-safe: solo lectura local. Sin red.
    DEVTOOLS_TASK_LIST_CACHE="$(TASK_COLOR=0 task --list 2>/dev/null || true)"
    DEVTOOLS_TASK_LIST_CACHE_LOADED=1
    return 0
}

# Helper: Verifica si una tarea existe realmente en el Taskfile (incluso importada)
task_exists() {
    local task_name="$1"
    [[ -n "${task_name:-}" ]] || return 1

    load_task_list_cache || true
    [[ -n "${DEVTOOLS_TASK_LIST_CACHE:-}" ]] || return 1

    # Parser robusto: soporta formatos comunes de `task --list`:
    # 1) "* ci:      desc"  -> $1="*"  $2="ci:"
    # 2) "- ci:      desc"  -> $1="-"  $2="ci:"
    # 3) "ci:        desc"  -> $1="ci:"
    # 4) "ci         desc"  -> $1="ci"
    awk -v want="${task_name}" '
        /^task:/ {next}          # ignora encabezados tipo "task: Available tasks..."
        NF==0 {next}             # ignora líneas vacías
        {
            name=$1
            if (name ~ /^[*+-]$/) { name=$2 }   # bullet separado
            gsub(/^[*+-]+/, "", name)           # bullets pegados
            gsub(/:$/, "", name)                # quita ":" final
            if (name == want) exit 0
        }
        END {exit 1}
    ' <<<"${DEVTOOLS_TASK_LIST_CACHE}"
}

detect_ci_tools() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    local has_taskfile=0
    if [[ -f "${root}/Taskfile.yaml" || -f "${root}/Taskfile.yml" || -f "${root}/taskfile.yml" ]]; then
        has_taskfile=1
    fi

    : "${POST_PUSH_FLOW:=true}"

    # --- Nivel 1: CI Nativo (Prioridad: Contrato 'task ci') ---
    if [[ -z "${NATIVE_CI_CMD:-}" ]]; then
        if task_exists "ci"; then
            export NATIVE_CI_CMD="task ci"
        elif task_exists "test"; then
            export NATIVE_CI_CMD="task test"
        elif [[ "${has_taskfile}" == "1" ]]; then
            export NATIVE_CI_CMD="task ci"
        fi
    fi

    # --- Nivel 2: Act (GitHub Actions Local) ---
    if [[ -z "${ACT_CI_CMD:-}" ]]; then
        if task_exists "ci:act"; then
            export ACT_CI_CMD="task ci:act"
        elif [[ "${has_taskfile}" == "1" ]]; then
            export ACT_CI_CMD="task ci:act"
        # FIX: fallback seguro (NO usar `act` pelado). Si existe el wrapper Taskfile, úsalo.
        elif [[ -f "${root}/.github/workflows/test/Taskfile.yaml" ]]; then
            export ACT_CI_CMD="task -t .github/workflows/test/Taskfile.yaml trigger"
        fi
    fi

    # --- Nivel 3: Compose (Runtime Dev / Smoke) ---
    if [[ -z "${COMPOSE_CI_CMD:-}" ]]; then
        # Gracias a task_exists, esto detecta 'local:check' aunque venga de un include
        if task_exists "local:check"; then
                export COMPOSE_CI_CMD="task local:check"
        elif task_exists "local:up"; then
                export COMPOSE_CI_CMD="task local:up"
        fi
    fi

    # --- Nivel 4: K8s Headless (Build -> Deploy -> Smoke) ---
    if [[ -z "${K8S_HEADLESS_CMD:-}" ]]; then
        # 1. Preferencia: Alias explícito si existiera (Future-proof)
        if task_exists "pipeline:local:headless"; then
            export K8S_HEADLESS_CMD="task pipeline:local:headless"
        # 2. Composición dinámica: Si existen las 3 piezas clave
        elif task_exists "build:local" && task_exists "deploy:local" && task_exists "smoke:local"; then
            export K8S_HEADLESS_CMD="task build:local && task deploy:local && task smoke:local"
        fi
    fi

    # --- Nivel 5: K8s Full (Pipeline Interactivo) ---
    if [[ -z "${K8S_FULL_CMD:-}" ]]; then
        if task_exists "pipeline:local"; then
            export K8S_FULL_CMD="task pipeline:local"
        fi
    fi
}

# ==============================================================================
# REGISTRO DE APPS (apps.yaml)
# ==============================================================================

apps_registry_file() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

    # contrato-first: si contract.sh está cargado, resuelve el path permitido
    if declare -F devtools_require_build_registry >/dev/null 2>&1; then
        devtools_require_build_registry "$root"
        return $?
    fi

    # fallback ultra-simple (solo path permitido)
    local dot_dir=".devtools"
    echo "${root}/${dot_dir}/config/apps.yaml"
}

require_apps_registry() {
    local f
    f="$(apps_registry_file)"
    if [[ ! -f "$f" ]]; then
        echo "❌ No existe el registro de apps en: $f"
        return 1
    fi
}

have_yq() { command -v yq >/dev/null 2>&1; }
have_jq() { command -v jq >/dev/null 2>&1; }

__apps_list_fallback() {
    local f="$1"
    # Parser básico (YAML simple) para extraer id/path de apps y components.
    awk '
        function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        BEGIN{ in_apps=0; in_components=0; cur_id=""; cur_path=""; item_has_id=0; item_has_path=0; }
        {
            line=$0
            sub(/\r$/, "", line)
            if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
            if (line ~ /^apps:[[:space:]]*$/) { in_apps=1; in_components=0; next }
            if (!in_apps) next
            if (line ~ /^[[:space:]]*components:[[:space:]]*$/) { in_components=1; next }
            if (line ~ /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/) {
                cur_id=line
                sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", cur_id)
                cur_id=trim(cur_id)
                item_has_id=1
                item_has_path=0
                cur_path=""
                next
            }
            if (item_has_id && line ~ /^[[:space:]]*path:[[:space:]]*/) {
                cur_path=line
                sub(/^[[:space:]]*path:[[:space:]]*/, "", cur_path)
                cur_path=trim(cur_path)
                if (cur_id != "" && cur_path != "") {
                    printf "%s\t%s\n", cur_id, cur_path
                }
                item_has_path=1
                next
            }
        }
    ' "$f"
}

__app_resolve_fallback() {
    local needle="$1"
    local f="$2"
    local root="$3"
    local needle_norm
    needle_norm="$(normalize_app_ref "$needle" "$root")"

    # Fallback: busca primer match por id o path y extrae campos simples si aparecen.
    awk -v want="$needle_norm" '
        function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        BEGIN{ in_apps=0; found=0; id=""; path=""; build_mode=""; build_cmd_local=""; build_cmd_act=""; artifact_paths=""; zip_name_pattern=""; }
        {
            line=$0
            sub(/\r$/, "", line)
            if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
            if (line ~ /^apps:[[:space:]]*$/) { in_apps=1; next }
            if (!in_apps) next

            if (line ~ /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/) {
                id=line
                sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", id)
                id=trim(id)
                path=""
                build_mode=""
                build_cmd_local=""
                build_cmd_act=""
                artifact_paths=""
                zip_name_pattern=""
                found=0
                next
            }
            if (id != "" && line ~ /^[[:space:]]*path:[[:space:]]*/) {
                path=line
                sub(/^[[:space:]]*path:[[:space:]]*/, "", path)
                path=trim(path)
                if (id == want || path == want) found=1
                next
            }
            if (!found) next

            if (line ~ /^[[:space:]]*build_mode:[[:space:]]*/) { build_mode=line; sub(/^[[:space:]]*build_mode:[[:space:]]*/, "", build_mode); build_mode=trim(build_mode); next }
            if (line ~ /^[[:space:]]*build_cmd_local:[[:space:]]*/) { build_cmd_local=line; sub(/^[[:space:]]*build_cmd_local:[[:space:]]*/, "", build_cmd_local); build_cmd_local=trim(build_cmd_local); next }
            if (line ~ /^[[:space:]]*build_cmd_act:[[:space:]]*/) { build_cmd_act=line; sub(/^[[:space:]]*build_cmd_act:[[:space:]]*/, "", build_cmd_act); build_cmd_act=trim(build_cmd_act); next }
            if (line ~ /^[[:space:]]*zip_name_pattern:[[:space:]]*/) { zip_name_pattern=line; sub(/^[[:space:]]*zip_name_pattern:[[:space:]]*/, "", zip_name_pattern); zip_name_pattern=trim(zip_name_pattern); next }
        }
        END{
            if (!found) exit 2
            printf "app_id=%s\n", id
            printf "app_root=%s\n", path
            printf "build_mode=%s\n", build_mode
            printf "build_cmd_local=%s\n", build_cmd_local
            printf "build_cmd_act=%s\n", build_cmd_act
            printf "artifact_paths=%s\n", artifact_paths
            printf "zip_name_pattern=%s\n", zip_name_pattern
        }
    ' "$f"
}

normalize_app_ref() {
    local input="$1"
    local root="$2"
    local ref="$input"

    ref="${ref%/}"
    if [[ -n "$root" && "$ref" == "$root/"* ]]; then
        ref="${ref#$root/}"
    fi

    echo "$ref"
}

apps_list() {
    require_apps_registry || return 1

    local f
    f="$(apps_registry_file)"

    if have_yq; then
        yq -r '.apps[] | "\(.id)\t\(.path)"' "$f"
        yq -r '.apps[]?.components[]? | "\(.id)\t\(.path)"' "$f"
        return 0
    fi
    __apps_list_fallback "$f"
}

app_resolve() {
    local needle="${1:-}"
    if [[ -z "$needle" ]]; then
        echo "❌ Debes indicar APP=<id|path>."
        return 1
    fi

    local root f needle_norm app_json
    root="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    f="$(apps_registry_file)"
    require_apps_registry || return 1

    needle_norm="$(normalize_app_ref "$needle" "$root")"

    # Ruta rápida: si hay yq+jq, mantenemos el comportamiento completo.
    if have_yq && have_jq; then
        app_json="$(NEEDLE="$needle_norm" yq -o=json \
            '.apps[] | select(.id == strenv(NEEDLE) or .path == strenv(NEEDLE))' "$f")"

        if [[ -z "$app_json" || "$app_json" == "null" ]]; then
            app_json="$(NEEDLE="$needle_norm" yq -o=json \
                '.apps[]?.components[]? | select(.id == strenv(NEEDLE) or .path == strenv(NEEDLE))' "$f")"
        fi

        if [[ -z "$app_json" || "$app_json" == "null" ]]; then
            echo "❌ APP '$needle' no existe en $f."
            return 1
        fi

        local app_id app_path build_mode build_cmd_local build_cmd_act artifact_paths zip_name_pattern
        app_id="$(echo "$app_json" | jq -r '.id // ""')"
        app_path="$(echo "$app_json" | jq -r '.path // ""')"
        build_mode="$(echo "$app_json" | jq -r '.build_mode // ""')"
        build_cmd_local="$(echo "$app_json" | jq -r '.build_cmd_local // ""')"
        build_cmd_act="$(echo "$app_json" | jq -r '.build_cmd_act // ""')"
        artifact_paths="$(echo "$app_json" | jq -r '.artifact_paths // [] | join(",")')"
        zip_name_pattern="$(echo "$app_json" | jq -r '.zip_name_pattern // ""')"

        echo "app_id=$app_id"
        echo "app_root=$app_path"
        echo "build_mode=$build_mode"
        echo "build_cmd_local=$build_cmd_local"
        echo "build_cmd_act=$build_cmd_act"
        echo "artifact_paths=$artifact_paths"
        echo "zip_name_pattern=$zip_name_pattern"
        return 0
    fi

    # Fallback portable (sin yq/jq): mejor esfuerzo.
    if __app_resolve_fallback "$needle" "$f" "$root"; then
        return 0
    fi
    echo "❌ APP '$needle' no existe en $f." >&2
    return 1
}

# ==============================================================================
# DETECCIÓN DE ENTORNO ACTIVO (DevX: Runtime + Alternativas)
# ==============================================================================

# Detecta si Docker Compose (Traefik) está activo (stack runtime)
detect_compose_active() {
    command -v docker >/dev/null || return 1
    # Indicador principal del stack: traefik (gateway único)
    # MODIFICADO (1.4): Usar variable configurable en lugar de hardcode
    local gateway="${COMPOSE_GATEWAY_CONTAINER:-traefik}"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -Fxq "$gateway"
}

# Detecta si Minikube/K8s local está activo (runtime prod-like)
detect_minikube_active() {
    # Contexto actual
    if command -v kubectl >/dev/null; then
        local ctx
        ctx="$(kubectl config current-context 2>/dev/null || echo "")"
        if [[ "$ctx" == "minikube" ]]; then
            # Si minikube está instalado, verificamos que esté corriendo
            if command -v minikube >/dev/null; then
                minikube status 2>/dev/null | grep -q "Running"
                return $?
            fi
            # Si no está minikube, pero el contexto es minikube, asumimos activo.
            return 0
        fi
    fi

    # Fallback: minikube status (si kubectl no está o el contexto no está configurado)
    if command -v minikube >/dev/null; then
        minikube status 2>/dev/null | grep -q "Running"
        return $?
    fi

    return 1
}

# Detecta si estamos dentro de Devbox (toolchain / shell)
detect_devbox_active() {
    # Devbox suele exportar DEVBOX_ENV_NAME, pero no es garantía universal.
    [[ -n "${DEVBOX_ENV_NAME:-}" ]] && return 0
    [[ -n "${DEVBOX_SHELL_ENABLED:-}" ]] && return 0
    [[ -n "${IN_DEVBOX_SHELL:-}" ]] && return 0
    return 1
}

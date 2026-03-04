#!/usr/bin/env bash
# Librería de soporte (devtools)

# ==============================================================================
# 1. VALIDACIONES DE HERRAMIENTAS (GH CLI)
# ==============================================================================

ensure_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        if declare -F log_error >/dev/null 2>&1; then
            log_error "No se encontró 'gh' (GitHub CLI)."
        else
            echo "ERROR: falta 'gh' (GitHub CLI)." >&2
        fi
        if declare -F log_info >/dev/null 2>&1; then
            log_info "Instala 'gh' (GitHub CLI) para continuar."
        else
            echo "Instala 'gh' para continuar." >&2
        fi
        return 1 2>/dev/null || exit 1
    fi

    if ! GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 gh auth status --hostname github.com >/dev/null 2>&1; then
        if declare -F log_error >/dev/null 2>&1; then
            log_error "gh no está autenticado."
        else
            echo "ERROR: gh no autenticado." >&2
        fi
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "Ejecuta: gh auth login"
        else
            echo "Ejecuta: gh auth login" >&2
        fi
        return 1 2>/dev/null || exit 1
    fi
}

# ==============================================================================
# 1.1 HELPERS PARA MERGE AUTOMÁTICO
# ==============================================================================
# Objetivo:
# - Esperar de forma robusta a que un PR quede mergeado cuando usamos `gh pr merge --auto`.
# - Obtener el SHA del merge commit.
#
# Variables (defaults pueden venir de core/config.sh):
# - DEVTOOLS_PR_MERGE_TIMEOUT_SECONDS (default 900)
# - DEVTOOLS_PR_MERGE_POLL_SECONDS (default 5)
wait_for_pr_merge_and_get_sha() {
    local pr_number="$1"
    local timeout="${DEVTOOLS_PR_MERGE_TIMEOUT_SECONDS:-900}"
    local interval="${DEVTOOLS_PR_MERGE_POLL_SECONDS:-5}"
    local elapsed=0

    ensure_gh_cli

    while true; do
        local merged state
        merged="$(GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 gh pr view "$pr_number" --json merged --jq '.merged' 2>/dev/null || echo "false")"
        state="$(GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || echo "")"

        if [[ "$merged" == "true" ]]; then
            local merge_sha
            merge_sha="$(GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 gh pr view "$pr_number" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || echo "")"

            if [[ -n "${merge_sha:-}" && "${merge_sha:-null}" != "null" ]]; then
                echo "$merge_sha"
                return 0
            fi
            # Si está merged pero no podemos leer mergeCommit, seguimos intentando un poco.
        else
            # Si el PR se cerró sin merge, abortamos.
            if [[ "$state" == "CLOSED" ]]; then
                log_error "El PR #$pr_number está CLOSED y no fue mergeado."
                return 1
            fi
        fi

        if (( elapsed >= timeout )); then
            log_error "Timeout esperando a que el PR #$pr_number sea mergeado."
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

# ==============================================================================
# 2. OPERACIONES DE PULL REQUESTS
# ==============================================================================

# Verifica si existe un PR abierto para la rama actual hacia la base
# Retorna: 0 (True) si existe, 1 (False) si no.
pr_exists() {
    local head="$1"
    local base="$2"
    local count
    
    # GH_PAGER=cat evita que se quede colgado esperando input del usuario
    count="$(GH_PAGER=cat gh pr list --state open --head "$head" --base "$base" --json number --jq 'length' 2>/dev/null || echo 0)"
    
    if [[ "$count" -gt 0 ]]; then
        return 0 # Existe
    else
        return 1 # No existe
    fi
}

create_pr() {
    local head="$1"
    local base="$2"
    
    log_info "🚀 Creando PR: $head -> $base"
    
    # --fill intenta llenar título y cuerpo con el último commit
    if GH_PAGER=cat gh pr create --base "$base" --head "$head" --fill; then
        log_success "PR Creado exitosamente."
    else
        log_error "Falló la creación del PR."
        exit 1
    fi
}

show_pr_info() {
    local head="$1"
    local base="$2"
    
    log_info "🟢 Ya existe un PR abierto para esta rama:"
    echo "---------------------------------------------------"
    GH_PAGER=cat gh pr list --state open --head "$head" --base "$base"
    echo "---------------------------------------------------"
}

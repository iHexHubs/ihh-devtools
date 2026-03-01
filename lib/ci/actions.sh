#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/ci/actions.sh

# ==============================================================================
# LÓGICA DE ACCIONES (Creación de PRs, Pipelines complejos, etc.)
# ==============================================================================

# ==============================================================================
# VISUALIZACIÓN DE WORKFLOWS (Live Logs).
# ==============================================================================

# Busca el último run en una rama y hace streaming de los logs a la terminal.
# Retorna 0 si el workflow fue exitoso, 1 si falló.
wait_and_watch_workflow() {
    local branch="$1"
    local workflow_name="${2:-}" # Opcional: filtrar por nombre de workflow

    # Verificación de dependencia
    if ! command -v gh &> /dev/null; then
        echo "⚠️  GitHub CLI (gh) no instalado. No puedo mostrar logs en vivo."
        # No bloqueamos el flujo si falta la herramienta visual, pero avisamos.
        return 0
    fi

    echo "⏳ Buscando workflows activos en '$branch'..."
    
    # Damos un momento para que GitHub registre el evento del push
    sleep 5

    # Buscamos el ID del último run en ejecución o encolado
    local run_id=""
    local retries=5
    
    while [[ $retries -gt 0 ]]; do
        if [[ -n "$workflow_name" ]]; then
            run_id="$(gh run list --branch "$branch" --workflow "$workflow_name" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
        else
            run_id="$(gh run list --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
        fi
        
        if [[ -n "$run_id" ]]; then
            break
        fi
        
        echo "   ... esperando que inicie el workflow ($retries)..."
        sleep 3
        retries=$((retries - 1))
    done

    if [[ -z "$run_id" ]]; then
        echo "⚠️  No se detectó ningún workflow corriendo en '$branch' tras varios intentos."
        echo "    (Puede que no haya workflow configurado o tardó mucho en iniciar)."
        return 0
    fi

    echo "📺 Conectando con GitHub Actions (Run ID: $run_id)..."
    echo "════════════════════════════════════════════════════"

    # Fuente de verdad: si checks.sh está cargado, delegamos al helper unificado.
    if declare -F watch_workflow_run_or_die >/dev/null 2>&1; then
        if watch_workflow_run_or_die "$run_id" "workflow" "${DEVTOOLS_BUILD_WAIT_TIMEOUT_SECONDS:-1800}" "${DEVTOOLS_BUILD_WAIT_POLL_SECONDS:-10}"; then
            echo "════════════════════════════════════════════════════"
            echo "✅ Workflow finalizado exitosamente."
            return 0
        fi
        echo "════════════════════════════════════════════════════"
        echo "❌ El workflow falló."
        return 1
    fi

    # Fallback legacy si el helper unificado no está disponible.
    if gh run watch "$run_id" --exit-status; then
        echo "════════════════════════════════════════════════════"
        echo "✅ Workflow finalizado exitosamente."
        return 0
    else
        echo "════════════════════════════════════════════════════"
        echo "❌ El workflow falló."
        return 1
    fi
}

# Helper: Creación de PR
# Invoca al script `git-pr.sh` pasando la rama base correcta.
do_create_pr_flow() {
    local head="$1"
    local base="$2"
    
    # Obtenemos el directorio donde reside ESTE script (.devtools/lib/ci)
    local current_dir
    current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Calculamos la ruta absoluta hacia git-pr.sh (.devtools/bin/git-pr.sh)
    # Subimos 2 niveles: lib/ci -> lib -> .devtools -> bin
    local pr_script="${current_dir}/../../bin/git-pr.sh"

    if [[ -f "$pr_script" ]]; then
        # MODIFICADO (1.2): Exportamos BASE_BRANCH para que git-pr.sh sepa a dónde apuntar
        BASE_BRANCH="$base" "$pr_script"
        if [ $? -eq 0 ]; then
            echo "Gracias por el trabajo, en breve se revisa."
            return 0
        fi
    elif command -v git-pr >/dev/null; then
        # Fallback por si git-pr está en el PATH global
        if git-pr; then return 0; fi
    else
        echo "❌ No encuentro el script git-pr.sh en $pr_script ni en el PATH."
        return 1
    fi
    
    echo "⚠️ Hubo un problema creando el PR."
    return 1
}

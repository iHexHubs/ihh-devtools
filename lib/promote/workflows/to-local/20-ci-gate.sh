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


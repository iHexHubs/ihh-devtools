#!/usr/bin/env bash
# Promote workflow helpers: common
# Este módulo contiene helpers comunes y utilidades de limpieza:
# - banner (fallback de compatibilidad)
# - resync_submodules_hard
# - cleanup_bot_branches
# - __read_repo_version
# - maybe_delete_source_branch (NUEVO: Borrado inteligente de ramas fuente)
#
# Dependencias: utils.sh (para log_info, log_warn, ask_yes_no, etc.)

# ==============================================================================
# COMPAT: banner puede no estar cargado por el caller en algunos entornos.
# - Si no existe, definimos un fallback simple para evitar "command not found".
# ==============================================================================
if ! declare -F banner >/dev/null 2>&1; then
    banner() {
        echo
        echo "=================================================="
        echo " $*"
        echo "=================================================="
        echo
    }
fi

# ==============================================================================
# HELPERS: Gestión de repositorio y limpieza
# ==============================================================================

# [FIX] Solución de raíz: re-sincronizar submódulos para evitar estados dirty falsos
resync_submodules_hard() {
  GIT_TERMINAL_PROMPT=0 git submodule sync --recursive >/dev/null 2>&1 || true
  GIT_TERMINAL_PROMPT=0 git submodule update --init --recursive >/dev/null 2>&1 || true
}

__read_repo_version() {
    local vf
    vf="$(resolve_repo_version_file)"
    [[ -f "$vf" ]] || return 1
    cat "$vf" | tr -d '[:space:]'
}

# Helper para limpieza de ramas de release-please (NUEVO)
cleanup_bot_branches() {
    local mode="${1:-prompt}" # prompt | auto
    
    log_info "🧹 Buscando ramas de 'release-please' fusionadas para limpiar..."
    
    # Fetch para asegurar que la lista remota está fresca
    GIT_TERMINAL_PROMPT=0 git fetch origin --prune

    # Buscamos ramas remotas que cumplan:
    # 1. Estén totalmente fusionadas en HEAD (staging/dev)
    # 2. Coincidan con el patrón del bot
    local branches_to_clean
    branches_to_clean="$(
        git branch -r --merged HEAD \
            | grep 'origin/release-please--' \
            | sed 's|origin/||' \
            | sed 's/^[[:space:]]*//' \
            | sed '/^$/d' \
            || true
        )"

    if [[ -z "$branches_to_clean" ]]; then
        log_info "✨ No hay ramas de bot pendientes de limpieza."
        return 0
    fi

    echo "🔍 Se encontraron las siguientes ramas de bot fusionadas:"
    echo "$branches_to_clean"
    echo

    # Modo automático (sin prompts): requerido para mantener el repo limpio al promover a staging
    if [[ "$mode" == "auto" ]]; then
        log_info "🧹 Limpieza automática activada (sin confirmación)."
        local IFS=$'\n'
        for branch in $branches_to_clean; do
            log_info "🔥 Eliminando remote: $branch"
            GIT_TERMINAL_PROMPT=0 git push origin --delete "$branch" || log_warn "No se pudo borrar $branch (tal vez ya no existe)."
        done
        log_success "🧹 Limpieza completada."
        return 0
    fi

    if ask_yes_no "¿Eliminar estas ramas remotas para mantener la limpieza?"; then
        local IFS=$'\n'
        for branch in $branches_to_clean; do
            log_info "🔥 Eliminando remote: $branch"
            GIT_TERMINAL_PROMPT=0 git push origin --delete "$branch" || log_warn "No se pudo borrar $branch (tal vez ya no existe)."
        done
        log_success "🧹 Limpieza completada."
    else
        log_warn "Omitiendo limpieza de ramas."
    fi
}

# ==============================================================================
# CHANGELOG: Generación y commit centralizado (git-cliff)
# ==============================================================================

resolve_promote_component() {
    local range="${1:-}"
    local component="${PROMOTE_COMPONENT:-}"

    if [[ -n "${component:-}" ]]; then
        echo "$component"
        return 0
    fi

    local files
    files="$(git diff --name-only "${range}" 2>/dev/null || true)"
    if [[ -z "${files:-}" ]]; then
        local ihh="ihh"
        local eco="ecosystem"
        echo "${ihh}-${eco}"
        return 0
    fi

    local dot_dir=".devtools"
    local all_ihh=1 all_pmbok=1 all_el_rincon=1 all_devbox=1
    while IFS= read -r file; do
        [[ "$file" == apps/ihh/* ]] || all_ihh=0
        [[ "$file" == apps/pmbok/* ]] || all_pmbok=0
        [[ "$file" == apps/iHexHubs/* ]] || all_el_rincon=0
        [[ "$file" == ${dot_dir}/* ]] || all_devbox=0
    done <<< "$files"

    if [[ "$all_ihh" -eq 1 ]]; then
        echo "ihh"
        return 0
    fi
    if [[ "$all_pmbok" -eq 1 ]]; then
        echo "pmbok"
        return 0
    fi
    if [[ "$all_el_rincon" -eq 1 ]]; then
        echo "iHexHubs"
        return 0
    fi
    if [[ "$all_devbox" -eq 1 ]]; then
        echo "devbox"
        return 0
    fi

    local ihh="ihh"
    local eco="ecosystem"
    echo "${ihh}-${eco}"
}

generate_changelog_for_component() {
    local component="${1:-}"
    local tag="${2:-}"
    local range="${3:-}"
    local dot_dir=".devtools"
    local repo_root
    repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

    local config_file="${repo_root}/cliff.toml"
    [[ -f "$config_file" ]] || die "No se encontró cliff.toml (necesario para git-cliff)."

    local output_file=""
    local -a scope_opts=()
    local -a range_opts=()
    case "$component" in
        ihh)
            output_file="${repo_root}/apps/ihh/CHANGELOG.md"
            scope_opts=(--include-path "apps/ihh/**")
            ;;
        pmbok)
            output_file="${repo_root}/apps/pmbok/CHANGELOG.md"
            scope_opts=(--include-path "apps/pmbok/**")
            ;;
        iHexHubs)
            output_file="${repo_root}/apps/iHexHubs/CHANGELOG.md"
            scope_opts=(--include-path "apps/iHexHubs/**")
            ;;
        devbox)
            output_file="${repo_root}/${dot_dir}/CHANGELOG.md"
            scope_opts=(--include-path "${dot_dir}/**")
            ;;
        *)
            output_file="${repo_root}/CHANGELOG.md"
            scope_opts=(--exclude-path "apps/**" --exclude-path "${dot_dir}/**")
            local ihh="ihh"
            local eco="ecosystem"
            component="${ihh}-${eco}"
            ;;
    esac

    mkdir -p "$(dirname "$output_file")"

    if [[ -n "${range:-}" ]]; then
        range_opts+=("$range")
    fi

    local tag_pattern="^([A-Za-z0-9._-]+-)?v[0-9]+\\.[0-9]+\\.[0-9]+(-rc\\.[0-9]+(\\+build\\.[0-9]+)?)?$"

    local tmp_full=""
    local tmp_section=""
    local tmp_dedup=""
    local tmp_merged=""
    tmp_full="$(mktemp)" || die "No pude crear temporal para changelog."
    tmp_section="$(mktemp)" || die "No pude crear temporal para sección de changelog."
    tmp_dedup="$(mktemp)" || die "No pude crear temporal para deduplicación de changelog."
    tmp_merged="$(mktemp)" || die "No pude crear temporal para merge de changelog."

    if command -v git-cliff >/dev/null 2>&1; then
        git-cliff --config "$config_file" \
            "${scope_opts[@]}" \
            --tag-pattern "$tag_pattern" \
            --tag "$tag" \
            "${range_opts[@]}" \
            -o "$tmp_full"
    elif command -v devbox >/dev/null 2>&1; then
        local devbox_env=""
        devbox_env="$(devbox shell --print-env 2>/dev/null)" \
            || die "No pude obtener entorno de Devbox para ejecutar git-cliff."
        (
            eval "$devbox_env"
            git-cliff --config "$config_file" \
                "${scope_opts[@]}" \
                --tag-pattern "$tag_pattern" \
                --tag "$tag" \
                "${range_opts[@]}" \
                -o "$tmp_full"
        ) || die "Falló git-cliff usando entorno de Devbox."
    else
        die "No se encontró git-cliff ni devbox para ejecutarlo."
    fi

    local tag_header="## ${tag}"
    if ! awk -v tag_header="$tag_header" '
        BEGIN { capture=0; found=0 }
        $0 == tag_header {
            capture=1
            found=1
        }
        capture {
            if ($0 ~ /^## / && $0 != tag_header && found == 1) {
                exit
            }
            print
        }
        END {
            if (found == 0) {
                exit 3
            }
        }
    ' "$tmp_full" > "$tmp_section"; then
        local awk_rc=$?
        if [[ "$awk_rc" -eq 3 ]]; then
            die "No encontré sección '${tag_header}' en salida de git-cliff."
        fi
        die "No pude extraer sección '${tag_header}' del changelog generado."
    fi

    # Dedup exacto de bullets para evitar repetidos por commits con cuerpo largo.
    awk '
        /^- / {
            if (seen[$0]++) {
                next
            }
        }
        { print }
    ' "$tmp_section" > "$tmp_dedup"

    if [[ ! -f "$output_file" || ! -s "$output_file" ]]; then
        printf '# Changelog\n\n' > "$output_file"
    fi
    if ! grep -Eq '^# Changelog' "$output_file"; then
        {
            printf '# Changelog\n\n'
            cat "$output_file"
        } > "$tmp_merged"
        mv "$tmp_merged" "$output_file"
    fi

    if grep -Fq "$tag_header" "$output_file"; then
        rm -f "$tmp_full" "$tmp_section" "$tmp_dedup" "$tmp_merged"
        echo "$output_file"
        return 0
    fi

    {
        head -n 1 "$output_file"
        printf '\n'
        cat "$tmp_dedup"
        printf '\n'
        tail -n +2 "$output_file"
    } > "$tmp_merged"
    mv "$tmp_merged" "$output_file"

    rm -f "$tmp_full" "$tmp_section" "$tmp_dedup" "$tmp_merged"
    echo "$output_file"
}

prepare_changelog_commit() {
    local tag="${1:-}"
    local range="${2:-}"
    local component="${3:-}"

    [[ -n "${tag:-}" ]] || die "Tag requerido para generar changelog."

    if declare -F ensure_clean_git >/dev/null 2>&1; then
        ensure_clean_git
    fi

    if [[ -z "${component:-}" ]]; then
        component="$(resolve_promote_component "$range")"
    fi
    if [[ -z "${component:-}" ]]; then
        local ihh="ihh"
        local eco="ecosystem"
        component="${ihh}-${eco}"
    fi

    log_info "🧾 Generando changelog (componente=${component}, tag=${tag})"

    local output_file
    output_file="$(generate_changelog_for_component "$component" "$tag" "$range")"
    [[ -n "${output_file:-}" ]] || die "No pude resolver el archivo de changelog."
    export DEVTOOLS_CHANGELOG_FILE="${output_file}"
    export DEVTOOLS_CHANGELOG_UPDATED="0"

    local contamination_pattern=""
    contamination_pattern="(/web""apps\\/|/ho""me/|/Us""ers/|\\.dev""tools\\/|git""hub\\.com/|git@gi""thub\\.com:)"
    if grep -nE "$contamination_pattern" "$output_file"; then
        die "CHANGELOG contaminado: se detectó patrón prohibido en ${output_file}"
    fi

    if git diff --quiet -- "$output_file"; then
        log_warn "El changelog no cambió (${output_file}). Omitiendo commit."
        return 0
    fi

    export DEVTOOLS_CHANGELOG_UPDATED="1"
    log_info "📝 Changelog actualizado en ${output_file} (se integrará en commit final)."
}

# ==============================================================================
# UI: Panel de comparación de commits (solo TTY)
# ==============================================================================

render_commit_diff_panel() {
    local title="$1"
    local range="$2"

    if ! declare -F can_prompt >/dev/null 2>&1; then
        return 0
    fi
    if ! can_prompt; then
        return 0
    fi

    if ! declare -F commit_summary_counts >/dev/null 2>&1; then
        local _base_dir _core_file
        _base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        _core_file="${_base_dir}/../../core/commit-summary.sh"
        if [[ -f "${_core_file}" ]]; then
            # shellcheck disable=SC1090
            source "${_core_file}"
        else
            return 0
        fi
    fi

    if ! declare -F ui_card >/dev/null 2>&1; then
        local _ui_file
        _ui_file="${_base_dir:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/../../ui/styles.sh"
        if [[ -f "${_ui_file}" ]]; then
            # shellcheck disable=SC1090
            source "${_ui_file}"
        fi
    fi

    local counts grouped
    counts="$(commit_summary_counts "$range" 2>/dev/null || echo "Sin commits")"
    grouped="$(commit_summary_grouped "$range" 0 2>/dev/null || echo "Sin commits")"

    if declare -F ui_card >/dev/null 2>&1; then
        ui_card "📊 ${title}" \
            "Rango: ${range}" \
            "" \
            "Resumen por tipo (conteo):" \
            "${counts}" \
            "" \
            "Resumen por tipo y scope (completo):" \
            "${grouped}"
    else
        echo
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "📊 ${title}"
        echo "Rango: ${range}"
        echo ""
        echo "Resumen por tipo (conteo):"
        echo "$counts"
        echo ""
        echo "Resumen por tipo y scope (completo):"
        echo "$grouped"
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo
    fi

    if ask_yes_no "¿Ver lista completa de commits?"; then
        echo
        if declare -F ui_separator >/dev/null 2>&1; then
            ui_separator
            echo
        fi
        commit_summary_list "$range" 0
        if declare -F ui_separator >/dev/null 2>&1; then
            echo
            ui_separator
        fi
        echo
    fi
}

# ==============================================================================
# LÓGICA DE BORRADO DE RAMA FUENTE (Implementación Tarea 3)
# ==============================================================================

promote_is_protected_branch() {
    local branch="${1:-}"
    [[ -n "${branch:-}" ]] || return 1

    local raw_patterns="${DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS:-dev|main|master|local|release/*}"
    local patterns="${raw_patterns//|/ }"
    patterns="${patterns//,/ }"

    local pattern=""
    for pattern in $patterns; do
        [[ -n "${pattern:-}" ]] || continue
        if [[ "$branch" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

promote_preflight_docker_or_die() {
    if ! command -v docker >/dev/null 2>&1 || ! docker ps >/dev/null 2>&1; then
        log_error "❌ Docker no está listo. Enciende Docker daemon/Docker Desktop o sudo systemctl start docker"
        return 2
    fi
    return 0
}

promote_preflight_argocd_or_die() {
    local argocd_app="${1:-pmbok}"

    if ! command -v argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."
        return 2
    fi

    if ! argocd account get-user-info >/dev/null 2>&1; then
        log_error "❌ ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."
        return 2
    fi

    if command -v kubectl >/dev/null 2>&1; then
        if ! kubectl cluster-info >/dev/null 2>&1; then
            log_warn "⚠️ Kubernetes/cluster no verificable desde kubectl (continuo porque el flujo usa ArgoCD CLI)."
        fi
    else
        log_warn "⚠️ kubectl no disponible. Si aplica, valida cluster con: kubectl cluster-info"
    fi

    log_info "✅ Preflight ArgoCD OK (app: ${argocd_app})."
    return 0
}

promote_ensure_tag_remote_or_die() {
    local tag="${1:-}"
    local source_sha="${2:-}"

    [[ -n "${tag:-}" ]] || { log_error "❌ Tag vacío para publish remoto."; return 2; }
    [[ -n "${source_sha:-}" ]] || { log_error "❌ SHA vacío para tag remoto."; return 2; }

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️ DRY-RUN: omito creación/push de tag remoto (${tag})."
        return 0
    fi

    if ! git show-ref --verify --quiet "refs/tags/${tag}"; then
        if ! git tag -a "$tag" "$source_sha" -m "chore(release): ${tag}"; then
            log_error "❌ No pude crear el tag local '${tag}'."
            return 2
        fi
        log_info "🏷️ Tag creado: ${tag}"
    else
        log_info "🏷️ Tag local ya existe: ${tag}"
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push origin "refs/tags/${tag}"; then
        log_error "❌ No pude pushear el tag. Ejecuta: git push origin refs/tags/${tag}"
        return 2
    fi

    log_info "🏷️ Tag pusheado: ${tag}"
    return 0
}

promote_argocd_sync_by_tag_or_die() {
    local tag="${1:-}"
    local argocd_app="${2:-pmbok}"
    local wait_timeout="${3:-${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}}"

    [[ -n "${tag:-}" ]] || { log_error "❌ Tag vacío para sync ArgoCD."; return 2; }

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️ DRY-RUN: omito ArgoCD set/sync para ${argocd_app} -> ${tag}."
        return 0
    fi

    log_info "ArgoCD: set revision ${argocd_app} -> ${tag}"
    if ! argocd app set "$argocd_app" --revision "$tag"; then
        log_error "❌ ArgoCD falló. Ejecuta: argocd app set ${argocd_app} --revision ${tag}"
        return 2
    fi

    if ! argocd app sync "$argocd_app"; then
        log_error "❌ ArgoCD falló. Ejecuta: argocd app sync ${argocd_app}"
        return 2
    fi

    if ! argocd app wait "$argocd_app" --timeout "${wait_timeout}" --health --sync; then
        log_error "❌ ArgoCD falló. Ejecuta: argocd app wait ${argocd_app} --timeout ${wait_timeout} --health --sync"
        return 2
    fi

    log_success "ArgoCD: sync ${argocd_app} OK"
    return 0
}

promote_cleanup_is_protected_branch() {
    promote_is_protected_branch "${1:-}"
}

promote_cleanup_choose_action() {
    # Args: branch has_upstream(0|1)
    local branch="$1"
    local has_upstream="${2:-0}"
    local action="delete_local"
    local prompt=""

    if [[ "$has_upstream" -eq 1 ]]; then
        action="delete_both"
        prompt="🗑️ ¿Deseas borrar la rama origen '${branch}' (local y remota)?"
    else
        prompt="🗑️ ¿Deseas borrar la rama origen '${branch}' (local)?"
    fi

    # En no-interactivo seguimos en modo seguro: solo borra si se pidió explícitamente.
    if [[ "${DEVTOOLS_ASSUME_YES:-0}" == "1" ]]; then
        if [[ "${DEVTOOLS_PROMOTE_DELETE_SOURCE_BRANCH:-0}" == "1" ]]; then
            echo "${action}"
        else
            echo "keep"
        fi
        return 0
    fi

    if declare -F ask_yes_no >/dev/null 2>&1; then
        if ask_yes_no "${prompt}"; then
            echo "${action}"
        else
            echo "keep"
        fi
        return 0
    fi

    # Fallback si no existe ask_yes_no.
    if [[ "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" || -n "${CI:-}" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "keep"
        return 0
    fi
    if [[ -r /dev/tty && -w /dev/tty ]]; then
        local ans=""
        printf "%s [Y/n]: " "${prompt}" > /dev/tty
        read -r ans < /dev/tty || true
        ans="${ans:-Y}"
        if [[ "${ans}" =~ ^[YySs]$ ]]; then
            echo "${action}"
        else
            echo "keep"
        fi
        return 0
    fi

    echo "keep"
    return 0
}

# Gestiona el borrado opcional de la rama fuente tras una promoción exitosa.
# Respeta excepciones de ramas protegidas y solo actúa sobre feature/**.
maybe_delete_source_branch() {
    local branch="$1"
    
    if [[ -z "${branch:-}" || "$branch" == "(detached)" ]]; then
        return 0
    fi

    # 1) PROTEGIDAS: nunca borrar
    if promote_cleanup_is_protected_branch "$branch"; then
        log_info "📌 Rama fuente '$branch' es protegida. Manteniéndola."
        return 0
    fi

    local upstream_short=""
    upstream_short="$(git for-each-ref --format='%(upstream:short)' "refs/heads/${branch}" | head -n 1 | tr -d '[:space:]' || true)"
    local has_upstream=0
    [[ -n "${upstream_short:-}" ]] && has_upstream=1

    # 2) INTERACCIÓN UNIVERSAL (Default: Sí, con guardrails en no-interactivo)
    echo
    log_warn "🚀 Promoción completada con éxito."
    local action=""
    action="$(promote_cleanup_choose_action "$branch" "$has_upstream")"

    if [[ "$action" == "keep" ]]; then
        log_info "📌 Manteniendo rama fuente '$branch' por elección del usuario."
        return 0
    fi

    local cur
    cur="$(git branch --show-current 2>/dev/null || echo "")"
    local deleted_local=0
    local deleted_remote=0

    log_info "🔥 Eliminando rama local: $branch"
    if [[ "$cur" == "$branch" ]]; then
        log_warn "No puedo borrar la rama local '$branch' porque está activa. (Sigue en destino y reintenta.)"
    else
        if git branch -D "$branch"; then
            deleted_local=1
        else
            log_warn "No se pudo borrar la rama local '$branch'."
        fi
    fi

    if [[ "$action" == "delete_both" ]]; then
        if [[ "$has_upstream" -eq 1 ]]; then
            local upstream_remote="${upstream_short%%/*}"
            local upstream_branch="${upstream_short#*/}"
            [[ -n "${upstream_remote:-}" && "${upstream_remote}" != "${upstream_short}" ]] || upstream_remote="origin"
            [[ -n "${upstream_branch:-}" ]] || upstream_branch="$branch"

            log_info "🔥 Eliminando rama remota: ${upstream_remote}/${upstream_branch}"
            if GIT_TERMINAL_PROMPT=0 git push "$upstream_remote" --delete "$upstream_branch"; then
                deleted_remote=1
            else
                log_warn "No se pudo borrar la rama remota ${upstream_remote}/${upstream_branch}."
            fi
        else
            log_warn "No hay upstream para '$branch'. Omitiendo borrado remoto."
        fi
    fi

    if [[ "$deleted_local" -eq 1 ]]; then
        log_info "🗑️ Rama borrada: ${branch}"
    fi
    if [[ "$deleted_remote" -eq 1 ]]; then
        log_info "🗑️ Rama remota borrada."
    fi

    log_success "🧹 Limpieza de '$branch' completada."
}

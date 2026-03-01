#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/promote/workflows/hotfix.sh
#
# Hotfix estandarizado:
# - promote_hotfix_start: entrypoint compatible con el router
# - create_hotfix: crea hotfix/<name> desde main (base canónica)
# - finish_hotfix: promueve el SHA del hotfix hacia main y dev usando:
#     update_branch_to_sha_with_strategy (ff-only | merge | merge-theirs | force)
#
# Dependencias: utils.sh, git-ops.sh (cargadas por el orquestador)

# ==============================================================================
# 6. HOTFIX WORKFLOWS (ESTÁNDAR).
# ==============================================================================

promote_hotfix_start() {
    # Uso:
    #   git promote hotfix                 -> si estás en hotfix/*: finaliza; si no: crea (pide nombre)
    #   git promote hotfix <name>          -> crea hotfix/<name>
    #   git promote hotfix finish          -> finaliza (requiere estar en hotfix/*)

    local action="${1:-}"
    local current
    current="$(git branch --show-current 2>/dev/null || echo "")"

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️  Simulacion (--dry-run) para HOTFIX"

        # Best-effort: refrescar refs
        git fetch origin main --prune >/dev/null 2>&1 || true

        local hf_branch="$current"
        if [[ "$current" != hotfix/* ]]; then
            if [[ -z "${action:-}" || "${action:-}" == "finish" ]]; then
                die "⛔ Para dry-run de hotfix debes estar en hotfix/* o indicar un nombre."
            fi
            if [[ "$action" == hotfix/* ]]; then
                hf_branch="$action"
            else
                hf_branch="hotfix/${action}"
            fi
        fi

        local hf_ref=""
        if git show-ref --verify --quiet "refs/heads/${hf_branch}"; then
            hf_ref="$hf_branch"
        elif git show-ref --verify --quiet "refs/remotes/origin/${hf_branch}"; then
            hf_ref="origin/${hf_branch}"
        else
            die "⛔ No existe la rama '${hf_branch}' (local ni origin)."
        fi

        local base_tag base_ver main_ref range bump reason commits next_ver tag motivo bump_forzado
        base_tag="$(get_last_stable_tag || true)"
        if [[ -z "${base_tag:-}" ]]; then
            base_tag="$(semver_bootstrap_tag)"
        fi
        base_ver="$(semver_normalize "$base_tag" || echo "0.0.0")"
        main_ref="$(semver_resolve_main_ref || echo "main")"
        range="${main_ref}..${hf_ref}"

        semver_analyze_range "$range" bump reason commits
        bump_forzado="patch"
        next_ver="$(semver_apply_bump "$base_ver" "$bump_forzado")"
        tag="v${next_ver}"

        case "$reason" in
            breaking) motivo="cambio incompatible" ;;
            feat) motivo="nueva funcionalidad" ;;
            fix) motivo="correccion" ;;
            otros) motivo="otros cambios" ;;
            sin_commits) motivo="sin commits" ;;
            *) motivo="$reason" ;;
        esac

        echo "Base estable   : ${base_tag}"
        echo "Main ref       : ${main_ref}"
        echo "Hotfix ref     : ${hf_ref}"
        echo "Rango          : ${range}"
        echo "Bump detectado : ${bump} (motivo: ${motivo})"
        echo "Bump forzado   : ${bump_forzado} (hotfix)"
        echo "Version final  : ${tag}"

        if [[ -n "$commits" ]]; then
            echo "Commits relevantes:"
            while IFS= read -r line; do
                echo "  - $line"
            done <<< "$commits"
        else
            echo "Commits relevantes: (ninguno)"
        fi

        # Resumen y diff (no interactivo)
        if ! declare -F commit_summary_counts >/dev/null 2>&1; then
            local _base_dir _core_file
            _base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            _core_file="${_base_dir}/../../core/commit-summary.sh"
            if [[ -f "${_core_file}" ]]; then
                # shellcheck disable=SC1090
                source "${_core_file}"
            fi
        fi
        local summary_counts summary_grouped diff_stat
        summary_counts="$(commit_summary_counts "$range" 2>/dev/null || echo "Sin commits")"
        summary_grouped="$(commit_summary_grouped "$range" 0 2>/dev/null || echo "Sin commits")"
        diff_stat="$(git diff --stat "$range" 2>/dev/null || echo "No hay diferencias disponibles")"

        echo ""
        echo "Resumen por tipo (conteo):"
        echo "$summary_counts"
        echo ""
        echo "Resumen por tipo y scope (completo):"
        echo "$summary_grouped"
        echo ""
        echo "Archivos afectados (diff --stat):"
        echo "$diff_stat"
        echo ""
        echo "Notas base (plantilla):"
        echo "- Funciones:"
        echo "- Correcciones:"
        echo "- Mantenimiento:"
        echo "- Otros:"
        echo ""

        echo "Acciones (si no es dry-run):"
        echo "  - Promover hotfix -> main con estrategia"
        echo "  - Backport hotfix -> dev con estrategia"
        echo "  - Confirmar en origin con git ls-remote"

        return 0
    fi

    # Best-effort: resync submodules si existe el helper (common.sh)
    if declare -F resync_submodules_hard >/dev/null 2>&1; then
        resync_submodules_hard
    fi

    if [[ "$action" == "finish" ]]; then
        finish_hotfix
        return $?
    fi

    if [[ "$current" == hotfix/* ]]; then
        finish_hotfix
        return $?
    fi

    # Si viene nombre, crear con ese nombre. Si no, crear pidiendo nombre.
    create_hotfix "${action:-}"
}

create_hotfix() {
    local hf_name="${1:-}"

    # Evitar sorpresas en no-tty
    if [[ -z "${hf_name:-}" ]]; then
        if declare -F can_prompt >/dev/null 2>&1 && can_prompt; then
            printf "Nombre del hotfix: " > /dev/tty
            read -r hf_name < /dev/tty
        else
            die "⛔ No hay TTY/UI. Usa: git promote hotfix <nombre>"
        fi
    fi

    hf_name="$(echo "${hf_name:-}" | tr -d '[:space:]')"
    [[ -n "${hf_name:-}" ]] || die "⛔ Nombre de hotfix vacío."

    local hf_branch="hotfix/${hf_name}"

    ensure_clean_git

    # Base canónica: main desde origin
    ensure_local_tracking_branch "main" "origin" || die "No pude preparar 'main' desde 'origin/main'."
    update_branch_from_remote "main"

    # Crear rama hotfix desde main actualizado
    git checkout -b "$hf_branch" >/dev/null 2>&1 || die "No pude crear la rama ${hf_branch}."

    # Aterrizaje final: quedarnos en el hotfix tras crear
    export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="$hf_branch"

    log_success "✅ Rama hotfix creada: $hf_branch (base: main)"
    log_info "👉 Haz tus commits y luego ejecuta: git promote hotfix"
}

finish_hotfix() {
    local current
    current="$(git branch --show-current 2>/dev/null || echo "")"
    [[ "$current" == hotfix/* ]] || die "⛔ No estás en una rama hotfix/*."

    ensure_clean_git

    if ! can_prompt; then
        die "⛔ Este flujo requiere modo interactivo (TTY) para la UI de hotfix."
    fi

    if [[ -f "${PROMOTE_LIB}/helpers/gh-interactions.sh" ]]; then
        # shellcheck disable=SC1090
        source "${PROMOTE_LIB}/helpers/gh-interactions.sh"
    fi

    local hotfix_sha
    hotfix_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    [[ -n "${hotfix_sha:-}" ]] || die "No pude resolver SHA del hotfix."

    echo
    banner "🩹 FINALIZANDO HOTFIX (Estandarizado)"
    log_info "Fuente : ${current} @${hotfix_sha:0:7}"
    log_info "Targets: main + staging + dev"
    echo

    # Estrategia (Menú Universal): debería venir del bin, pero mantenemos fallback seguro.
    local strategy="${DEVTOOLS_PROMOTE_STRATEGY:-}"
    if [[ -z "${strategy:-}" ]]; then
        strategy="$(promote_choose_strategy_or_die)"
        export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
    fi

    # Pre-check: refrescar refs para reconciliación
    git fetch origin main staging dev --prune >/dev/null 2>&1 || true

    local main_ref staging_ref dev_ref range
    main_ref="$(semver_resolve_main_ref || echo "main")"
    if ! git rev-parse "$main_ref" >/dev/null 2>&1; then
        if git show-ref --verify --quiet "refs/remotes/origin/main"; then
            main_ref="origin/main"
        elif git show-ref --verify --quiet "refs/heads/main"; then
            main_ref="main"
        else
            die "No pude resolver ref de main para reconciliación."
        fi
    fi

    staging_ref="origin/staging"
    if ! git show-ref --verify --quiet "refs/remotes/origin/staging"; then
        if git show-ref --verify --quiet "refs/heads/staging"; then
            staging_ref="staging"
        else
            die "No pude resolver ref de staging para reconciliación."
        fi
    fi

    dev_ref="origin/dev"
    if ! git show-ref --verify --quiet "refs/remotes/origin/dev"; then
        if git show-ref --verify --quiet "refs/heads/dev"; then
            dev_ref="dev"
        else
            die "No pude resolver ref de dev para reconciliación."
        fi
    fi

    local main_sha staging_sha dev_sha
    main_sha="$(git rev-parse "$main_ref" 2>/dev/null || true)"
    staging_sha="$(git rev-parse "$staging_ref" 2>/dev/null || true)"
    dev_sha="$(git rev-parse "$dev_ref" 2>/dev/null || true)"
    [[ -n "${main_sha:-}" ]] || die "No pude resolver SHA de main."
    [[ -n "${staging_sha:-}" ]] || die "No pude resolver SHA de staging."
    [[ -n "${dev_sha:-}" ]] || die "No pude resolver SHA de dev."

    range="${main_ref}..${current}"
    render_commit_diff_panel "Comparación MAIN vs HOTFIX" "$range"

    # Pre-check de reconciliación (main -> staging -> dev)
    if declare -F remote_health_check >/dev/null 2>&1; then
        remote_health_check "main" "origin" || die "No hay acceso a origin/main."
        remote_health_check "staging" "origin" || die "No hay acceso a origin/staging."
        remote_health_check "dev" "origin" || die "No hay acceso a origin/dev."
    fi

    log_info "🔎 Pre-check reconciliación:"
    log_info "   main   : ${main_ref} @${main_sha:0:7}"
    log_info "   staging: ${staging_ref} @${staging_sha:0:7}"
    log_info "   dev    : ${dev_ref} @${dev_sha:0:7}"

    if declare -F __git_is_ancestor >/dev/null 2>&1; then
        local needs_confirm=0

        if ! __git_is_ancestor "$main_sha" "$hotfix_sha"; then
            log_warn "El hotfix no parte de main (main no es ancestro del hotfix)."
            needs_confirm=1
        fi

        if __git_is_ancestor "$hotfix_sha" "$main_sha"; then
            log_warn "main ya contiene el hotfix o está por delante del hotfix."
        fi

        if ! __git_is_ancestor "$staging_sha" "$main_sha"; then
            log_warn "staging tiene commits fuera de main; Fast-Forward no es posible."
            needs_confirm=1
        elif [[ "$staging_sha" != "$main_sha" ]]; then
            log_info "staging está detrás de main (Fast-Forward posible)."
        fi

        if ! __git_is_ancestor "$dev_sha" "$staging_sha"; then
            log_warn "dev tiene commits fuera de staging; Fast-Forward no es posible."
            needs_confirm=1
        elif [[ "$dev_sha" != "$staging_sha" ]]; then
            log_info "dev está detrás de staging (Fast-Forward posible)."
        fi

        if [[ "$needs_confirm" -eq 1 ]]; then
            if ! ask_yes_no "Se detectaron divergencias en la reconciliación. ¿Continuar?"; then
                die "Abortado por el usuario."
            fi
        fi
    else
        log_warn "No se encontró __git_is_ancestor; omitiendo pre-check de divergencias."
    fi

    local repo_root promote_tag_file final_tag
    repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    promote_tag_file="${repo_root}/.promote_tag"
    [[ -f "$promote_tag_file" ]] || die "Falta .promote_tag. Ejecuta primero git promote dev."
    final_tag="$(promote_tag_read_cache "$promote_tag_file" 2>/dev/null || true)"
    if [[ -z "${final_tag:-}" ]]; then
        log_warn ".promote_tag está vacío o desfasado. Recalculando tag desde tags."
        final_tag="$(promote_next_tag_hotfix)"
    fi
    [[ -n "${final_tag:-}" ]] || die "No pude resolver tag para hotfix."
    if [[ -z "${TAG_PREFIX:-}" && -z "${APP:-}" ]]; then
        if [[ "$final_tag" =~ ^([A-Za-z0-9._-]+)-v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            export TAG_PREFIX="${BASH_REMATCH[1]}"
        fi
    fi

    local final_ver final_rc final_build
    if ! semver_parse_tag "$final_tag" final_ver final_rc final_build; then
        die "El tag en .promote_tag no es estable valido (esperado [APP]-vX.Y.Z)."
    fi
    if [[ -n "${final_rc:-}" || -n "${final_build:-}" ]]; then
        die "El tag en .promote_tag no es estable valido (esperado [APP]-vX.Y.Z)."
    fi
    log_info "🏷️ Tag leído desde .promote_tag: ${final_tag}"

    echo
    generate_ai_prompt "${current}" "${main_ref}"

    local notes_dir notes_file tmp_file
    notes_dir="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.devtools/releases"
    mkdir -p "$notes_dir"
    notes_file="${notes_dir}/hotfix.md"
    tmp_file="$(mktemp)"
    capture_release_notes "$tmp_file"
    prepend_release_notes_header "$tmp_file" "## ${final_tag}"
    mv "$tmp_file" "$notes_file"
    log_info "📝 Notas guardadas en: ${notes_file}"

    if ! ask_yes_no "¿Confirmas promover hotfix con version ${final_tag}?"; then
        die "Abortado por el usuario."
    fi

    if ! declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        die "No se encontró gate_required_workflows_on_sha_or_die (faltó source de workflows/checks.sh)."
    fi
    gate_required_workflows_on_sha_or_die "$hotfix_sha" "$current" \
        || die "Gate por SHA falló para hotfix (${hotfix_sha:0:7}). Abortando finalización."

    # 1) MAIN
    log_info "1/3 🚀 Actualizando 'main' desde hotfix..."
    local main_sha="" rc=0
    while true; do
        main_sha="$(update_branch_to_sha_with_strategy "main" "$hotfix_sha" "origin" "$strategy")"
        rc=$?
        if [[ "$rc" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward NO es posible en main. Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc" -eq 0 ]] || die "No pude actualizar 'main' (strategy=${strategy}, rc=${rc})."
        break
    done
    log_success "✅ MAIN OK: origin/main @${main_sha:0:7}"

    # 2) STAGING (sync)
    log_info "2/3 🚀 Sync a 'staging' desde main..."
    local staging_sha="" rc2=0
    while true; do
        staging_sha="$(update_branch_to_sha_with_strategy "staging" "$main_sha" "origin" "$strategy")"
        rc2=$?
        if [[ "$rc2" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward NO es posible en staging. Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc2" -eq 0 ]] || die "No pude actualizar 'staging' (strategy=${strategy}, rc=${rc2})."
        break
    done
    log_success "✅ STAGING OK: origin/staging @${staging_sha:0:7}"

    # 3) DEV (sync)
    log_info "3/3 🚀 Sync a 'dev' desde staging..."
    local dev_sha="" rc3=0
    while true; do
        dev_sha="$(update_branch_to_sha_with_strategy "dev" "$staging_sha" "origin" "$strategy")"
        rc3=$?
        if [[ "$rc3" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward NO es posible en dev. Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc3" -eq 0 ]] || die "No pude actualizar 'dev' (strategy=${strategy}, rc=${rc3})."
        break
    done
    log_success "✅ DEV OK: origin/dev @${dev_sha:0:7}"

    echo
    log_info "🔎 Confirmación visual:"
    log_info "   git ls-remote --heads origin main"
    git ls-remote --heads origin main 2>/dev/null || true
    log_info "   git ls-remote --heads origin staging"
    git ls-remote --heads origin staging 2>/dev/null || true
    log_info "   git ls-remote --heads origin dev"
    git ls-remote --heads origin dev 2>/dev/null || true
    echo

    if declare -F gh_create_release_draft_from_tag >/dev/null 2>&1; then
        gh_create_release_draft_from_tag "$final_tag" "$notes_file" "$main_sha" "origin"
    elif declare -F gh_create_release_from_tag >/dev/null 2>&1; then
        gh_create_release_from_tag "$final_tag" "$notes_file" "$main_sha" "origin"
    else
        log_warn "No se encontró helper de release final; omitiendo publicación."
    fi

    # Aterrizaje final: quedarnos en main (por ser “producción” del hotfix)
    export DEVTOOLS_LAND_ON_SUCCESS_BRANCH="main"

    log_success "✅ Hotfix integrado (estándar): ${current} -> main + staging + dev (strategy=${strategy})"
    return 0
}

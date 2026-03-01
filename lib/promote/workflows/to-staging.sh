#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/promote/workflows/to-staging.sh
#
# CONTRATO: STAGING CERO FRICCIÓN (default)
# Objetivo: Menú (estrategia) → Push → Confirmación (git ls-remote) → Landing (quedar en staging).
# Incluye UI interactiva (TTY) para version RC y notas de lanzamiento.
# Comparación: se muestra panel solo en modo interactivo (TTY).
# (Este archivo debe mantenerse corto y predecible.)

promote_to_staging() {
    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️  Simulacion (--dry-run) para STAGING"

        # Best-effort: refrescar refs
        git fetch origin dev staging --prune >/dev/null 2>&1 || true

        local range tag last_tag
        range="staging..dev"
        last_tag="$(promote_last_tag_or_empty 2>/dev/null || true)"
        tag="$(promote_next_tag_staging "$range")"

        if [[ -n "${last_tag:-}" ]]; then
            echo "Tag previo   : ${last_tag}"
        else
            echo "Tag previo   : (no encontrado)"
        fi
        echo "Rango        : ${range}"
        echo "Bump         : (calculado por estrategia)"
        echo "Version RC   : ${tag}"

        if [[ -n "${commits:-}" ]]; then
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
        echo "  - Actualizar refs de dev y staging"
        echo "  - Promover dev -> staging con estrategia"
        echo "  - Confirmar en origin con git ls-remote"

        exit 0
    fi

    resync_submodules_hard
    ensure_clean_git

    if [[ -f "${PROMOTE_LIB}/helpers/gh-interactions.sh" ]]; then
        # shellcheck disable=SC1090
        source "${PROMOTE_LIB}/helpers/gh-interactions.sh"
    fi

    # Siempre trabajamos sobre un dev actualizado desde origin (HEAD real)
    ensure_local_tracking_branch "dev" "origin" || { log_error "No pude preparar la rama 'dev' desde 'origin/dev'."; exit 1; }
    if [[ "$(git branch --show-current)" != "dev" ]]; then
        log_warn "No estás en 'dev'. Cambiando..."
        git checkout dev >/dev/null 2>&1 || exit 1
    fi
    update_branch_from_remote "dev"

    local dev_sha
    dev_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    [[ -n "${dev_sha:-}" ]] || { log_error "No pude resolver DEV HEAD."; exit 1; }
    log_info "✅ DEV HEAD: ${dev_sha:0:7}"

    if ! can_prompt; then
        die "⛔ Este flujo requiere modo interactivo (TTY) para la UI de staging."
    fi

    local base_ref="origin/staging"
    if ! git show-ref --verify --quiet "refs/remotes/origin/staging"; then
        if git show-ref --verify --quiet "refs/heads/staging"; then
            base_ref="staging"
        else
            base_ref=""
        fi
    fi
    local compare_ref range
    compare_ref="${base_ref:-staging}"
    if [[ -n "${base_ref:-}" ]]; then
        range="${base_ref}..dev"
        render_commit_diff_panel "Comparación STAGING vs DEV" "$range"
    else
        range="dev"
        log_warn "No pude resolver ref de staging para mostrar comparación."
    fi

    local promote_tag_file cached_tag final_tag
    promote_tag_file="$(promote_tag_file_path)"
    if [[ -f "$promote_tag_file" ]]; then
        cached_tag="$(promote_tag_read_cache "$promote_tag_file" 2>/dev/null || true)"
        if [[ -n "${cached_tag:-}" ]]; then
            log_info "🏷️ Tag en .promote_tag (cache): ${cached_tag}"
        else
            log_warn ".promote_tag está vacío o desfasado. Se recalculará el tag."
        fi
    else
        log_info "No se encontró .promote_tag. Se calculará el tag desde tags."
    fi

    if [[ -n "${cached_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$cached_tag"
    fi

    final_tag="$(promote_next_tag_staging "$range")"

    if declare -F can_prompt >/dev/null 2>&1 && can_prompt; then
        local input_tag
        if have_gum_ui; then
            input_tag="$(gum input --value "$final_tag" --header "Version RC (sin build, Enter acepta sugerida)")"
        else
            printf "Version RC (sin build) [%s]: " "$final_tag" > /dev/tty
            read -r input_tag < /dev/tty
        fi
        input_tag="${input_tag:-$final_tag}"
        final_tag="$input_tag"
    fi

    if [[ -z "${TAG_PREFIX:-}" && -z "${APP:-}" ]]; then
        if [[ "$final_tag" =~ ^([A-Za-z0-9._-]+)-v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            export TAG_PREFIX="${BASH_REMATCH[1]}"
        fi
    fi

    local final_ver final_rc final_build
    if ! semver_parse_tag "$final_tag" final_ver final_rc final_build; then
        die "El tag no es RC valido (esperado [APP]-vX.Y.Z-rc.N)."
    fi
    if [[ -z "${final_rc:-}" || -n "${final_build:-}" ]]; then
        die "El tag de staging no debe incluir build (esperado [APP]-vX.Y.Z-rc.N)."
    fi

    local tag_owner="Local"
    if declare -F promote_resolve_tag_owner_for_env >/dev/null 2>&1; then
        if promote_resolve_tag_owner_for_env "staging"; then
            tag_owner="${PROMOTE_TAG_OWNER:-Local}"
        fi
    fi
    if declare -F promote_log_tag_owner_for_env >/dev/null 2>&1; then
        promote_log_tag_owner_for_env "staging"
    else
        local tag_owner_reason="${PROMOTE_TAG_OWNER_REASON:-workflow}"
        log_info "Owner tags = ${tag_owner} | Razón = ${tag_owner_reason}"
    fi

    local promote_tag_file
    promote_tag_file="$(promote_tag_file_path)"
    if ! promote_tag_write_cache "$final_tag" "$final_ver" "$final_rc" "" "staging" "to-staging" "$promote_tag_file"; then
        die "No pude escribir .promote_tag."
    fi
    log_info "🏷️ Tag actualizado en: ${promote_tag_file}"

    echo
    generate_ai_prompt "dev" "$compare_ref"

    local notes_dir notes_file tmp_file
    notes_dir="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.devtools/releases"
    mkdir -p "$notes_dir"
    notes_file="${notes_dir}/staging.md"
    tmp_file="$(mktemp)"
    capture_release_notes "$tmp_file"
    prepend_release_notes_header "$tmp_file" "## ${final_tag}"
    mv "$tmp_file" "$notes_file"
    log_info "📝 Notas guardadas en: ${notes_file}"

    if ! ask_yes_no "¿Confirmas promover a staging con version ${final_tag}?"; then
        die "Abortado por el usuario."
    fi

    local staging_overlay_file="devops/k8s/overlays/staging/kustomization.yaml"
    local repo_root_for_overlay_check="${DEVTOOLS_DISPATCH_REPO_ROOT:-${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
    if [[ "${repo_root_for_overlay_check}" != "/webapps/ihh-devtools" && "${repo_root_for_overlay_check}" != "/webapps/ihh-ecosystem" ]]; then
        [[ -f "${staging_overlay_file}" ]] || die "No existe overlay de staging: ${staging_overlay_file}"
        local staging_unqualified_images=""
        local staging_line_no=0
        while IFS= read -r line; do
            staging_line_no=$((staging_line_no + 1))
            [[ "$line" =~ ^[[:space:]]*newName:[[:space:]]*([^[:space:]#]+) ]] || continue
            local image_name="${BASH_REMATCH[1]}"
            image_name="${image_name%\"}"
            image_name="${image_name#\"}"
            image_name="${image_name%\'}"
            image_name="${image_name#\'}"
            local first_segment="$image_name"
            if [[ "$image_name" == */* ]]; then
                first_segment="${image_name%%/*}"
            fi
            if [[ "$first_segment" != *.* && "$first_segment" != *:* ]]; then
                staging_unqualified_images+="${image_name}@L${staging_line_no} "
            fi
        done < "${staging_overlay_file}"
        [[ -z "${staging_unqualified_images:-}" ]] \
            || die "Policy registry (staging): imágenes sin registry en ${staging_overlay_file}: ${staging_unqualified_images}"
    fi

    if ! declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        die "No se encontró gate_required_workflows_on_sha_or_die (faltó source de workflows/checks.sh)."
    fi
    gate_required_workflows_on_sha_or_die "$dev_sha" "dev" \
        || die "Gate por SHA falló para dev (${dev_sha:0:7}). Abortando promote a staging."

    local strategy="${DEVTOOLS_PROMOTE_STRATEGY:-ff-only}"
    local staging_sha="" rc=0
    while true; do
        staging_sha="$(update_branch_to_sha_with_strategy "staging" "$dev_sha" "origin" "$strategy")"
        rc=$?
        if [[ "$rc" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward no es posible (hay divergencia en staging). Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc" -eq 0 ]] || { log_error "No pude actualizar 'staging' con estrategia ${strategy} (rc=${rc})."; exit 1; }
        break
    done

    log_success "✅ Staging actualizado. SHA final: ${staging_sha:0:7}"
    echo
    log_info "🔎 Confirmación visual (git ls-remote --heads origin staging):"
    git ls-remote --heads origin staging 2>/dev/null || true
    echo

    if [[ "$tag_owner" == "Local" ]]; then
        if declare -F gh_create_prerelease_draft_from_tag >/dev/null 2>&1; then
            gh_create_prerelease_draft_from_tag "$final_tag" "$notes_file" "$staging_sha" "origin"
        elif declare -F gh_create_prerelease_from_tag >/dev/null 2>&1; then
            gh_create_prerelease_from_tag "$final_tag" "$notes_file" "$staging_sha" "origin"
        else
            log_warn "No se encontró helper de pre-release; omitiendo publicación."
        fi
    else
        log_info "Se omite creación/push local de tag en staging (owner GitHub)."
    fi

    exit 0
}

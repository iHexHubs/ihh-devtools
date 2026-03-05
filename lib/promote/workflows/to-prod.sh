#!/usr/bin/env bash
# Promote workflow: to-prod
# CONTRATO: PROD CERO FRICCIÓN (default)
# Objetivo: Menú (estrategia) → Push → Confirmación (git ls-remote) → Landing.
# Incluye UI interactiva (TTY) para version final y notas de lanzamiento.
# Comparación: se muestra panel solo en modo interactivo (TTY).

promote_to_prod() {
    local dot_dir=".devtools"
    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "⚗️  Simulacion (--dry-run) para PRODUCCION"

        # Best-effort: refrescar refs
        GIT_TERMINAL_PROMPT=0 git fetch origin main staging --prune >/dev/null 2>&1 || true

        local range tag last_tag
        local reason="" commits="" motivo=""
        range="main..staging"
        last_tag="$(promote_last_tag_or_empty 2>/dev/null || true)"
        tag="$(promote_next_tag_prod)"

        case "$reason" in
            breaking) motivo="cambio incompatible" ;;
            feat) motivo="nueva funcionalidad" ;;
            fix) motivo="correccion" ;;
            otros) motivo="otros cambios" ;;
            sin_commits) motivo="sin commits" ;;
            *) motivo="$reason" ;;
        esac

        if [[ -n "${last_tag:-}" ]]; then
            echo "Tag previo   : ${last_tag}"
        else
            echo "Tag previo   : (no encontrado)"
        fi
        echo "Rango        : ${range}"
        echo "Bump         : (calculado por estrategia)"
        echo "Version final: ${tag}"

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
        echo "  - Actualizar refs de staging y main"
        echo "  - Promover staging -> main con estrategia"
        echo "  - Confirmar en origin con git ls-remote"

        exit 0
    fi

    resync_submodules_hard
    ensure_clean_git

    if [[ -f "${PROMOTE_LIB}/helpers/gh-interactions.sh" ]]; then
        # shellcheck disable=SC1090
        source "${PROMOTE_LIB}/helpers/gh-interactions.sh"
    fi

    # Siempre trabajamos sobre un staging actualizado desde origin (HEAD real)
    ensure_local_tracking_branch "staging" "origin" || { log_error "No pude preparar la rama 'staging' desde 'origin/staging'."; exit 1; }
    if [[ "$(git branch --show-current)" != "staging" ]]; then
        log_warn "No estás en 'staging'. Cambiando..."
        git checkout staging >/dev/null 2>&1 || exit 1
    fi
    update_branch_from_remote "staging"

    local staging_sha
    staging_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    [[ -n "${staging_sha:-}" ]] || { log_error "No pude resolver STAGING HEAD."; exit 1; }
    log_info "✅ STAGING HEAD: ${staging_sha:0:7}"

    if ! can_prompt; then
        die "⛔ Este flujo requiere modo interactivo (TTY) para la UI de produccion."
    fi

    local base_ref="origin/main"
    if ! git show-ref --verify --quiet "refs/remotes/origin/main"; then
        if git show-ref --verify --quiet "refs/heads/main"; then
            base_ref="main"
        else
            base_ref=""
        fi
    fi
    local compare_ref range
    compare_ref="${base_ref:-main}"
    if [[ -n "${base_ref:-}" ]]; then
        range="${base_ref}..staging"
        render_commit_diff_panel "Comparación MAIN vs STAGING" "$range"
    else
        range="staging"
        log_warn "No pude resolver ref de main para mostrar comparación."
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

    final_tag="$(promote_next_tag_prod)"

    if declare -F can_prompt >/dev/null 2>&1 && can_prompt; then
        local input_tag
        if have_gum_ui; then
            input_tag="$(gum input --value "$final_tag" --header "Version final (Enter acepta sugerida)")"
        else
            printf "Version final [%s]: " "$final_tag" > /dev/tty
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
        die "El tag no es estable valido (esperado [APP]-vX.Y.Z)."
    fi
    if [[ -n "${final_rc:-}" || -n "${final_build:-}" ]]; then
        die "El tag no es estable valido (esperado [APP]-vX.Y.Z)."
    fi

    local tag_owner="Local"
    if declare -F promote_resolve_tag_owner_for_env >/dev/null 2>&1; then
        if promote_resolve_tag_owner_for_env "prod"; then
            tag_owner="${PROMOTE_TAG_OWNER:-Local}"
        fi
    fi
    if declare -F promote_log_tag_owner_for_env >/dev/null 2>&1; then
        promote_log_tag_owner_for_env "prod"
    else
        local tag_owner_reason="${PROMOTE_TAG_OWNER_REASON:-workflow}"
        log_info "Owner tags = ${tag_owner} | Razón = ${tag_owner_reason}"
    fi

    if ! promote_tag_write_cache "$final_tag" "$final_ver" "" "" "prod" "to-prod" "$promote_tag_file"; then
        die "No pude escribir .promote_tag."
    fi
    log_info "🏷️ Tag actualizado en: ${promote_tag_file}"

    echo
    generate_ai_prompt "staging" "$compare_ref"

    local notes_dir notes_file tmp_file
    notes_dir="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/${dot_dir}/releases"
    mkdir -p "$notes_dir"
    notes_file="${notes_dir}/prod.md"
    tmp_file="$(mktemp)"
    capture_release_notes "$tmp_file"
    prepend_release_notes_header "$tmp_file" "## ${final_tag}"
    mv "$tmp_file" "$notes_file"
    log_info "📝 Notas guardadas en: ${notes_file}"

    if ! ask_yes_no "¿Confirmas promover a produccion con version ${final_tag}?"; then
        die "Abortado por el usuario."
    fi

    local main_overlay_file="devops/k8s/overlays/main/kustomization.yaml"
    if [[ -f "${main_overlay_file}" ]]; then
        local main_unqualified_images=""
        local main_line_no=0
        while IFS= read -r line; do
            main_line_no=$((main_line_no + 1))
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
                main_unqualified_images+="${image_name}@L${main_line_no} "
            fi
        done < "${main_overlay_file}"
        [[ -z "${main_unqualified_images:-}" ]] \
            || die "Policy registry (prod): imágenes sin registry en ${main_overlay_file}: ${main_unqualified_images}"
    else
        log_warn "No existe overlay de main en este repo. Omitiendo validación de registry para prod."
    fi

    if ! declare -F gate_required_workflows_on_sha_or_die >/dev/null 2>&1; then
        die "No se encontró gate_required_workflows_on_sha_or_die (faltó source de workflows/checks.sh)."
    fi
    gate_required_workflows_on_sha_or_die "$staging_sha" "staging" \
        || die "Gate por SHA falló para staging (${staging_sha:0:7}). Abortando promote a prod."

    local strategy="${DEVTOOLS_PROMOTE_STRATEGY:-ff-only}"
    local main_sha="" rc=0
    while true; do
        main_sha="$(update_branch_to_sha_with_strategy "main" "$staging_sha" "origin" "$strategy")"
        rc=$?
        if [[ "$rc" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward no es posible (hay divergencia en main). Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi
        [[ "$rc" -eq 0 ]] || { log_error "No pude actualizar 'main' con estrategia ${strategy} (rc=${rc})."; exit 1; }
        break
    done

    log_success "✅ Producción actualizada. SHA final: ${main_sha:0:7}"
    echo
    log_info "🔎 Confirmación visual (git ls-remote --heads origin main):"
    GIT_TERMINAL_PROMPT=0 git ls-remote --heads origin main 2>/dev/null || true
    echo

    if [[ "$tag_owner" == "Local" ]]; then
        if declare -F gh_create_release_draft_from_tag >/dev/null 2>&1; then
            gh_create_release_draft_from_tag "$final_tag" "$notes_file" "$main_sha" "origin"
        elif declare -F gh_create_release_from_tag >/dev/null 2>&1; then
            gh_create_release_from_tag "$final_tag" "$notes_file" "$main_sha" "origin"
        else
            log_warn "No se encontró helper de release final; omitiendo publicación."
        fi
    else
        log_info "Se omite creación/push local de tag en prod (owner GitHub)."
    fi

    exit 0
}

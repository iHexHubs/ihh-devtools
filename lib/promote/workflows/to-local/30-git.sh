#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_resolve_tag_owner() {
    local owner="Local"
    local reason="workflow"
    local root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local wf_dir="${root}/.github/workflows"

    if [[ "${DEVTOOLS_FORCE_LOCAL_TAGS:-0}" == "1" ]]; then
        owner="Local"
        reason="override:DEVTOOLS_FORCE_LOCAL_TAGS"
    elif [[ "${DEVTOOLS_DISABLE_GH_TAGGER:-0}" == "1" ]]; then
        owner="Local"
        reason="override:DEVTOOLS_DISABLE_GH_TAGGER"
    elif [[ -f "${wf_dir}/tag-rc-on-staging.yaml" || -f "${wf_dir}/tag-rc-on-staging.yml" \
        || -f "${wf_dir}/tag-final-on-main.yaml" || -f "${wf_dir}/tag-final-on-main.yml" ]]; then
        owner="GitHub"
    fi

    PROMOTE_TAG_OWNER="$owner"
    PROMOTE_TAG_OWNER_REASON="$reason"
    return 0
}



promote_local_resolve_tag_target_sha() {
    local source_sha="$1"
    local local_sha=""
    local_sha="$(git rev-parse local 2>/dev/null || true)"
    if [[ -n "${local_sha:-}" ]]; then
        echo "$local_sha"
        return 0
    fi

    if [[ -z "${source_sha:-}" ]]; then
        if declare -F die >/dev/null 2>&1; then
            die "No pude resolver SHA destino para el tag local (source_sha vacío)."
        fi
        echo "No pude resolver SHA destino para el tag local (source_sha vacío)." >&2
        return 1
    fi
    echo "$source_sha"
    return 0
}



promote_local_verify_tag_points_to_overlay_or_die() {
    local tag="$1"
    local expected_sha="$2"
    local overlay_file="$3"
    local expected_overlay_tag="$4"

    [[ -n "${tag:-}" ]] || die "Verificación de tag inválida: tag vacío."
    [[ -n "${expected_sha:-}" ]] || die "Verificación de tag inválida: expected_sha vacío."
    [[ -n "${overlay_file:-}" ]] || die "Verificación de tag inválida: overlay_file vacío."
    [[ -n "${expected_overlay_tag:-}" ]] || die "Verificación de tag inválida: expected_overlay_tag vacío."

    local tag_sha=""
    tag_sha="$(git rev-list -n 1 "${tag}" 2>/dev/null || true)"
    [[ -n "${tag_sha:-}" ]] || die "No pude resolver SHA del tag ${tag}."
    [[ "${tag_sha}" == "${expected_sha}" ]] \
        || die "Anti-regresión: tag ${tag} apunta a ${tag_sha:0:7}, esperado ${expected_sha:0:7} (HEAD local)."

    local overlay_content=""
    overlay_content="$(git show "${tag}:${overlay_file}" 2>/dev/null || true)"
    [[ -n "${overlay_content:-}" ]] \
        || die "Anti-regresión: no pude leer ${overlay_file} dentro del tag ${tag}."

    local overlay_tag_in_tag=""
    overlay_tag_in_tag="$(printf '%s\n' "${overlay_content}" | promote_local_read_overlay_tag_from_text 2>/dev/null || true)"
    [[ -n "${overlay_tag_in_tag:-}" ]] \
        || die "Anti-regresión: no encontré newTag en ${overlay_file} dentro del tag ${tag}."
    [[ "${overlay_tag_in_tag}" == "${expected_overlay_tag}" ]] \
        || die "Anti-regresión: newTag en ${tag}:${overlay_file}='${overlay_tag_in_tag}', esperado '${expected_overlay_tag}'."

    log_info "✅ Anti-regresión tag/overlay OK: ${tag} -> ${expected_sha:0:7}, newTag=${overlay_tag_in_tag}"
}



promote_local_is_protected_branch() {
    local branch="${1:-}"
    if declare -F promote_is_protected_branch >/dev/null 2>&1; then
        promote_is_protected_branch "$branch"
        return $?
    fi

    case "$branch" in
        dev|main|master|local|release/*) return 0 ;;
        *) return 1 ;;
    esac
}



promote_local_cleanup_stale_worktrees_for_branch() {
    local branch="${1:-local}"
    local repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local wt_path=""
    local wt_branch=""
    local removed=0

    while IFS= read -r line; do
        case "${line}" in
            worktree\ *)
                wt_path="${line#worktree }"
                ;;
            branch\ *)
                wt_branch="${line#branch }"
                if [[ -n "${wt_path:-}" && "${wt_path}" != "${repo_root}" ]]; then
                    case "${wt_path}" in
                        /tmp/eco-promote-validate*|/tmp/eco-validate-*|/tmp/ihh-promote-validate*|/tmp/ihh-validate-*)
                            log_warn "🧹 Cleanup stale worktree temporal: ${wt_path} (${wt_branch:-sin-branch})"
                            git worktree remove --force "${wt_path}" >/dev/null 2>&1 || true
                            rm -rf "${wt_path}" >/dev/null 2>&1 || true
                            removed=1
                            ;;
                        *)
                            if [[ "${wt_branch}" == "refs/heads/${branch}" ]]; then
                                log_warn "⚠️ Rama '${branch}' está ocupada por worktree externo (${wt_path}). Continuaré con fallback sin checkout."
                            fi
                            ;;
                    esac
                fi
                ;;
        esac
    done < <(git worktree list --porcelain 2>/dev/null || true)

    if [[ "${removed}" == "1" ]]; then
        git worktree prune >/dev/null 2>&1 || true
    fi
    return 0
}



promote_local_checkout_branch_best_effort() {
    local branch="${1:-local}"
    if git checkout "${branch}" >/dev/null 2>&1; then
        return 0
    fi
    promote_local_cleanup_stale_worktrees_for_branch "${branch}"
    git checkout "${branch}" >/dev/null 2>&1
}



promote_local_apply_strategy_to_local_or_die() {
    local source_sha="${1:-}"
    local local_branch="${2:-local}"
    local strategy="${DEVTOOLS_PROMOTE_STRATEGY:-ff-only}"
    local rc=0
    local final_sha=""
    local used_ref_fallback=0

    [[ -n "${source_sha:-}" ]] || die "No pude aplicar estrategia a local: source_sha vacío."
    command -v git >/dev/null 2>&1 || die "No se encontró git para aplicar estrategia local."

    while true; do
        rc=0
        used_ref_fallback=0
        promote_local_cleanup_stale_worktrees_for_branch "$local_branch"

        # PREPARE puro: alinear rama local con origin/local sin hacer push.
        if branch_exists_remote "$local_branch" "origin"; then
            ensure_local_branch_tracks_remote "$local_branch" "origin" || die "No pude preparar '${local_branch}' desde origin/${local_branch}."
            if ! git checkout "$local_branch" >/dev/null 2>&1; then
                used_ref_fallback=1
                log_warn "⚠️ No pude cambiar a '${local_branch}'. Uso fallback sin checkout."
            fi
            git fetch origin "$local_branch" >/dev/null 2>&1 || true
            if [[ "$used_ref_fallback" -eq 0 ]]; then
                git reset --hard "origin/${local_branch}" >/dev/null 2>&1 || true
            else
                local remote_sha=""
                remote_sha="$(git rev-parse "refs/remotes/origin/${local_branch}" 2>/dev/null || true)"
                if [[ -n "${remote_sha:-}" ]]; then
                    git update-ref "refs/heads/${local_branch}" "$remote_sha" >/dev/null 2>&1 || true
                fi
            fi
        else
            if git show-ref --verify --quiet "refs/heads/${local_branch}"; then
                if ! git checkout "$local_branch" >/dev/null 2>&1; then
                    used_ref_fallback=1
                    log_warn "⚠️ No pude cambiar a '${local_branch}'. Uso fallback sin checkout."
                fi
            elif git show-ref --verify --quiet "refs/heads/dev"; then
                if ! git checkout -b "$local_branch" dev >/dev/null 2>&1; then
                    used_ref_fallback=1
                    log_warn "⚠️ No pude crear '${local_branch}' desde dev por checkout. Uso fallback por ref."
                    git branch -f "$local_branch" "refs/heads/dev" >/dev/null 2>&1 \
                        || die "No pude crear '${local_branch}' por ref desde dev."
                fi
            else
                if ! git checkout -b "$local_branch" >/dev/null 2>&1; then
                    used_ref_fallback=1
                    log_warn "⚠️ No pude crear '${local_branch}' por checkout. Uso fallback por ref."
                    git branch -f "$local_branch" "$source_sha" >/dev/null 2>&1 \
                        || die "No pude crear '${local_branch}' por ref desde ${source_sha:0:7}."
                fi
            fi
        fi

        if [[ "$used_ref_fallback" -eq 1 ]]; then
            local local_ref_sha=""
            local_ref_sha="$(git rev-parse "refs/heads/${local_branch}" 2>/dev/null || true)"
            [[ -n "${local_ref_sha:-}" ]] || local_ref_sha="$source_sha"

            case "$strategy" in
                ff-only)
                    if git merge-base --is-ancestor "$local_ref_sha" "$source_sha"; then
                        final_sha="$source_sha"
                    else
                        rc=3
                    fi
                    ;;
                merge|merge-theirs|force)
                    final_sha="$source_sha"
                    if [[ "$strategy" != "force" ]]; then
                        log_warn "⚠️ Fallback sin checkout: estrategia '${strategy}' degradada a actualización por ref (${local_branch} -> ${source_sha:0:7})."
                    fi
                    ;;
                *)
                    die "Estrategia inválida: ${strategy}"
                    ;;
            esac

            if [[ "$rc" -eq 3 ]]; then
                log_warn "⚠️ Fast-Forward NO es posible para local. Elige otra estrategia."
                strategy="$(promote_choose_strategy_or_die)"
                export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
                continue
            fi

            [[ "$rc" -eq 0 ]] || die "No pude actualizar '${local_branch}' con estrategia '${strategy}' (rc=${rc})."
            git update-ref "refs/heads/${local_branch}" "$final_sha" >/dev/null 2>&1 \
                || die "No pude actualizar refs/heads/${local_branch} con fallback por ref."
            break
        fi

        case "$strategy" in
            ff-only)
                local base_sha=""
                base_sha="$(git rev-parse HEAD 2>/dev/null || true)"
                if [[ -n "${base_sha:-}" ]] && ! git merge-base --is-ancestor "$base_sha" "$source_sha"; then
                    rc=3
                else
                    git merge --ff-only "$source_sha" >/dev/null 2>&1 || rc=1
                fi
                ;;
            merge)
                git -c commit.gpgsign=false merge --no-ff --no-edit "$source_sha" >/dev/null 2>&1 || rc=1
                ;;
            merge-theirs)
                git -c commit.gpgsign=false merge --no-ff --no-edit -X theirs "$source_sha" >/dev/null 2>&1 || rc=1
                ;;
            force)
                git reset --hard "$source_sha" >/dev/null 2>&1 || rc=1
                ;;
            *)
                die "Estrategia inválida: ${strategy}"
                ;;
        esac

        if [[ "$rc" -eq 3 ]]; then
            log_warn "⚠️ Fast-Forward NO es posible para local. Elige otra estrategia."
            strategy="$(promote_choose_strategy_or_die)"
            export DEVTOOLS_PROMOTE_STRATEGY="$strategy"
            continue
        fi

        [[ "$rc" -eq 0 ]] || die "No pude actualizar '${local_branch}' con estrategia '${strategy}' (rc=${rc})."
        final_sha="$(git rev-parse HEAD 2>/dev/null || true)"
        break
    done

    log_success "✅ Estrategia aplicada: ${local_branch} <- ${source_sha:0:7} (strategy=${strategy}, sha=${final_sha:0:7})"
}




promote_local_push_branch_force_or_die() {
    local branch="${1:-local}"
    local remote="${2:-origin}"

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_warn "⚗️ DRY-RUN: omito push de ${remote}/${branch}."
        return 0
    fi

    if ! declare -F push_branch_force >/dev/null 2>&1; then
        log_error "❌ No se encontró push_branch_force."
        return 2
    fi
    push_branch_force "${branch}" "${remote}"
}



promote_local_offer_delete_source_branch_if_needed() {
    local source_branch="${1:-}"
    [[ -n "${source_branch:-}" ]] || return 0
    [[ "${source_branch}" != "(detached)" ]] || return 0

    local post_branch="${DEVTOOLS_PROMOTE_POST_BRANCH:-dev}"
    local prune_mode="${DEVTOOLS_PROMOTE_PRUNE_SOURCE_BRANCH:-ask}" # ask|1|0

    # 1) Post-promote: no volver a la rama fuente por defecto.
    if [[ -n "${post_branch:-}" ]]; then
        local current_branch=""
        current_branch="$(git branch --show-current 2>/dev/null || true)"
        if [[ "${current_branch:-}" != "${post_branch}" ]]; then
            if git show-ref --verify --quiet "refs/heads/${post_branch}"; then
                log_info "🛬 Finalizando flujo: aterrizando en '${post_branch}'."
                git checkout "${post_branch}" >/dev/null 2>&1 || log_warn "No pude cambiar a '${post_branch}'."
            elif git show-ref --verify --quiet "refs/remotes/origin/${post_branch}"; then
                log_info "🛬 Finalizando flujo: creando local '${post_branch}' desde origin/${post_branch}."
                git checkout -B "${post_branch}" "origin/${post_branch}" >/dev/null 2>&1 || log_warn "No pude crear '${post_branch}' desde origin."
            else
                log_warn "Rama post-promote '${post_branch}' no existe (local/remota). Mantengo rama actual."
            fi
        fi
    fi

    # 2) Limpieza de rama fuente controlada por env (ask|1|0).
    if promote_local_is_protected_branch "$source_branch"; then
        log_info "ℹ️ Limpieza omitida: '${source_branch}' es rama protegida."
        return 0
    fi

    case "${prune_mode}" in
        ask|1|0) ;;
        *)
            log_warn "DEVTOOLS_PROMOTE_PRUNE_SOURCE_BRANCH inválido ('${prune_mode}'). Uso 'ask'."
            prune_mode="ask"
            ;;
    esac

    if [[ "${prune_mode}" == "ask" ]]; then
        if [[ "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" ]]; then
            prune_mode="0"
        elif ! declare -F ask_yes_no >/dev/null 2>&1; then
            prune_mode="0"
        elif ! ask_yes_no "¿Borrar rama fuente '${source_branch}' local y remota?"; then
            prune_mode="0"
        else
            prune_mode="1"
        fi
    fi

    if [[ "${prune_mode}" != "1" ]]; then
        log_info "ℹ️ Limpieza omitida (DEVTOOLS_PROMOTE_PRUNE_SOURCE_BRANCH=${prune_mode})."
        return 0
    fi

    local upstream_short=""
    upstream_short="$(git for-each-ref --format='%(upstream:short)' "refs/heads/${source_branch}" | head -n 1 | tr -d '[:space:]' || true)"

    local current_branch=""
    current_branch="$(git branch --show-current 2>/dev/null || true)"
    if [[ "${current_branch:-}" == "${source_branch}" ]]; then
        log_warn "No puedo borrar '${source_branch}' porque sigue activa."
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/${source_branch}"; then
        if git branch -D "${source_branch}" >/dev/null 2>&1; then
            log_info "🧹 Rama local eliminada: ${source_branch}"
        else
            log_warn "No pude eliminar rama local: ${source_branch}"
        fi
    fi

    if [[ -n "${upstream_short:-}" ]]; then
        local remote_name="origin"
        local remote_branch="${source_branch}"
        local parsed_remote="${upstream_short%%/*}"
        local parsed_branch="${upstream_short#*/}"
        [[ -n "${parsed_remote:-}" && "${parsed_remote}" != "${upstream_short}" ]] && remote_name="${parsed_remote}"
        [[ -n "${parsed_branch:-}" ]] && remote_branch="${parsed_branch}"

        if git push "${remote_name}" --delete "${remote_branch}" >/dev/null 2>&1; then
            log_info "🧹 Rama remota eliminada: ${remote_name}/${remote_branch}"
        else
            log_warn "No pude eliminar rama remota ${remote_name}/${remote_branch}. Ejecuta: git push ${remote_name} --delete ${remote_branch}"
        fi
    else
        log_info "ℹ️ Rama '${source_branch}' sin upstream remoto: solo se eliminó local."
    fi
}



promote_local_ensure_tag_remote_or_die() {
    local tag="${1:-}"
    local source_sha="${2:-}"

    promote_local_ensure_remote_tag_or_die "$tag" "$source_sha"
}



promote_local_remote_tag_exists() {
    local tag="${1:-}"
    [[ -n "${tag:-}" ]] || return 1

    local refs=""
    refs="$(
        git ls-remote --tags origin "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>/dev/null \
            | awk '{print $2}' \
            | sed 's/\^{}$//'
    )"
    printf '%s\n' "${refs:-}" | grep -Fqx "refs/tags/${tag}"
}



promote_local_remote_tag_sha_or_empty() {
    local tag="${1:-}"
    local remote="${2:-origin}"
    [[ -n "${tag:-}" ]] || {
        printf '%s\n' ""
        return 0
    }

    local resolved=""
    resolved="$(git ls-remote --tags "${remote}" "refs/tags/${tag}^{}" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ -z "${resolved:-}" ]]; then
        resolved="$(git ls-remote --tags "${remote}" "refs/tags/${tag}" 2>/dev/null | awk 'NR==1 {print $1}')"
    fi
    printf '%s\n' "${resolved:-}"
    return 0
}



promote_local_next_remote_safe_tag() {
    local candidate="${1:-}"
    local head_sha="${2:-}"
    local max_tries="${3:-30}"
    local try=0
    local next=""
    local remote_sha=""

    [[ -n "${candidate:-}" ]] || return 1

    while (( try < max_tries )); do
        if ! promote_local_remote_tag_exists "${candidate}"; then
            printf '%s\n' "${candidate}"
            return 0
        fi

        remote_sha="$(promote_local_remote_tag_sha_or_empty "${candidate}" "origin")"
        if [[ -n "${head_sha:-}" && -n "${remote_sha:-}" && "${remote_sha}" == "${head_sha}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi

        next="$(promote_local_ensure_tag_matches_head_or_bump "${candidate}" "${head_sha}" 2>/dev/null || true)"
        if [[ -z "${next:-}" || "${next}" == "${candidate}" ]]; then
            local base=""
            local current_rev=0
            base="$(promote_local_strip_rev_suffix "${candidate}")"
            if [[ "${candidate}" =~ -rev\.([0-9]+)$ ]]; then
                current_rev="${BASH_REMATCH[1]}"
            fi
            next="${base}-rev.$((current_rev + 1))"
        fi

        candidate="${next}"
        try=$((try + 1))
    done

    return 1
}



promote_local_ensure_remote_tag_or_die() {
    local tag="${1:-}"
    local source_sha="${2:-}"

    [[ -n "${tag:-}" ]] || { log_error "❌ Tag vacío para publish remoto."; return 2; }
    promote_local_is_valid_tag_name "${tag}" || {
        log_error "❌ Tag inválido '${tag}'. Permitidos: [0-9A-Za-z._+-]"
        return 2
    }

    if promote_local_remote_tag_exists "${tag}"; then
        return 0
    fi

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_error "❌ Tag remoto inexistente en DRY_RUN: refs/tags/${tag}."
        return 2
    fi

    if ! git show-ref --verify --quiet "refs/tags/${tag}"; then
        [[ -n "${source_sha:-}" ]] || {
            log_error "❌ No existe tag local '${tag}' y no recibí SHA para crearlo."
            return 2
        }
        git tag -a "${tag}" "${source_sha}" -m "chore(release): ${tag}" || {
            log_error "❌ No pude crear el tag local '${tag}'."
            return 2
        }
    fi

    if ! git push origin "refs/tags/${tag}"; then
        log_error "❌ No pude pushear el tag. Ejecuta: git push origin refs/tags/${tag}"
        return 2
    fi

    if ! promote_local_remote_tag_exists "${tag}"; then
        log_error "❌ El tag remoto no aparece tras push: refs/tags/${tag}."
        return 2
    fi
    return 0
}



promote_local_resolve_gitops_revision() {
    local final_tag="${1:-}"

    if [[ -n "${DEVTOOLS_GITOPS_REVISION:-}" ]]; then
        printf '%s\n' "${DEVTOOLS_GITOPS_REVISION}"
        return 0
    fi
    if [[ -n "${DEVTOOLS_PROMOTE_TAG:-}" ]]; then
        printf '%s\n' "${DEVTOOLS_PROMOTE_TAG}"
        return 0
    fi
    if [[ -n "${final_tag:-}" ]]; then
        printf '%s\n' "${final_tag}"
        return 0
    fi

    printf '%s\n' "local"
    return 0
}



promote_local_ensure_tag_matches_head_or_bump() {
    local candidate_tag="$1"
    local head_sha="$2"

    [[ -n "${candidate_tag:-}" ]] || return 1
    [[ -n "${head_sha:-}" ]] || return 1

    git fetch --tags --quiet >/dev/null 2>&1 || true

    if ! git show-ref --tags --verify --quiet "refs/tags/${candidate_tag}"; then
        printf '%s\n' "${candidate_tag}"
        return 0
    fi

    if promote_local_tag_points_to_sha "${candidate_tag}" "${head_sha}"; then
        printf '%s\n' "${candidate_tag}"
        return 0
    fi

    local base next_rev bumped_tag
    base="$(promote_local_strip_rev_suffix "${candidate_tag}")"
    next_rev="$(promote_local_next_rev_for_base "${base}")"
    bumped_tag="${base}-rev.${next_rev}"
    printf '%s\n' "${bumped_tag}"
    return 0
}



promote_local_pick_head_rev_tag_or_empty() {
    local sha="${1:-}"
    [[ -n "${sha:-}" ]] || {
        printf '%s\n' ""
        return 0
    }

    local selected=""
    local tag=""
    while IFS= read -r tag; do
        [[ -n "${tag:-}" ]] || continue
        promote_local_is_valid_tag_name "${tag}" || continue
        [[ "${tag}" =~ -rev\.([0-9]+)$ ]] || continue
        selected="${tag}"
    done < <(git tag --points-at "${sha}" 2>/dev/null | sort -V)

    printf '%s\n' "${selected:-}"
    return 0
}



promote_local_remote_branch_sha_best_effort() {
    local remote="${1:-origin}"
    local branch="${2:-local}"
    local sha=""

    sha="$(git ls-remote --heads "${remote}" "${branch}" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ -n "${sha:-}" ]]; then
        printf '%s\n' "$sha"
        return 0
    fi

    sha="$(git rev-parse "${remote}/${branch}" 2>/dev/null || true)"
    printf '%s\n' "${sha:-}"
    return 0
}

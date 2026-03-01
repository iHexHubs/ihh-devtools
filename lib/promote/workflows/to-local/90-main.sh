#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_maybe_create_local_tag_or_die() {
    local final_tag="${1:-}"
    local tag_target_sha="${2:-}"

    [[ -n "${final_tag:-}" ]] || die "Tag local vacío en prepare."
    [[ -n "${tag_target_sha:-}" ]] || die "SHA objetivo vacío para tag local."

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_warn "⚗️ DRY-RUN: omito creación de tag local (${final_tag})."
        return 0
    fi

    if git show-ref --verify --quiet "refs/tags/${final_tag}"; then
        local existing_tag_sha=""
        existing_tag_sha="$(git rev-list -n 1 "${final_tag}" 2>/dev/null || true)"
        if [[ -n "${existing_tag_sha:-}" && "${existing_tag_sha}" != "${tag_target_sha}" ]]; then
            die "El tag local ${final_tag} ya existe y apunta a otro SHA (${existing_tag_sha:0:7})."
        fi
        return 0
    fi

    git tag -a "${final_tag}" "${tag_target_sha}" -m "chore(local): ${final_tag}" \
        || die "No pude crear el tag local ${final_tag}."
    log_info "Checkpoint: tag local creado (${final_tag})"
    return 0
}



promote_to_local_v2() {
    resync_submodules_hard

    local source_branch="${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
    if [[ -z "${source_branch:-}" || "${source_branch:-}" == "(detached)" ]]; then
        source_branch="$(git branch --show-current 2>/dev/null || true)"
    fi
    source_branch="$(echo "${source_branch:-}" | tr -d '[:space:]')"
    [[ -n "${source_branch:-}" ]] || die "No pude detectar rama fuente."

    if promote_local_is_protected_branch "$source_branch"; then
        die "No ejecutes promote local desde rama protegida (${source_branch}). Crea una rama de trabajo."
    fi

    local source_sha="${DEVTOOLS_PROMOTE_FROM_SHA:-}"
    if [[ -z "${source_sha:-}" ]]; then
        source_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    fi
    [[ -n "${source_sha:-}" ]] || die "No pude resolver SHA fuente."

    if declare -F ensure_promote_preflight_or_die >/dev/null 2>&1; then
        ensure_promote_preflight_or_die "$source_sha"
    fi

    log_info "PROMOCION LOCAL (transaccional)"
    log_info "Fuente : ${source_branch} @${source_sha:0:7}"

    local selected_level=""
    local run_rc=0
    while true; do
        selected_level="$(promote_local_choose_validation_level)"
        selected_level="${selected_level//$'\r'/}"
        selected_level="$(echo "${selected_level:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
        [[ -n "${selected_level:-}" ]] || selected_level="exit"

        promote_local_run_validation_level "$selected_level" "$source_branch"
        run_rc=$?
        case "$run_rc" in
            0) break ;;
            10)
                log_info "🚪 Flujo finalizado sin promover local."
                return 0
                ;;
            11)
                continue
                ;;
            12)
                log_info "📨 PR creado. Finalizo sin promover local."
                return 0
                ;;
            *)
                die "Validación '${selected_level}' falló (rc=${run_rc}). Abortando sin tocar 'local'."
                ;;
        esac
    done

    local local_sha_before=""
    local_sha_before="$(git rev-parse refs/heads/local 2>/dev/null || true)"

    local candidate_sha=""
    candidate_sha="$(promote_local_promote_transactional_or_die "$source_sha" "local")"
    [[ -n "${candidate_sha:-}" ]] || die "No pude resolver SHA final de local."

    if [[ "${DEVTOOLS_DRY_RUN:-0}" != "1" ]]; then
        git checkout local >/dev/null 2>&1 || log_warn "No pude dejarte en rama 'local'."
    fi

    if [[ "$selected_level" == "standard" && "${DEVTOOLS_DRY_RUN:-0}" != "1" ]]; then
        local app_name=""
        local base_version=""
        local rc=""
        local build=""
        local rev=""
        local final_tag=""

        app_name="$(promote_local_app_name)" || die "No pude resolver nombre de programa para tag local."
        base_version="$(promote_local_base_version)" || die "VERSION inválida o ausente en raíz."
        promote_local_select_rc_build "$app_name" "$base_version" rc build
        rev="$(promote_local_next_rev "$app_name" "$base_version" "$rc" "$build")"
        final_tag="$(promote_local_tag_name "$app_name" "$base_version" "$rc" "$build" "$rev")"

        promote_local_create_tag "$final_tag" "$candidate_sha" \
            || die "No pude crear/publicar tag local ${final_tag}."
        log_success "✅ Tag local creado: ${final_tag}"
    fi

    log_info "Local antes: ${local_sha_before:-<vacío>}"
    log_info "Local ahora: ${candidate_sha}"
    log_success "✅ Promoción local completada (transaccional)."
    return 0
}



promote_to_local() {
    if [[ "${DEVTOOLS_LOCAL_PROMOTE_V2:-1}" == "1" ]]; then
        promote_to_local_v2 "$@"
        return $?
    fi

    resync_submodules_hard
    PROMOTE_ENTRY_DIR="${PROMOTE_ENTRY_DIR:-${REPO_ROOT:-$PWD}}"
    git_entry() {
        env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR \
            git -C "$PROMOTE_ENTRY_DIR" "$@"
    }

    local source_branch="${DEVTOOLS_PROMOTE_FROM_BRANCH:-}"
    if [[ -z "${source_branch:-}" || "${source_branch:-}" == "(detached)" ]]; then
        source_branch="$(git branch --show-current 2>/dev/null || echo "")"
    fi
    source_branch="$(echo "${source_branch:-}" | tr -d '[:space:]')"
    [[ -n "${source_branch:-}" ]] || die "No pude detectar rama fuente."

    if promote_local_is_protected_branch "$source_branch"; then
        log_info "📌 Rama fuente protegida '${source_branch}': se permite promote local en modo seguro."
    fi

    local source_sha="${DEVTOOLS_PROMOTE_FROM_SHA:-}"
    if [[ -z "${source_sha:-}" ]]; then
        source_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    fi
    if ! declare -F ensure_promote_preflight_or_die >/dev/null 2>&1; then
        die "No se encontró ensure_promote_preflight_or_die."
    fi
    ensure_promote_preflight_or_die "$source_sha"

    echo
    log_info "PROMOCION LOCAL"
    log_info "Fuente : ${source_branch} @${source_sha:0:7}"
    log_info "Checkpoint: preflight ok"
    log_info "Gate por SHA: validando workflows requeridos para ${source_sha:0:7}"
    promote_local_ensure_checks_loaded
    gate_required_workflows_on_sha_or_die "$source_sha" "$source_branch" "local" \
        || die "Gate por SHA no aprobado; abortando."
    log_info "Checkpoint: gate-by-sha ok"
    echo

    # Detectar cambios simples por paths (para Gate selectivo)
    local base_ref=""
    if git show-ref --verify --quiet "refs/remotes/origin/dev"; then
        base_ref="origin/dev"
    elif git show-ref --verify --quiet "refs/heads/dev"; then
        base_ref="dev"
    fi

    local backend_changed=0 frontend_changed=0
    local changes
    changes="$(promote_local_detect_changes "$base_ref" "$source_sha")"
    while IFS='=' read -r key value; do
        case "$key" in
            backend) backend_changed="$value" ;;
            frontend) frontend_changed="$value" ;;
        esac
    done <<< "$changes"

    if [[ "$backend_changed" -eq 0 && "$frontend_changed" -eq 0 ]]; then
        log_warn "Sin cambios en backend/frontend."
    else
        log_info "Cambios detectados: backend=${backend_changed} frontend=${frontend_changed}"
    fi
    local p0_is_no_app=0
    if [[ "$backend_changed" -eq 0 && "$frontend_changed" -eq 0 ]]; then
        p0_is_no_app=1
    fi
    local p0_mode="${DEVTOOLS_PROMOTE_P0_MODE:-gitops-only}" # gitops-only|config-only|noop|publish
    case "$p0_mode" in
        gitops-only|config-only|noop|publish) ;;
        *)
            log_warn "DEVTOOLS_PROMOTE_P0_MODE inválido ('${p0_mode}'). Uso 'gitops-only'."
            p0_mode="gitops-only"
            ;;
    esac

    local gate_ok=0
    local native_override=""
    if [[ "$backend_changed" -eq 1 && "$frontend_changed" -eq 0 ]]; then
        # native_override="task ci:backend"
        native_override="task pipeline:ci:backend"
    elif [[ "$backend_changed" -eq 0 && "$frontend_changed" -eq 1 ]]; then
        # native_override="task ci:frontend"
        native_override="task pipeline:ci:frontend"
    fi
    if [[ -n "${native_override:-}" ]]; then
        export DEVTOOLS_CI_NATIVE_CMD_OVERRIDE="$native_override"
    else
        unset DEVTOOLS_CI_NATIVE_CMD_OVERRIDE
    fi

    local ci_workflow=""
    if [[ -n "${LIB_DIR:-}" ]]; then
        ci_workflow="${LIB_DIR}/ci-workflow.sh"
    else
        local _base_dir
        _base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        ci_workflow="${_base_dir}/ci-workflow.sh"
    fi

    if command -v is_tty >/dev/null 2>&1 && is_tty; then
        if [[ -f "$ci_workflow" ]]; then
            # Menú de validación antes de compilar
            # shellcheck disable=SC1090
            source "$ci_workflow"
            POST_PUSH_FLOW=true
            unset NATIVE_CI_CMD ACT_CI_CMD COMPOSE_CI_CMD K8S_HEADLESS_CMD K8S_FULL_CMD
            detect_ci_tools

            # En preflight de promote:local NO queremos opciones pesadas del pipeline.
            unset COMPOSE_CI_CMD K8S_HEADLESS_CMD K8S_FULL_CMD

            # Render del panel una sola vez; el menú puede repetirse sin duplicar el dashboard.
            ci_render_validation_menu_header "$source_branch"

            while true; do
                local selected rc
                # IMPORTANT: evitar subshell-loss de CI_OPT_* (ci_prompt_validation_menu corre en $(...))
                ci_build_validation_menu
                selected="$(ci_prompt_validation_menu || true)"
                # Normalizar (gum puede incluir CR en algunos TTYs)
                selected="${selected//$'\r'/}"

                # Cancelar/ESC devuelve vacío: re-mostrar menú.
                if [[ -z "${selected:-}" ]]; then
                    continue
                fi

                # 🚪 Salir: salida limpia antes de tags/overlay/commit/push.
                if [[ "${selected}" == "${CI_OPT_SKIP:-}" ]]; then
                    echo "👌 Omitido."
                    return 0
                fi

                # Guard de permisos solo si la opción usa CI nativo.
                if ci_selection_uses_native "$selected" && [[ "$frontend_changed" -eq 1 ]]; then
                    promote_local_frontend_permissions_guard || die "Permisos invalidos en node_modules (frontend)."
                fi

                ci_run_validation_option "$selected" "$source_branch" "local" "pre"
                rc=$?

                # 10=skip, 11=acción no-terminal (help/k9s/cluster:up) → re-mostrar menú.
                if [[ "$rc" -eq 10 ]]; then
                    return 0
                elif [[ "$rc" -eq 11 ]]; then
                    continue
                elif [[ "$rc" -ne 0 ]]; then
                    return "$rc"
                fi

                # Si fue una validación (Gate/Native/Act/Compose/K8s...), continuamos con tag/build/overlay.
                if ci_is_validation_option "$selected"; then
                    gate_ok=1
                    break
                fi

                # Selección desconocida que no produjo acción: reintentar sin spamear panel.
                log_warn "Opción no reconocida: '${selected}'. Reintentando..."
            done
        else
            log_warn "No se encontró ci-workflow.sh. Saliendo sin ejecutar validaciones."
            return 0
        fi
    else
        # Fallback no interactivo
        if [[ "$backend_changed" -eq 1 ]]; then
            # log_info "Gate: task ci:backend"
            # task ci:backend
            log_info "Gate: task pipeline:ci:backend"
            task pipeline:ci:backend
        fi
        if [[ "$frontend_changed" -eq 1 ]]; then
            promote_local_frontend_permissions_guard || die "Permisos invalidos en node_modules (frontend)."
            # log_info "Gate: task ci:frontend"
            # task ci:frontend
            log_info "Gate: task pipeline:ci:frontend"
            task pipeline:ci:frontend
        fi

        log_info "Gate: task ci:act"
        task ci:act
        gate_ok=1
    fi

    unset DEVTOOLS_CI_NATIVE_CMD_OVERRIDE
    if [[ "$gate_ok" -ne 1 ]]; then
        die "Gate no aprobado; abortando sin side-effects."
    fi
    log_info "Checkpoint: gate ok"
    log_info "🧪 FASE PREPARE: validaciones y armado local (sin side-effects remotos)."
    local strategy_applied=0
    local overlay_file="devops/k8s/overlays/local/kustomization.yaml"

    if [[ "$p0_is_no_app" -eq 1 ]]         && [[ "$p0_mode" != "noop" ]]         && [[ ! -f "$overlay_file" ]]         && [[ "${CI:-0}" == "1" ]]         && [[ "${DEVTOOLS_NONINTERACTIVE:-0}" == "1" ]]         && [[ "${DEVTOOLS_PROMOTE_LOCAL_CI_NOOP_WHEN_NO_OVERLAY:-1}" == "1" ]]; then
        p0_mode="noop"
        log_warn "⚠️ CI/no interactivo sin overlay local: fuerzo DEVTOOLS_PROMOTE_P0_MODE=noop."
    fi

    if [[ "$p0_is_no_app" -eq 1 ]]; then
        log_info "⚙️ P0 mode=${p0_mode} (sin cambios de app)."
        if [[ "$p0_mode" == "noop" ]]; then
            local local_sha_before_strategy=""
            local_sha_before_strategy="$(git rev-parse local 2>/dev/null || echo "(local-missing)")"
            log_info "ANTES estrategia: local apunta a ${local_sha_before_strategy}"
            promote_local_apply_strategy_to_local_or_die "$source_sha" "local"
            local local_sha_after_strategy=""
            local_sha_after_strategy="$(git rev-parse local 2>/dev/null || echo "(local-missing)")"
            log_info "DESPUÉS estrategia: local apunta a ${local_sha_after_strategy}"
            log_info "Checkpoint: strategy local<-source aplicada"
            strategy_applied=1

            local pushed_local=0
            local pushed_tag=0
            local argocd_changed=0
            local argocd_sync_skipped=0
            log_info "⛔ Modo NO-OP transaccional: no actualizaré origin/local, no crearé/pushearé tags, no tocaré ArgoCD."
            log_info "📌 Resultado final: SUCCESS (mode=noop, pushed_local=${pushed_local}, pushed_tag=${pushed_tag}, argocd_changed=${argocd_changed}, argocd_sync_skipped=${argocd_sync_skipped})."
            log_success "✅ Promoción local completada (NO-OP)."
            return 0
        fi
    fi

    # Aplicar estrategia elegida (menú de seguridad) sobre la rama local usando SHA fuente.
    if [[ "$strategy_applied" -ne 1 ]]; then
        local local_sha_before_strategy=""
        local_sha_before_strategy="$(git rev-parse local 2>/dev/null || echo "(local-missing)")"
        log_info "ANTES estrategia: local apunta a ${local_sha_before_strategy}"
        promote_local_apply_strategy_to_local_or_die "$source_sha" "local"
        local local_sha_after_strategy=""
        local_sha_after_strategy="$(git rev-parse local 2>/dev/null || echo "(local-missing)")"
        log_info "DESPUÉS estrategia: local apunta a ${local_sha_after_strategy}"
        log_info "Checkpoint: strategy local<-source aplicada"
    fi

    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "config-only" ]]; then
        local local_branch="local"
        local pushed_local=0
        local pushed_tag=0
        local argocd_changed=0
        local argocd_sync_skipped=0

        log_info "⚙️ P0 CONFIG-ONLY: push de origin/local únicamente; sin tags; sin ArgoCD."
        log_info "🚀 FASE PUBLISH: side-effects remotos (solo origin/local)."
        if ! declare -F push_branch_force >/dev/null 2>&1; then
            die "No se encontró push_branch_force."
        fi
        push_branch_force "$local_branch" "origin" || die "No pude empujar a origin/${local_branch} en modo config-only."
        pushed_local=1
        log_info "Checkpoint: pushed local (config-only)"
        log_info "Checkpoint: tag omitido por P0 config-only"
        log_info "Checkpoint: ArgoCD omitido por P0 config-only"

        log_info "📌 Resultado final: SUCCESS (mode=config-only, pushed_local=${pushed_local}, pushed_tag=${pushed_tag}, argocd_changed=${argocd_changed}, argocd_sync_skipped=${argocd_sync_skipped})."
        log_success "✅ Promoción local completada (P0 config-only)."
        return 0
    fi

    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "gitops-only" ]]; then
        log_info "⚙️ P0 GITOPS-ONLY: se publicará origin/local + tag + ArgoCD, sin build/load."
    fi

    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "publish" ]]; then
        log_info "⚙️ P0 PUBLISH: flujo completo habilitado explícitamente (incluye tags/ArgoCD)."
    fi

    local local_has_overlay=0
    local previous_tag=""
    previous_tag="$(promote_local_get_previous_tag "$overlay_file" "origin" "local")"
    previous_tag="${previous_tag:-local}"
    local overlay_tag_current=""
    if [[ -f "$overlay_file" ]]; then
        local_has_overlay=1
        overlay_tag_current="$(promote_local_read_overlay_tag_from_text < "$overlay_file" 2>/dev/null || true)"
    else
        log_warn "⚠️ Overlay local no encontrado (${overlay_file}). Omitiré mutaciones/render de overlay para este repo."
    fi

    if ! declare -F promote_next_tag_local >/dev/null 2>&1; then
        die "No se encontro promote_next_tag_local."
    fi
    if ! declare -F semver_parse_tag >/dev/null 2>&1; then
        die "No se encontro semver_parse_tag."
    fi

    local final_tag
    final_tag="$(promote_local_next_tag_from_previous "$previous_tag")"
    [[ -n "${final_tag:-}" ]] || die "No pude calcular el tag local."

    local override_tag="${DEVTOOLS_PROMOTE_TAG_OVERRIDE:-}"
    if [[ -n "${override_tag:-}" ]]; then
        final_tag="$override_tag"
        log_info "Override de tag por DEVTOOLS_PROMOTE_TAG_OVERRIDE: ${final_tag}"
    fi

    local tag_target_sha=""
    tag_target_sha="$(promote_local_resolve_tag_target_sha "$source_sha")" \
        || die "No pude resolver SHA destino para el tag local."
    final_tag="$(promote_local_ensure_tag_matches_head_or_bump "$final_tag" "$tag_target_sha")" \
        || die "No pude ajustar tag local para que represente el commit promovido."

    local base_tag parsed_ver parsed_rc parsed_build
    base_tag="$(promote_strip_rev_from_tag "$final_tag")"
    if ! semver_parse_tag "$base_tag" parsed_ver parsed_rc parsed_build; then
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            local dry_head_rev_tag=""
            dry_head_rev_tag="$(promote_local_pick_head_rev_tag_or_empty "$tag_target_sha")"
            if [[ -n "${dry_head_rev_tag:-}" ]]; then
                final_tag="${dry_head_rev_tag}"
                base_tag="$(promote_strip_rev_from_tag "$final_tag")"
                log_warn "⚗️ DRY-RUN: usando tag existente de HEAD para continuar smoke (${final_tag})."
            fi
        fi
    fi
    if ! semver_parse_tag "$base_tag" parsed_ver parsed_rc parsed_build; then
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            parsed_ver="0.0.0"
            parsed_rc=""
            parsed_build=""
            log_warn "⚗️ DRY-RUN: no pude parsear semver de '${base_tag}'. Continúo smoke sin metadatos de versión."
        else
            die "Formato invalido. Esperado [APP]-vX.Y.Z-rc.N+build.N-rev.N"
        fi
    fi

    local image_tag="$final_tag"
    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "gitops-only" ]]; then
        image_tag="${overlay_tag_current:-$previous_tag}"
        [[ -n "${image_tag:-}" ]] || die "P0 gitops-only requiere newTag en overlay local (no pude resolver DOCKER_TAG)."
        log_info "⚙️ P0 GITOPS-ONLY: sin build/load; DOCKER_TAG=${image_tag}; publicar origin/local + tag + ArgoCD."
    else
        if declare -F semver_to_image_tag >/dev/null 2>&1; then
            image_tag="$(semver_to_image_tag "$final_tag")"
        fi
    fi
    export DEVTOOLS_PROMOTE_IMAGE_TAG="$image_tag"

    local promote_tag_file
    promote_tag_file="$(promote_tag_file_path)"
    promote_tag_write_cache "$final_tag" "$parsed_ver" "$parsed_rc" "$parsed_build" "local" "to-local" "$promote_tag_file" \
        || die "No pude escribir .promote_tag."

    log_info "Tag local (provisional): ${final_tag}"
    log_info "Tag imagen: ${image_tag} (previo: ${previous_tag})"
    log_info "Checkpoint: version ok (tag=${final_tag})"

    local argocd_app="${DEVTOOLS_ARGOCD_APP_LOCAL:-pmbok-backend-app}"
    local gitops_revision=""
    gitops_revision="$(promote_local_resolve_gitops_revision "$final_tag")"
    [[ -n "${gitops_revision:-}" ]] || gitops_revision="local"
    log_info "GitOps local: app=${argocd_app} revision=${gitops_revision}"

    local tag_owner="Local"
    local tag_owner_reason="workflow"
    local reuse_existing_tag=0
    promote_local_resolve_tag_owner || die "No pude resolver owner de tags para local."
    tag_owner="${PROMOTE_TAG_OWNER:-Local}"
    tag_owner_reason="${PROMOTE_TAG_OWNER_REASON:-workflow}"
    if declare -F log_info >/dev/null 2>&1; then
        log_info "Owner tags = ${tag_owner} | Razón = ${tag_owner_reason}"
    else
        echo "Owner tags = ${tag_owner} | Razón = ${tag_owner_reason}"
    fi

    # Build + load según runtime de cluster, usando un único DOCKER_TAG para backend/frontend.
    export DOCKER_TAG="$image_tag"
    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "gitops-only" ]]; then
        log_info "Checkpoint: build/load omitido por P0 gitops-only (DOCKER_TAG=${DOCKER_TAG})"
    else
        if ! promote_local_preflight_docker_or_die; then
            return 2
        fi

        local runtime=""
        promote_local_ensure_cluster_runtime runtime
        [[ -n "${runtime:-}" ]] || die "No pude resolver runtime local para build/load."
        export DEVTOOLS_LOCAL_CLUSTER_RUNTIME="$runtime"
        log_info "Runtime local detectado: ${runtime}"
        log_info "DOCKER_TAG compartido: ${DOCKER_TAG}"
        promote_local_guard_runtime_matches_kubectl_context_or_die "$runtime"

        if [[ "$backend_changed" -eq 1 ]]; then
            promote_local_build_and_load_image "$runtime" "backend" "$DOCKER_TAG"
        else
            promote_local_retag_or_build "$runtime" "backend" "$previous_tag" "$DOCKER_TAG"
        fi

        if [[ "$frontend_changed" -eq 1 ]]; then
            promote_local_build_and_load_image "$runtime" "frontend" "$DOCKER_TAG"
        else
            promote_local_retag_or_build "$runtime" "frontend" "$previous_tag" "$DOCKER_TAG"
        fi

        log_info "Checkpoint: build/load ok"
        promote_local_preflight_images_or_die "$runtime" "$DOCKER_TAG"
    fi

    # Crear/actualizar rama local con el overlay actualizado
    local local_branch="local"
    local local_before_publish_sha=""
    local commit_created=0
    local pushed_local=0
    local pushed_tag=0
    local argocd_changed=0
    local argocd_sync_skipped=0
    local old_origin_local_sha=""
    local old_argocd_revision=""
    local return_to_source="${DEVTOOLS_PROMOTE_LOCAL_RETURN_TO_SOURCE:-0}"

    promote_local_rollback_before_push() {
        local reason="$1"
        if [[ "$commit_created" -eq 1 && "$pushed_local" -eq 0 && -n "${local_before_publish_sha:-}" ]]; then
            if git checkout "$local_branch" >/dev/null 2>&1 \
                && git reset --hard "$local_before_publish_sha" >/dev/null 2>&1; then
                log_warn "Rollback local aplicado (${reason})."
            else
                log_warn "Rollback sugerido: git checkout ${local_branch} && git reset --hard ${local_before_publish_sha}"
            fi
        fi
    }

    promote_local_rollback_after_publish_best_effort() {
        local reason="${1:-fallo en publish}"
        local current_remote_sha=""
        log_warn "↩️ ROLLBACK best-effort: ${reason}"

        if [[ "$argocd_changed" -eq 1 && -n "${old_argocd_revision:-}" ]]; then
            log_warn "Intentando rollback ArgoCD -> ${old_argocd_revision}"
            if ! promote_local_argocd_sync_by_tag_or_die "${old_argocd_revision}" "${argocd_app}" "${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}"; then
                log_warn "No pude revertir ArgoCD automáticamente. Manual: argocd --core app set ${argocd_app} --revision ${old_argocd_revision} && argocd --core app sync ${argocd_app}"
            fi
        fi

        if [[ "$pushed_tag" -eq 1 ]]; then
            log_warn "Intentando rollback tag remoto ${final_tag}"
            if ! git push origin ":refs/tags/${final_tag}" >/dev/null 2>&1; then
                log_warn "No pude borrar tag remoto ${final_tag}. Manual: git push origin :refs/tags/${final_tag}"
            fi
        fi

        if [[ "$pushed_local" -eq 1 ]]; then
            if [[ -n "${old_origin_local_sha:-}" ]]; then
                current_remote_sha="$(promote_local_remote_branch_sha_best_effort "origin" "${local_branch}")"
                if [[ -n "${current_remote_sha:-}" ]]; then
                    if ! git push origin --force-with-lease="refs/heads/${local_branch}:${current_remote_sha}" "${old_origin_local_sha}:refs/heads/${local_branch}" >/dev/null 2>&1; then
                        log_warn "No pude restaurar origin/${local_branch}. Manual: git push origin --force-with-lease=refs/heads/${local_branch}:${current_remote_sha} ${old_origin_local_sha}:refs/heads/${local_branch}"
                    fi
                else
                    log_warn "No pude leer SHA remoto actual para rollback de origin/${local_branch}."
                fi
            else
                log_warn "No capturé SHA previo de origin/${local_branch}; omito rollback automático de rama remota."
                log_warn "Manual: git log --oneline origin/${local_branch} y luego git push origin --force-with-lease refs/heads/${local_branch}:<sha_anterior>"
            fi
        fi
    }

    promote_local_cleanup_stale_worktrees_for_branch "$local_branch"
    if branch_exists_remote "$local_branch" "origin"; then
        ensure_local_branch_tracks_remote "$local_branch" "origin" || true
        if ! promote_local_checkout_branch_best_effort "$local_branch"; then
            if ! git show-ref --verify --quiet "refs/heads/${local_branch}"; then
                git branch -f "$local_branch" "refs/remotes/origin/${local_branch}" >/dev/null 2>&1 || true
            fi
            promote_local_checkout_branch_best_effort "$local_branch" || true
        fi
    else
        # Sin origin/local: preferir rama local existente antes de intentar crearla.
        if git show-ref --verify --quiet "refs/heads/${local_branch}"; then
            promote_local_checkout_branch_best_effort "$local_branch" || true
        elif git show-ref --verify --quiet "refs/heads/dev"; then
            git branch -f "$local_branch" "refs/heads/dev" >/dev/null 2>&1 || true
            promote_local_checkout_branch_best_effort "$local_branch" || true
        else
            git branch -f "$local_branch" "$source_sha" >/dev/null 2>&1 || true
            promote_local_checkout_branch_best_effort "$local_branch" || true
        fi
    fi
    local_before_publish_sha="$(git rev-parse "refs/heads/${local_branch}" 2>/dev/null || git rev-parse HEAD 2>/dev/null || true)"
    [[ -n "${local_before_publish_sha:-}" ]] || die "No pude resolver SHA base de la rama local."
    local current_publish_branch=""
    current_publish_branch="$(git branch --show-current 2>/dev/null || true)"
    local can_mutate_overlay=1
    if [[ "${current_publish_branch:-}" != "${local_branch}" ]]; then
        if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "gitops-only" ]]; then
            can_mutate_overlay=0
            log_warn "⚠️ No estoy en '${local_branch}' (actual='${current_publish_branch:-<vacío>}'). Continúo en P0 gitops-only sin mutar overlay/commit."
        elif [[ "$local_has_overlay" -eq 0 ]]; then
            can_mutate_overlay=0
            log_warn "⚠️ No estoy en '${local_branch}' (actual='${current_publish_branch:-<vacío>}'). Este repo no tiene overlay local; continúo sin mutaciones."
        fi
    fi

    if [[ "$p0_is_no_app" -eq 1 && "$p0_mode" == "gitops-only" ]]; then
        if [[ "$local_has_overlay" -eq 1 ]]; then
            promote_local_verify_rendered_tags_or_die "devops/k8s/overlays/local" "$DOCKER_TAG"
            log_info "Checkpoint: render GitOps validado (P0 gitops-only, sin mutar overlay)."
        else
            log_warn "⚠️ P0 gitops-only: omito validación de render porque no existe overlay local en este repo."
        fi
    else
        if [[ "$local_has_overlay" -eq 1 && "$can_mutate_overlay" -eq 0 ]]; then
            log_warn "⚠️ Omitiendo mutación de overlay/commit: no estoy en '${local_branch}' y este contexto permite continuar sin checkout."
        elif [[ "$local_has_overlay" -eq 1 ]]; then
        if [[ "${current_publish_branch:-}" != "${local_branch}" ]]; then
            die "No estoy en la rama '${local_branch}' antes de mutar overlay/commit (actual='${current_publish_branch:-<vacío>}')."
        fi
        local local_pull_policy=""
        local_pull_policy="$(promote_local_pull_policy)"
        promote_local_apply_pull_policy_overrides "$local_pull_policy"
        local registry_value="${DEVTOOLS_LOCAL_REGISTRY:-}"
        local registry_prefix="${registry_value%/}"
        local backend_newname="pmbok-backend"
        local frontend_newname="pmbok-frontend"
        if [[ -n "${DEVTOOLS_LOCAL_REGISTRY:-}" ]]; then
            local registry_host="${registry_prefix%%/*}"
            if [[ "$registry_host" != *.* && "$registry_host" != *:* ]]; then
                die "DEVTOOLS_LOCAL_REGISTRY inválido: ${registry_prefix}. Usa host calificado (ej: localhost:5000/pmbok)."
            fi
            backend_newname="${registry_prefix}/backend"
            frontend_newname="${registry_prefix}/frontend"
            log_info "Registry local activo: ${registry_prefix}"
            log_info "Registry prefix final: ${registry_prefix}"
        else
            log_info "Fallback sin registry local: usando newName sin registry."
        fi

        if [[ -n "${DEVTOOLS_LOCAL_REGISTRY:-}" ]]; then
            promote_local_push_images_to_local_registry_or_die "$registry_prefix" "$image_tag"
        fi

        promote_local_update_kustomize_newnames "$overlay_file" "$backend_newname" "$frontend_newname"
        promote_local_update_kustomize_tag "$overlay_file" "$image_tag"
        promote_local_verify_overlay_image_settings_or_die "$overlay_file" "$backend_newname" "$frontend_newname" "$image_tag"
        promote_local_verify_rendered_tags_or_die "devops/k8s/overlays/local" "$DOCKER_TAG"

        git add \
            "$overlay_file" \
            "devops/k8s/overlays/local/patch-imagepullpolicy-backend.yaml" \
            "devops/k8s/overlays/local/patch-imagepullpolicy-frontend.yaml"
        if git diff --cached --quiet; then
            log_warn "No hay cambios en overlay local. Omitiendo commit."
        else
            git commit -m "chore(local): promote overlay" \
                || die "No pude crear el commit local."
            commit_created=1
        fi
        else
            log_warn "⚠️ Omitiendo mutación de overlay local: este repo no contiene devops/k8s/overlays/local."
        fi
    fi
    # T52: el tag final debe apuntar al ref real de local (post-overlay/estrategia).
    tag_target_sha="$(git rev-parse "refs/heads/${local_branch}" 2>/dev/null || git rev-parse HEAD 2>/dev/null || true)"
    [[ -n "${tag_target_sha:-}" ]] || die "No pude resolver HEAD de local para tag final."
    final_tag="$(promote_local_ensure_tag_matches_head_or_bump "$final_tag" "$tag_target_sha")" \
        || die "No pude ajustar tag final para el HEAD post-overlay."
    gitops_revision="$(promote_local_resolve_gitops_revision "$final_tag")"
    [[ -n "${gitops_revision:-}" ]] || gitops_revision="local"
    log_info "🎯 Tag target final (ref local post-overlay): ${tag_target_sha:0:7}"
    log_info "🏷️ Tag final post-overlay: ${final_tag}"

    local remote_tag_check_rc=2
    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_warn "⚗️ DRY-RUN: omito verificación remota de colisión de tag (${final_tag})."
    elif declare -F promote_tag_exists_remote >/dev/null 2>&1; then
        if promote_tag_exists_remote "$final_tag" "origin"; then
            local remote_tag_sha=""
            remote_tag_sha="$(promote_local_remote_tag_sha_or_empty "$final_tag" "origin")"
            if [[ -n "${remote_tag_sha:-}" && "${remote_tag_sha}" == "${tag_target_sha}" ]]; then
                reuse_existing_tag=1
                log_warn "Tag ya existe en origin y apunta al mismo SHA: ${final_tag}. Reutilizando."
            elif [[ "${DEVTOOLS_REUSE_EXISTING_TAG:-0}" == "1" ]]; then
                reuse_existing_tag=1
                log_warn "Tag ya existe en origin: ${final_tag}. DEVTOOLS_REUSE_EXISTING_TAG=1 activo: reutilizando."
            else
                local collided_tag="${final_tag}"
                final_tag="$(promote_local_next_remote_safe_tag "${final_tag}" "${tag_target_sha}")" \
                    || die "No pude resolver un tag remoto no conflictivo partiendo de ${collided_tag}."
                if [[ "${final_tag}" == "${collided_tag}" ]]; then
                    die "Tag ya existe en origin: ${final_tag}"
                fi
                log_warn "Tag ${collided_tag} ya existe en origin con otro SHA. Se usará ${final_tag}."
            fi
        else
            remote_tag_check_rc=$?
            if [[ "$remote_tag_check_rc" -eq 2 ]]; then
                if [[ "${DEVTOOLS_PROMOTE_OFFLINE_OK:-0}" == "1" || "${DEVTOOLS_PROMOTE_OFFLINE:-0}" == "1" ]]; then
                    log_warn "No pude verificar ${final_tag} en origin. OFFLINE activo: usando fallback local."
                else
                    die "No pude verificar ${final_tag} en origin y OFFLINE no está permitido."
                fi
            fi
        fi
    fi

    # Prepare tag local + verificación anti-regresión (sin side-effects remotos).
    if [[ "${tag_owner}" == "GitHub" ]]; then
        log_info "Checkpoint: tag local omitido (owner GitHub)."
    elif [[ "$reuse_existing_tag" -eq 1 ]]; then
        log_info "Checkpoint: tag local reutilizado (${final_tag})."
    else
        promote_local_maybe_create_local_tag_or_die "${final_tag}" "${tag_target_sha}"
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            log_info "Checkpoint: tag local omitido por DRY_RUN."
        else
            if [[ "$local_has_overlay" -eq 1 ]]; then
                promote_local_verify_tag_points_to_overlay_or_die "$final_tag" "$tag_target_sha" "$overlay_file" "$DOCKER_TAG"
            else
                log_warn "⚠️ Omitiendo verificación tag/overlay: no existe overlay local en este repo."
            fi
        fi
    fi

    # Deploy + smoke (si existen los tasks)
    if ! promote_local_deploy_and_smoke_if_available; then
        promote_local_rollback_before_push "falló deploy/smoke"
        if [[ "$return_to_source" == "1" ]]; then
            git checkout "$source_branch" >/dev/null 2>&1 || true
        fi
        die "Deploy/Smoke local falló."
    fi
    log_info "Checkpoint: smoke ok"

    # Captura de estado inicial remoto para rollback best-effort.
    old_origin_local_sha="$(promote_local_remote_branch_sha_best_effort "origin" "${local_branch}")"
    if ! promote_local_is_protected_branch "$source_branch"; then
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            log_warn "⚗️ DRY-RUN: omito preflight de ArgoCD previo a publish."
        else
            if ! promote_local_preflight_argocd_or_die "$argocd_app"; then
                die "Preflight ArgoCD falló antes de publish (sin side-effects remotos)."
            fi
            old_argocd_revision="$(promote_local_argocd_revision_best_effort "$argocd_app")"
        fi
    fi

    log_info "Checkpoint: ready-to-publish (sin side-effects remotos pendientes)."
    log_info "🚀 FASE PUBLISH: side-effects remotos (origin/local, tags, ArgoCD)."

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        argocd_sync_skipped=1
        log_warn "⚗️ DRY-RUN: publish remoto omitido (sin push de local, sin push de tags y sin ArgoCD)."
        log_info "Checkpoint: publish remoto omitido por DRY_RUN"
    else
        if ! promote_local_push_branch_force_or_die "$local_branch" "origin"; then
            promote_local_rollback_before_push "falló push final"
            if [[ "$return_to_source" == "1" ]]; then
                git checkout "$source_branch" >/dev/null 2>&1 || true
            fi
            die "No pude empujar a origin/${local_branch}."
        fi
        pushed_local=1
        log_info "Checkpoint: pushed local"

        # Requisito GitOps/tag: side-effects remotos posteriores al push de local.
        if [[ "${tag_owner}" == "GitHub" ]]; then
            log_info "Checkpoint: tag remoto omitido (owner GitHub)."
        else
            if ! promote_local_ensure_tag_remote_or_die "$final_tag" "$tag_target_sha"; then
                promote_local_rollback_after_publish_best_effort "falló push de tag remoto"
                return 2
            fi
            pushed_tag=1
            log_info "Checkpoint: tag pusheado (${final_tag})"
            if [[ "$local_has_overlay" -eq 1 ]]; then
                promote_local_verify_tag_points_to_overlay_or_die "$final_tag" "$tag_target_sha" "$overlay_file" "$DOCKER_TAG"
            else
                log_warn "⚠️ Omitiendo verificación tag/overlay: no existe overlay local en este repo."
            fi
        fi

        if ! promote_local_is_protected_branch "$source_branch"; then
            argocd_changed=1
            if ! promote_local_argocd_sync_by_tag_or_die "$gitops_revision" "$argocd_app" "${DEVTOOLS_ARGOCD_WAIT_TIMEOUT:-300}"; then
                promote_local_rollback_after_publish_best_effort "falló sync ArgoCD por tag"
                return 2
            fi
            argocd_sync_skipped="${PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED:-0}"
            if [[ "${argocd_sync_skipped}" == "1" ]]; then
                log_warn "Checkpoint: argocd sync omitido (argocd_sync_skipped=1)."
            else
                if ! ( promote_local_argocd_wait_healthy_or_die ); then
                    promote_local_rollback_after_publish_best_effort "falló wait ArgoCD (Healthy/Synced)"
                    return 2
                fi
                log_info "Checkpoint: argocd set/sync a ${gitops_revision}"
                log_info "Checkpoint: argocd healthy/synced"
            fi
        fi

        if [[ "${DEVTOOLS_E2E_ARGOCD_STRICT:-0}" == "1" ]]; then
            if ! ( promote_local_report_pull_errors_or_die "$DOCKER_TAG" ); then
                promote_local_rollback_after_publish_best_effort "fallaron post-checks estrictos de imagen/pods"
                return 2
            fi
        else
            if ! promote_local_report_pull_errors_or_die "$DOCKER_TAG"; then
                log_warn "Post-sync detectó errores de pods/imagenes, pero DEVTOOLS_E2E_ARGOCD_STRICT!=1: continúo."
            fi
        fi
        log_info "Checkpoint: sin errores post-sync de imagen/contenedor"
    fi

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        log_info "Checkpoint: limpieza de rama omitida por DRY_RUN."
    fi

    if [[ "$gate_ok" -eq 1 ]]; then
        if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
            log_info "📌 Resultado final: SUCCESS (mode=dry-run, pushed_local=${pushed_local}, pushed_tag=${pushed_tag}, argocd_changed=${argocd_changed}, argocd_sync_skipped=${argocd_sync_skipped})."
            log_success "✅ Promoción local completada (DRY-RUN)."
        elif [[ "$pushed_local" -eq 1 ]]; then
            log_info "📌 Resultado final: SUCCESS (prepare + publish completados, pushed_local=${pushed_local}, pushed_tag=${pushed_tag}, argocd_changed=${argocd_changed}, argocd_sync_skipped=${argocd_sync_skipped})."
            log_success "✅ Promoción local completada."
        fi
    fi
}

#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_update_kustomize_tag() {
    local file="$1"
    local tag="$2"

    [[ -f "$file" ]] || die "No existe el overlay local: $file"

    # GNU sed vs BSD sed
    if sed --version >/dev/null 2>&1; then
        sed -i -E "s/(newTag:).*/\\1 ${tag}/" "$file"
    else
        sed -i '' -E "s/(newTag:).*/\\1 ${tag}/" "$file"
    fi
}



promote_local_update_kustomize_newnames() {
    local file="$1"
    local backend_newname="$2"
    local frontend_newname="$3"
    local backend_escaped=""
    local frontend_escaped=""

    [[ -f "$file" ]] || die "No existe el overlay local: $file"

    backend_escaped="$(printf '%s' "$backend_newname" | sed -E 's/[&|]/\\&/g')"
    frontend_escaped="$(printf '%s' "$frontend_newname" | sed -E 's/[&|]/\\&/g')"

    # GNU sed vs BSD sed
    if sed --version >/dev/null 2>&1; then
        sed -i -E \
            -e "/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*backend[[:space:]]*$/ { n; s|^[[:space:]]*newName:[[:space:]]*.*$|    newName: ${backend_escaped}|; }" \
            -e "/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*frontend[[:space:]]*$/ { n; s|^[[:space:]]*newName:[[:space:]]*.*$|    newName: ${frontend_escaped}|; }" \
            "$file"
    else
        sed -i '' -E \
            -e "/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*backend[[:space:]]*$/ { n; s|^[[:space:]]*newName:[[:space:]]*.*$|    newName: ${backend_escaped}|; }" \
            -e "/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*frontend[[:space:]]*$/ { n; s|^[[:space:]]*newName:[[:space:]]*.*$|    newName: ${frontend_escaped}|; }" \
            "$file"
    fi
}



promote_local_verify_overlay_image_settings_or_die() {
    local file="$1"
    local backend_expected="$2"
    local frontend_expected="$3"
    local tag_expected="$4"

    [[ -f "$file" ]] || die "No existe el overlay local: $file"

    local backend_current=""
    local frontend_current=""
    local tag_current=""

    backend_current="$(awk '/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*backend[[:space:]]*$/ { f=1; next } f && /^[[:space:]]*newName:[[:space:]]*/ { print $2; exit }' "$file")"
    frontend_current="$(awk '/^[[:space:]]*-[[:space:]]*name:[[:space:]]+[^[:space:]#]*frontend[[:space:]]*$/ { f=1; next } f && /^[[:space:]]*newName:[[:space:]]*/ { print $2; exit }' "$file")"
    tag_current="$(promote_local_read_overlay_tag_from_text < "$file" 2>/dev/null || true)"

    [[ "${backend_current:-}" == "${backend_expected:-}" ]] \
        || die "Overlay local inválido: newName backend='${backend_current:-<vacío>}' (esperado '${backend_expected}')."
    [[ "${frontend_current:-}" == "${frontend_expected:-}" ]] \
        || die "Overlay local inválido: newName frontend='${frontend_current:-<vacío>}' (esperado '${frontend_expected}')."
    [[ "${tag_current:-}" == "${tag_expected:-}" ]] \
        || die "Overlay local inválido: newTag='${tag_current:-<vacío>}' (esperado '${tag_expected}')."
}



promote_local_log_render_hints() {
    local rendered_text="$1"
    local backend_img frontend_img
    backend_img="$(__promote_local_backend_image_name 2>/dev/null || true)"
    frontend_img="$(__promote_local_frontend_image_name 2>/dev/null || true)"
    local hint_pattern='^[[:space:]]*(-[[:space:]]*)?image:|^[[:space:]]*name:[[:space:]].*(frontend|backend)'
    if [[ -n "$backend_img" ]]; then
        hint_pattern="${hint_pattern}|${backend_img}"
    fi
    if [[ -n "$frontend_img" ]]; then
        hint_pattern="${hint_pattern}|${frontend_img}"
    fi
    local hints=""
    hints="$(printf '%s\n' "$rendered_text" \
        | grep -nE "$hint_pattern" \
        | head -n 20 || true)"
    if [[ -n "${hints:-}" ]]; then
        log_warn "🧾 Pistas del render (top 20):"
        while IFS= read -r line; do
            log_warn "   ${line}"
        done <<< "$hints"
    else
        log_warn "🧾 Pistas del render: sin coincidencias de image/name para frontend/backend."
    fi
}



promote_local_verify_rendered_tags_or_die() {
    local overlay_dir="$1"
    local expected_tag="$2"

    [[ -d "$overlay_dir" ]] || die "No existe overlay local para render: $overlay_dir"

    local rendered=""
    if command -v kustomize >/dev/null 2>&1; then
        rendered="$(kustomize build "$overlay_dir" 2>/dev/null)" \
            || die "No pude renderizar manifiestos con kustomize build ($overlay_dir)."
    elif command -v kubectl >/dev/null 2>&1; then
        rendered="$(kubectl kustomize "$overlay_dir" 2>/dev/null)" \
            || die "No pude renderizar manifiestos con kubectl kustomize ($overlay_dir)."
    else
        die "No existe kustomize ni kubectl para verificar drift de tags."
    fi

    local backend_image=""
    local frontend_image=""
    local rendered_images=""
    local rendered_images_count="0"
    local expected_backend expected_frontend
    expected_backend="$(__promote_local_backend_image_name)"
    expected_frontend="$(__promote_local_frontend_image_name)"
    log_info "🔎 GitOps render: ${overlay_dir}"
    log_info "🎯 Esperadas: backend=${expected_backend} frontend=${expected_frontend} tag=${expected_tag}"
    rendered_images="$(printf '%s\n' "$rendered" \
        | sed -nE 's/^[[:space:]]*(-[[:space:]]*)?image:[[:space:]]*"?([^"[:space:]]+)"?.*$/\2/p')"
    rendered_images_count="$(printf '%s\n' "$rendered_images" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"
    log_info "🔍 Imágenes detectadas en render: ${rendered_images_count}"

    backend_image="$(printf '%s\n' "$rendered_images" \
        | awk -v expected="${expected_backend}:" '($0 ~ /(^|\/)backend:/ || index($0, expected) > 0) { print; exit }')"
    frontend_image="$(printf '%s\n' "$rendered_images" \
        | awk -v expected="${expected_frontend}:" '($0 ~ /(^|\/)frontend:/ || index($0, expected) > 0) { print; exit }')"

    if [[ -z "${backend_image:-}" ]]; then
        log_error "⛔ ABORTADO (seguridad): backend no aparece en render de ${overlay_dir}."
        log_error "📍 Paso que falló: verify_rendered_tags/backend_lookup"
        promote_local_log_render_hints "$rendered"
        die "No encontré imagen backend en render de ${overlay_dir}."
    fi
    if [[ -z "${frontend_image:-}" ]]; then
        log_error "⛔ ABORTADO (seguridad): frontend no aparece en render de ${overlay_dir}."
        log_error "📍 Paso que falló: verify_rendered_tags/frontend_lookup"
        promote_local_log_render_hints "$rendered"
        die "No encontré imagen frontend en render de ${overlay_dir}."
    fi

    log_info "✅ Encontradas en render: backend=${backend_image} frontend=${frontend_image}"

    if [[ "${backend_image}" != *":${expected_tag}" ]]; then
        log_error "⛔ ABORTADO (seguridad): tag backend no coincide."
        log_error "📍 Paso que falló: verify_rendered_tags/backend_tag_match"
        promote_local_log_render_hints "$rendered"
        die "Tag drift backend: render='${backend_image}', esperado '*:${expected_tag}'."
    fi
    if [[ "${frontend_image}" != *":${expected_tag}" ]]; then
        log_error "⛔ ABORTADO (seguridad): tag frontend no coincide."
        log_error "📍 Paso que falló: verify_rendered_tags/frontend_tag_match"
        promote_local_log_render_hints "$rendered"
        die "Tag drift frontend: render='${frontend_image}', esperado '*:${expected_tag}'."
    fi
    log_info "✅ Render validado: backend/frontend con tag esperado (${expected_tag})."
}



promote_local_pull_policy() {
    local requested="${DEVTOOLS_LOCAL_PULL_POLICY:-}"
    case "$requested" in
        "")
            echo "IfNotPresent"
            return 0
            ;;
        Never)
            echo "⚠️ DEVTOOLS_LOCAL_PULL_POLICY=Never activo: si no hiciste build/load tendrás ImagePullBackOff." >&2
            echo "Never"
            return 0
            ;;
        *)
            echo "⚠️ DEVTOOLS_LOCAL_PULL_POLICY='${requested}' inválido. Usando IfNotPresent." >&2
            echo "IfNotPresent"
            return 0
            ;;
    esac
}



promote_local_update_pull_policy_patch() {
    local file="$1"
    local policy="$2"

    [[ -f "$file" ]] || die "No existe patch de imagePullPolicy: $file"

    # GNU sed vs BSD sed
    if sed --version >/dev/null 2>&1; then
        sed -i -E "s/(imagePullPolicy:).*/\\1 ${policy}/" "$file"
    else
        sed -i '' -E "s/(imagePullPolicy:).*/\\1 ${policy}/" "$file"
    fi
}



promote_local_apply_pull_policy_overrides() {
    local policy="$1"
    local backend_patch="devops/k8s/overlays/local/patch-imagepullpolicy-backend.yaml"
    local frontend_patch="devops/k8s/overlays/local/patch-imagepullpolicy-frontend.yaml"

    promote_local_update_pull_policy_patch "$backend_patch" "$policy"
    promote_local_update_pull_policy_patch "$frontend_patch" "$policy"
}



promote_local_runtime_from_context() {
    local ctx="$1"
    case "$ctx" in
        minikube) echo "minikube"; return 0 ;;
        kind) echo "kind"; return 0 ;;
        kind-*) echo "kind"; return 0 ;;
        docker-desktop) echo "docker-desktop"; return 0 ;;
    esac
    return 1
}



promote_local_minikube_running() {
    command -v minikube >/dev/null 2>&1 || return 1

    local status_json=""
    status_json="$(minikube status --output=json 2>/dev/null || true)"
    if [[ -n "${status_json:-}" ]]; then
        if echo "$status_json" | grep -Eq '"Host"[[:space:]]*:[[:space:]]*"Running"' \
            && echo "$status_json" | grep -Eq '"Kubelet"[[:space:]]*:[[:space:]]*"Running"' \
            && echo "$status_json" | grep -Eq '"APIServer"[[:space:]]*:[[:space:]]*"Running"'; then
            return 0
        fi
    fi

    local status_text=""
    status_text="$(minikube status 2>/dev/null || true)"
    if [[ -n "${status_text:-}" ]]; then
        if echo "$status_text" | grep -Eq 'host:[[:space:]]*Running' \
            && echo "$status_text" | grep -Eq 'kubelet:[[:space:]]*Running' \
            && echo "$status_text" | grep -Eq 'apiserver:[[:space:]]*Running'; then
            return 0
        fi
    fi

    return 1
}



promote_local_kind_has_clusters() {
    command -v kind >/dev/null 2>&1 || return 1
    [[ -n "$(kind get clusters 2>/dev/null || true)" ]]
}



promote_local_docker_desktop_context_active() {
    command -v docker >/dev/null 2>&1 || return 1
    local ctx=""
    ctx="$(docker context show 2>/dev/null || true)"
    [[ -n "${ctx:-}" ]] || return 1

    case "$ctx" in
        desktop-linux|docker-desktop|*desktop-linux*|*docker-desktop*)
            return 0
            ;;
    esac
    return 1
}



promote_local_kind_cluster_from_context() {
    local ctx="$1"
    if [[ "$ctx" == kind-* ]]; then
        local cluster="${ctx#kind-}"
        [[ -n "${cluster:-}" ]] || cluster="kind"
        echo "$cluster"
        return 0
    fi
    return 1
}



promote_local_kind_cluster_name() {
    if [[ -n "${DEVTOOLS_KIND_CLUSTER_NAME:-}" ]]; then
        echo "${DEVTOOLS_KIND_CLUSTER_NAME}"
        return 0
    fi

    local ctx=""
    if command -v kubectl >/dev/null 2>&1; then
        ctx="$(kubectl config current-context 2>/dev/null || true)"
    fi

    if promote_local_kind_cluster_from_context "$ctx" >/dev/null 2>&1; then
        promote_local_kind_cluster_from_context "$ctx"
        return 0
    fi

    if [[ "$ctx" == "kind" ]]; then
        command -v kind >/dev/null 2>&1 || die "Contexto actual=kind pero no existe binario 'kind'."

        local kind_count=0
        local kind_only=""
        while IFS= read -r cluster; do
            [[ -n "${cluster:-}" ]] || continue
            kind_count=$((kind_count + 1))
            if [[ "$kind_count" -eq 1 ]]; then
                kind_only="$cluster"
            fi
        done < <(kind get clusters 2>/dev/null || true)

        if [[ "$kind_count" -eq 1 ]]; then
            echo "$kind_only"
            return 0
        fi

        if [[ "$kind_count" -gt 1 ]]; then
            die "Contexto 'kind' ambiguo con ${kind_count} clusters. Define DEVTOOLS_KIND_CLUSTER_NAME o usa contexto kind-<cluster>."
        fi

        die "Contexto 'kind' activo pero no encontré clusters kind."
    fi

    if command -v kind >/dev/null 2>&1; then
        local kind_count=0
        local kind_only=""
        while IFS= read -r cluster; do
            [[ -n "${cluster:-}" ]] || continue
            kind_count=$((kind_count + 1))
            if [[ "$kind_count" -eq 1 ]]; then
                kind_only="$cluster"
            fi
        done < <(kind get clusters 2>/dev/null || true)

        if [[ "$kind_count" -eq 1 ]]; then
            echo "$kind_only"
            return 0
        fi

        if [[ "$kind_count" -gt 1 ]]; then
            die "Detecté múltiples clusters kind (${kind_count}). Define DEVTOOLS_KIND_CLUSTER_NAME o usa contexto kind-<cluster>."
        fi
    fi

    echo "kind"
    return 0
}



promote_local_detect_cluster_runtime() {
    local forced_runtime="${DEVTOOLS_LOCAL_RUNTIME:-}"

    # 1) Si viene forzado, validar y usarlo.
    if [[ -n "${forced_runtime:-}" ]]; then
        case "$forced_runtime" in
            minikube|kind|docker-desktop)
                echo "$forced_runtime"
                return 0
                ;;
            *)
                die "DEVTOOLS_LOCAL_RUNTIME inválido: '${forced_runtime}'. Usa minikube|kind|docker-desktop."
                ;;
        esac
    fi

    # 2) Autodetección por kubectl current-context (si existe)
    if command -v kubectl >/dev/null 2>&1; then
        local ctx=""
        ctx="$(kubectl config current-context 2>/dev/null || true)"
        if [[ -n "${ctx:-}" ]] && promote_local_runtime_from_context "$ctx" >/dev/null 2>&1; then
            promote_local_runtime_from_context "$ctx"
            return 0
        fi
    fi

    # 3) Heurísticas seguras
    if promote_local_minikube_running; then
        echo "minikube"
        return 0
    fi
    if promote_local_kind_has_clusters; then
        echo "kind"
        return 0
    fi
    if promote_local_docker_desktop_context_active; then
        echo "docker-desktop"
        return 0
    fi

    die "No pude autodetectar runtime local. Define DEVTOOLS_LOCAL_RUNTIME=minikube|kind|docker-desktop."
}



promote_local_ensure_cluster_runtime() {
    local out_var="${1:-}"
    local resolved_runtime=""
    resolved_runtime="$(promote_local_detect_cluster_runtime)"
    local detect_rc=$?
    if [[ "$detect_rc" -ne 0 || -z "${resolved_runtime:-}" ]]; then
        die "No pude detectar runtime local. Define DEVTOOLS_LOCAL_RUNTIME=minikube|kind|docker-desktop."
    fi

    if [[ -n "${DEVTOOLS_LOCAL_RUNTIME:-}" ]]; then
        log_info "Runtime local forzado por DEVTOOLS_LOCAL_RUNTIME=${resolved_runtime}"
    fi

    case "$resolved_runtime" in
        minikube)
            local minikube_ready=0
            if command -v detect_minikube_active >/dev/null 2>&1; then
                if detect_minikube_active; then
                    minikube_ready=1
                fi
            fi

            if [[ "$minikube_ready" -eq 1 ]]; then
                :
            elif promote_local_minikube_running; then
                minikube_ready=1
            elif task_exists "check-minikube"; then
                task check-minikube || return $?
                minikube_ready=1
            elif task_exists "cluster:up"; then
                task cluster:up || return $?
                minikube_ready=1
            else
                die "Runtime=minikube no está listo. Arranca minikube o define DEVTOOLS_LOCAL_RUNTIME=minikube."
            fi
            ;;
        kind)
            command -v kind >/dev/null 2>&1 || die "Runtime detectado=kind pero no existe el binario 'kind'."
            local kind_cluster=""
            kind_cluster="$(promote_local_kind_cluster_name)"
            kind get clusters 2>/dev/null | grep -qx "$kind_cluster" \
                || die "Runtime=kind pero no existe el cluster '${kind_cluster}'."
            ;;
        docker-desktop)
            ;;
        *)
            die "Runtime local no soportado: ${resolved_runtime}"
            ;;
    esac

    if [[ -n "${out_var:-}" ]]; then
        printf -v "$out_var" '%s' "$resolved_runtime"
        return 0
    fi

    echo "$resolved_runtime"
    return 0
}



promote_local_guard_runtime_matches_kubectl_context_or_die() {
    local runtime="$1"
    if ! command -v kubectl >/dev/null 2>&1; then
        log_warn "No existe kubectl; omito guard de contexto contra runtime."
        return 0
    fi

    local ctx=""
    ctx="$(kubectl config current-context 2>/dev/null || true)"
    [[ -n "${ctx:-}" ]] || return 0

    local expected_runtime=""
    if [[ "$ctx" == *minikube* ]]; then
        expected_runtime="minikube"
    elif [[ "$ctx" == *kind-* || "$ctx" == "kind" || "$ctx" == *kind* ]]; then
        expected_runtime="kind"
    elif [[ "$ctx" == *docker-desktop* || "$ctx" == *desktop-linux* ]]; then
        expected_runtime="docker-desktop"
    fi

    [[ -n "${expected_runtime:-}" ]] || return 0
    if [[ "${DEVTOOLS_LOCAL_RUNTIME_FORCE:-0}" == "1" ]]; then
        log_warn "Runtime/context mismatch omitido por DEVTOOLS_LOCAL_RUNTIME_FORCE=1 (ctx=${ctx}, runtime=${runtime}, esperado=${expected_runtime})."
        return 0
    fi
    if [[ "$runtime" != "$expected_runtime" ]]; then
        die "Runtime/context mismatch: kubectl context='${ctx}' => esperado='${expected_runtime}', pero DEVTOOLS_LOCAL_RUNTIME='${runtime}'. Usa DEVTOOLS_LOCAL_RUNTIME_FORCE=1 para forzar."
    fi
}



promote_local_deploy_and_smoke_if_available() {
    promote_local_run_smoke() {
        local smoke_task="$1"
        local rc=0

        log_info "Smoke local: task ${smoke_task}"
        set +e
        task -x "${smoke_task}"
        rc=$?
        set -e

        if [[ "$rc" -eq 2 || "$rc" -eq 201 ]]; then
            log_warn "Smoke omitido: no hay listener local (gateway/túnel)."
            echo "   Modo Compose: task local:gateway:up"
            echo "   Modo K8s/Minikube: task cluster:connect"
            echo "   Luego: task local:smoke"
            return 0
        fi

        [[ "$rc" -eq 0 ]] || return "$rc"
        return 0
    }

    # Opcional: solo corre si existen los tasks
    if task_exists "pipeline:deploy:local"; then
        log_info "Deploy local: task pipeline:deploy:local"
        task pipeline:deploy:local || return 1
    elif task_exists "deploy:local"; then
        log_info "Deploy local: task deploy:local"
        task deploy:local || return 1
    else
        log_warn "No hay task de deploy local (pipeline:deploy:local/deploy:local). Omitiendo."
        return 0
    fi

    if task_exists "local:smoke"; then
        promote_local_run_smoke "local:smoke" || return 1
    elif task_exists "smoke:local"; then
        promote_local_run_smoke "smoke:local" || return 1
    else
        log_warn "No hay task de smoke local (local:smoke/smoke:local). Omitiendo."
        return 0
    fi
}



promote_local_kind_nodes() {
    local cluster="$1"

    if command -v kind >/dev/null 2>&1; then
        local nodes=""
        nodes="$(kind get nodes --name "$cluster" 2>/dev/null || true)"
        if [[ -n "${nodes:-}" ]]; then
            printf '%s\n' "$nodes"
            return 0
        fi
    fi

    if command -v docker >/dev/null 2>&1; then
        docker ps --format '{{.Names}}' 2>/dev/null \
            | grep -E "^${cluster}-(control-plane|worker([0-9]+)?)$" || true
    fi
}



promote_local_kind_node_images() {
    local node="$1"

    command -v docker >/dev/null 2>&1 || return 1

    if docker exec "$node" sh -lc "command -v crictl >/dev/null 2>&1"; then
        docker exec "$node" crictl images 2>/dev/null || return 1
        return 0
    fi

    if docker exec "$node" sh -lc "command -v ctr >/dev/null 2>&1"; then
        docker exec "$node" ctr -n k8s.io images ls 2>/dev/null || return 1
        return 0
    fi

    return 1
}



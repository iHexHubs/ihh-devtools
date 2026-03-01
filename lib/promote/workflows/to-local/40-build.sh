#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

promote_local_docker_image_exists() {
    local image_ref="$1"
    command -v docker >/dev/null 2>&1 || return 1
    docker image inspect "${image_ref}" >/dev/null 2>&1
}



promote_local_push_images_to_local_registry_or_die() {
    local registry_prefix="$1"
    local image_tag="$2"
    registry_prefix="${registry_prefix%/}"
    [[ -n "${registry_prefix:-}" ]] || die "Registry local activo pero vacío tras sanitización."
    local backend_src="pmbok-backend:${image_tag}"
    local frontend_src="pmbok-frontend:${image_tag}"
    local backend_dst="${registry_prefix}/backend:${image_tag}"
    local frontend_dst="${registry_prefix}/frontend:${image_tag}"

    command -v docker >/dev/null 2>&1 || die "Registry local activo pero no existe binario 'docker'."

    if ! promote_local_docker_image_exists "$backend_src"; then
        log_warn "No encontré ${backend_src} en docker local. Recompilando backend para push a registry..."
        promote_local_build_image_with_docker "pmbok-backend" "$image_tag" "backend" \
            || die "No pude preparar imagen backend para push a registry local."
    fi
    if ! promote_local_docker_image_exists "$frontend_src"; then
        log_warn "No encontré ${frontend_src} en docker local. Recompilando frontend para push a registry..."
        promote_local_build_image_with_docker "pmbok-frontend" "$image_tag" "frontend" \
            || die "No pude preparar imagen frontend para push a registry local."
    fi

    log_info "Registry local activo: ${registry_prefix}"
    log_info "Registry prefix final: ${registry_prefix}"
    log_info "Pushing ${backend_dst}"
    docker tag "${backend_src}" "${backend_dst}" || die "No pude taggear ${backend_dst}."
    docker push "${backend_dst}" || die "No pude push ${backend_dst}."
    log_info "OK push ${backend_dst}"

    log_info "Pushing ${frontend_dst}"
    docker tag "${frontend_src}" "${frontend_dst}" || die "No pude taggear ${frontend_dst}."
    docker push "${frontend_dst}" || die "No pude push ${frontend_dst}."
    log_info "OK push ${frontend_dst}"
}



promote_local_frontend_permissions_guard() {
    local node_modules="apps/pmbok/frontend/node_modules"
    [[ -d "$node_modules" ]] || return 0

    local uid=""
    if stat -c %u "$node_modules" >/dev/null 2>&1; then
        uid="$(stat -c %u "$node_modules")"
    elif stat -f %u "$node_modules" >/dev/null 2>&1; then
        uid="$(stat -f %u "$node_modules")"
    fi

    if [[ "$uid" == "0" ]]; then
        log_error "❌ node_modules en frontend es root. Esto rompe npm ci."
        echo "   Solucion recomendada:" >&2
        echo "   - sudo chown -R $(id -u):$(id -g) ${node_modules}" >&2
        echo "   - (opcional) borrar y reinstalar: sudo rm -rf ${node_modules} && (cd apps/pmbok/frontend && npm ci)" >&2
        return 1
    fi

    return 0
}



promote_local_component_build_context() {
    local component="$1"
    case "$component" in
        backend) echo "apps/pmbok/backend" ;;
        frontend) echo "apps/pmbok/frontend" ;;
        *) return 1 ;;
    esac
}



promote_local_build_image_with_docker() {
    local image="$1"
    local tag="$2"
    local component="$3"

    command -v docker >/dev/null 2>&1 || die "No encontré docker para compilar imágenes locales."

    local context_dir=""
    context_dir="$(promote_local_component_build_context "$component")" || die "Componente inválido para build: ${component}"
    [[ -f "${context_dir}/Dockerfile" ]] || die "No existe Dockerfile en ${context_dir}"

    log_info "Build local (docker): ${image}:${tag}"
    (cd "$context_dir" && docker build -t "${image}:${tag}" -f Dockerfile .)
}



promote_local_load_image_to_runtime() {
    local runtime="$1"
    local image_ref="$2"

    case "$runtime" in
        minikube)
            command -v minikube >/dev/null 2>&1 || die "Runtime=minikube pero no existe binario 'minikube'."
            log_info "Load en minikube: ${image_ref}"
            minikube image load "${image_ref}"
            return $?
            ;;
        kind)
            command -v kind >/dev/null 2>&1 || die "Runtime=kind pero no existe binario 'kind'."
            local cluster=""
            cluster="$(promote_local_kind_cluster_name)"
            log_info "Load en kind (${cluster}): ${image_ref}"
            kind load docker-image "${image_ref}" --name "${cluster}"
            return $?
            ;;
        docker-desktop)
            log_info "Runtime docker-desktop: no requiere load explícito (${image_ref})."
            return 0
            ;;
    esac

    die "Runtime no soportado para load de imagen: ${runtime}"
}



promote_local_build_and_load_image() {
    local runtime="$1"
    local component="$2"
    local tag="$3"
    local image="pmbok-${component}"

    if [[ "$runtime" == "minikube" ]]; then
        log_info "Build local (minikube task): ${image}:${tag}"
        TAG="$tag" ONLY_APP="$component" task build:local
        return $?
    fi

    promote_local_build_image_with_docker "$image" "$tag" "$component" || return 1
    promote_local_load_image_to_runtime "$runtime" "${image}:${tag}" || return 1
    return 0
}



promote_local_image_present_in_runtime() {
    local runtime="$1"
    local image="$2"
    local tag="$3"
    local image_ref="${image}:${tag}"

    case "$runtime" in
        minikube)
            command -v minikube >/dev/null 2>&1 || return 1
            minikube image ls 2>/dev/null | grep -F "${image_ref}" >/dev/null 2>&1 \
                || return 1
            return 0
            ;;
        kind)
            local cluster=""
            cluster="$(promote_local_kind_cluster_name)"
            local kind_nodes=""
            kind_nodes="$(promote_local_kind_nodes "$cluster")"
            [[ -n "${kind_nodes:-}" ]] || return 1

            local node=""
            while IFS= read -r node; do
                [[ -n "${node:-}" ]] || continue
                promote_local_kind_node_images "$node" 2>/dev/null \
                    | grep -F "${image}" \
                    | grep -F "${tag}" >/dev/null 2>&1 \
                    || return 1
            done <<< "$kind_nodes"
            return 0
            ;;
        docker-desktop)
            command -v docker >/dev/null 2>&1 || return 1
            docker image inspect "${image_ref}" >/dev/null 2>&1 || return 1
            return 0
            ;;
    esac

    return 2
}



promote_local_assert_image_present_in_runtime() {
    local runtime="$1"
    local image="$2"
    local tag="$3"
    local image_ref="${image}:${tag}"

    promote_local_image_present_in_runtime "$runtime" "$image" "$tag" \
        || die "Imagen faltante: ${image_ref} -> ejecuta promote local (build/load)"
    return 0
}



promote_local_ensure_image_in_runtime_or_die() {
    local runtime="$1"
    local image="$2"
    local tag="$3"
    local image_ref="${image}:${tag}"

    if promote_local_image_present_in_runtime "$runtime" "$image" "$tag"; then
        return 0
    fi

    case "$runtime" in
        minikube|kind)
            log_warn "Imagen faltante en runtime (${runtime}): ${image_ref}. Intentando auto-carga."
            command -v docker >/dev/null 2>&1 || die "No existe 'docker' para auto-cargar ${image_ref} en ${runtime}."
            promote_local_docker_image_exists "${image_ref}" \
                || die "Imagen faltante en Docker local: ${image_ref}. Recompila/retag antes de promote local."

            promote_local_load_image_to_runtime "$runtime" "${image_ref}" \
                || die "Falló auto-carga de ${image_ref} en runtime=${runtime}."
            promote_local_image_present_in_runtime "$runtime" "$image" "$tag" \
                || die "La imagen sigue faltando tras auto-carga: ${image_ref} (runtime=${runtime})."
            log_info "Auto-carga OK en runtime (${runtime}): ${image_ref}"
            return 0
            ;;
        docker-desktop)
            command -v docker >/dev/null 2>&1 || die "Runtime=docker-desktop pero no existe binario 'docker'."
            docker info >/dev/null 2>&1 || die "Runtime=docker-desktop no disponible (docker info falló)."
            local docker_ctx=""
            docker_ctx="$(docker context show 2>/dev/null || true)"
            [[ -n "${docker_ctx:-}" ]] || die "No pude resolver docker context actual."
            promote_local_docker_image_exists "${image_ref}" \
                || die "Imagen faltante en docker-desktop: ${image_ref}. Recompila antes de promote local."
            log_info "Runtime docker-desktop verificado (contexto: ${docker_ctx})."
            return 0
            ;;
    esac

    die "Runtime no soportado en preflight de imágenes: ${runtime}"
}



promote_local_preflight_images_or_die() {
    local runtime="$1"
    local tag="$2"

    log_info "Preflight imágenes runtime=${runtime}, tag=${tag}"
    promote_local_ensure_image_in_runtime_or_die "$runtime" "pmbok-backend" "$tag"
    promote_local_ensure_image_in_runtime_or_die "$runtime" "pmbok-frontend" "$tag"
    log_info "Checkpoint: preflight imágenes ok"
}



promote_local_retag_or_build() {
    local runtime="$1"
    local component="$2"   # backend|frontend
    local src_tag="$3"
    local dst_tag="$4"
    local image="pmbok-${component}"

    if command -v docker >/dev/null 2>&1 && docker image inspect "${image}:${src_tag}" >/dev/null 2>&1; then
        docker tag "${image}:${src_tag}" "${image}:${dst_tag}" || return 1
        promote_local_load_image_to_runtime "$runtime" "${image}:${dst_tag}" || return 1
        log_info "Retag/load OK: ${image}:${src_tag} -> ${image}:${dst_tag} (${runtime})"
        return 0
    fi

    log_warn "No encontré ${image}:${src_tag} para retag. Recompilando ${component}..."
    promote_local_build_and_load_image "$runtime" "$component" "$dst_tag"
}



promote_local_preflight_docker_or_die() {
    if declare -F promote_preflight_docker_or_die >/dev/null 2>&1; then
        promote_preflight_docker_or_die
        return $?
    fi

    if ! command -v docker >/dev/null 2>&1 || ! docker ps >/dev/null 2>&1; then
        log_error "❌ Docker no está listo. Enciende Docker daemon/Docker Desktop o sudo systemctl start docker"
        return 2
    fi
    return 0
}



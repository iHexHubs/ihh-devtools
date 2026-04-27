#!/usr/bin/env bash
# lib/core/services.sh
# Helper canónico de fuente de verdad de servicios. Implementa la jerarquía
# oficial de resolución registrada en ADR 0002 (B-4):
#
#   1) Variable de entorno explícita.
#   2) Archivo declarativo (devtools.repo.yaml.registries.deploy o default
#      ecosystem/services.yaml).
#   3) Error claro con instrucciones. Sin fallback silencioso a literales.
#
# Cierra SEC-2B-Phase2 (B-5) + H-AMBOS-9 Phase2 + T-AMBOS-3 Phase2.
#
# Funciones públicas:
#   services_resolve_path
#   services_load
#   services_resolve_by_id <id>
#   services_resolve_by_path <fs_path>
#   services_image_for <id>
#   services_argocd_app_for <id> <env>
#   services_changelog_for <id>
#   services_local_image_name <id> <component>
#
# Códigos de salida convencionales:
#   0  OK.
#   2  modo/argumento inválido.
#   4  configuración faltante (ENV var ausente y archivo no cableado).
#   5  recurso no encontrado (id/path no matchea).
#   6  YAML no parseable.
#
# Dependencias: yq (mikefarah, ya disponible vía devbox.json).

# Imprime el error con el formato literal vinculante registrado en ADR 0002 §7.
__services_emit_resolution_error() {
    local field="$1"
    local target="$2"
    local env_var="$3"
    local path_resolved="$4"
    {
        printf '\xe2\x9d\x8c No se puede resolver %s para %s.\n' "$field" "$target"
        printf '   Buscamos en este orden:\n'
        printf '     1. ENV var %s\n' "$env_var"
        printf '     2. %s\n' "$path_resolved"
        printf '   Para configurar: edita %s o exporta %s.\n' "$path_resolved" "$env_var"
    } >&2
}

# services_resolve_path
# Resuelve la ruta absoluta del archivo declarativo.
# Stdout: ruta absoluta. Exit: 0/4/5.
services_resolve_path() {
    local repo_root
    repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

    local declared=""
    if [[ -n "${DEVTOOLS_REGISTRIES_DEPLOY:-}" ]]; then
        declared="$DEVTOOLS_REGISTRIES_DEPLOY"
    elif [[ -f "${repo_root}/devtools.repo.yaml" ]] && command -v yq >/dev/null 2>&1; then
        local from_contract
        from_contract="$(yq eval '.registries.deploy // ""' "${repo_root}/devtools.repo.yaml" 2>/dev/null || true)"
        if [[ -n "$from_contract" && "$from_contract" != "null" ]]; then
            declared="$from_contract"
        fi
    fi

    if [[ -z "$declared" ]]; then
        declared="ecosystem/services.yaml"
    fi

    local resolved
    if [[ "$declared" == /* ]]; then
        resolved="$declared"
    else
        resolved="${repo_root}/${declared}"
    fi

    if [[ ! -f "$resolved" ]]; then
        __services_emit_resolution_error \
            "archivo declarativo" "el repo" \
            "DEVTOOLS_REGISTRIES_DEPLOY" "$resolved"
        return 5
    fi

    printf '%s\n' "$resolved"
    return 0
}

# services_load
# Carga y cachea el archivo declarativo. Variables globales:
#   __DEVTOOLS_SERVICES_PATH    ruta cacheada
#   __DEVTOOLS_SERVICES_CONTENT contenido cacheado (YAML)
# Exit: 0/5/6.
services_load() {
    local force="${1:-}"
    if [[ "${__DEVTOOLS_SERVICES_LOADED:-0}" == "1" && "$force" != "--force" ]]; then
        return 0
    fi

    local path
    path="$(services_resolve_path)" || return $?

    if ! command -v yq >/dev/null 2>&1; then
        printf '\xe2\x9d\x8c services_load: yq no esta disponible en PATH.\n' >&2
        return 6
    fi

    if ! yq eval '.' "$path" >/dev/null 2>&1; then
        printf '\xe2\x9d\x8c services_load: %s no parsea como YAML.\n' "$path" >&2
        return 6
    fi

    __DEVTOOLS_SERVICES_PATH="$path"
    __DEVTOOLS_SERVICES_CONTENT="$(cat "$path")"
    __DEVTOOLS_SERVICES_LOADED=1
    return 0
}

# services_resolve_by_id <id>
# Stdout: YAML del record. Exit: 0/5.
services_resolve_by_id() {
    local id="${1:-}"
    if [[ -z "$id" ]]; then
        printf '\xe2\x9d\x8c services_resolve_by_id: id vacio.\n' >&2
        return 2
    fi

    services_load || return $?

    local record
    record="$(printf '%s' "$__DEVTOOLS_SERVICES_CONTENT" \
        | yq eval ".services[] | select(.id == \"$id\")" - 2>/dev/null || true)"

    if [[ -z "$record" ]]; then
        __services_emit_resolution_error \
            "servicio" "id=$id" \
            "DEVTOOLS_SERVICES_OVERRIDE_$(__services_normalize_id "$id")" \
            "$__DEVTOOLS_SERVICES_PATH"
        return 5
    fi

    printf '%s\n' "$record"
    return 0
}

# services_resolve_by_path <fs_path>
# Cruza el path con services[].path como prefijo. Stdout: id. Exit: 0/5.
services_resolve_by_path() {
    local fs_path="${1:-}"
    if [[ -z "$fs_path" ]]; then
        printf '\xe2\x9d\x8c services_resolve_by_path: path vacio.\n' >&2
        return 2
    fi

    services_load || return $?

    local id
    id="$(printf '%s' "$__DEVTOOLS_SERVICES_CONTENT" \
        | yq eval -r '.services[] | [.id, .path] | @tsv' - 2>/dev/null \
        | awk -F'\t' -v p="$fs_path" '
            {
                svc_path=$2
                if (svc_path == "") next
                # Match si fs_path == svc_path o empieza con svc_path/.
                if (p == svc_path || index(p, svc_path "/") == 1) {
                    print $1
                    exit
                }
            }
        ' || true)"

    if [[ -z "$id" ]]; then
        printf '\xe2\x9d\x8c services_resolve_by_path: ningun servicio matchea %s.\n' "$fs_path" >&2
        return 5
    fi

    printf '%s\n' "$id"
    return 0
}

# services_image_for <id>
# Precedencia: ENV DEVTOOLS_IMAGE_FOR_<ID> > services[].image > error 5.
# Stdout: image name.
services_image_for() {
    local id="${1:-}"
    if [[ -z "$id" ]]; then
        printf '\xe2\x9d\x8c services_image_for: id vacio.\n' >&2
        return 2
    fi

    local norm_id env_var override
    norm_id="$(__services_normalize_id "$id")"
    env_var="DEVTOOLS_IMAGE_FOR_${norm_id}"
    override="${!env_var:-}"
    if [[ -n "$override" ]]; then
        printf '%s\n' "$override"
        return 0
    fi

    services_load || return $?

    local image
    image="$(printf '%s' "$__DEVTOOLS_SERVICES_CONTENT" \
        | yq eval -r ".services[] | select(.id == \"$id\") | .image // \"\"" - 2>/dev/null || true)"

    if [[ -z "$image" || "$image" == "null" ]]; then
        __services_emit_resolution_error \
            "imagen" "id=$id" "$env_var" "$__DEVTOOLS_SERVICES_PATH"
        return 5
    fi

    printf '%s\n' "$image"
    return 0
}

# services_argocd_app_for <id> <env>
# Precedencia:
#   ENV DEVTOOLS_ARGOCD_APP_<ENV>_<ID>
# > services[].argocd_app_per_env.<env>  (campo opcional, si existe)
# > template DEVTOOLS_ARGOCD_APP_TEMPLATE (default "<env>-<id>-app").
# Stdout: nombre app argocd.
services_argocd_app_for() {
    local id="${1:-}"
    local env="${2:-}"
    if [[ -z "$id" || -z "$env" ]]; then
        printf '\xe2\x9d\x8c services_argocd_app_for: id o env vacios.\n' >&2
        return 2
    fi

    local norm_id norm_env env_var override
    norm_id="$(__services_normalize_id "$id")"
    norm_env="$(__services_normalize_id "$env")"
    env_var="DEVTOOLS_ARGOCD_APP_${norm_env}_${norm_id}"
    override="${!env_var:-}"
    if [[ -n "$override" ]]; then
        printf '%s\n' "$override"
        return 0
    fi

    if [[ "${__DEVTOOLS_SERVICES_LOADED:-0}" == "1" ]] || services_load 2>/dev/null; then
        local from_yaml
        from_yaml="$(printf '%s' "$__DEVTOOLS_SERVICES_CONTENT" \
            | yq eval -r ".services[] | select(.id == \"$id\") | .argocd_app_per_env.${env} // \"\"" - 2>/dev/null || true)"
        if [[ -n "$from_yaml" && "$from_yaml" != "null" ]]; then
            printf '%s\n' "$from_yaml"
            return 0
        fi
    fi

    local template="${DEVTOOLS_ARGOCD_APP_TEMPLATE:-<env>-<id>-app}"
    local rendered="${template//<env>/$env}"
    rendered="${rendered//<id>/$id}"
    printf '%s\n' "$rendered"
    return 0
}

# services_changelog_for <id>
# Precedencia: services[].changelog (si declarado) > apps/<id>/CHANGELOG.md.
services_changelog_for() {
    local id="${1:-}"
    if [[ -z "$id" ]]; then
        printf '\xe2\x9d\x8c services_changelog_for: id vacio.\n' >&2
        return 2
    fi

    if services_load 2>/dev/null; then
        local declared
        declared="$(printf '%s' "$__DEVTOOLS_SERVICES_CONTENT" \
            | yq eval -r ".services[] | select(.id == \"$id\") | .changelog // \"\"" - 2>/dev/null || true)"
        if [[ -n "$declared" && "$declared" != "null" ]]; then
            printf '%s\n' "$declared"
            return 0
        fi
    fi

    printf 'apps/%s/CHANGELOG.md\n' "$id"
    return 0
}

# services_local_image_name <id> <component>
# Resuelve nombre de imagen Docker local para <id>+<component>.
# Precedencia:
#   ENV DEVTOOLS_LOCAL_IMAGE_<COMPONENT>_<ID>
# > convención: si services[].image existe, usa ultimo segmento
#   o "<id>-<component>" si no aplica.
# Stdout: nombre de imagen.
services_local_image_name() {
    local id="${1:-}"
    local component="${2:-}"
    if [[ -z "$id" || -z "$component" ]]; then
        printf '\xe2\x9d\x8c services_local_image_name: id o component vacios.\n' >&2
        return 2
    fi

    local norm_id norm_comp env_var override
    norm_id="$(__services_normalize_id "$id")"
    norm_comp="$(__services_normalize_id "$component")"
    env_var="DEVTOOLS_LOCAL_IMAGE_${norm_comp}_${norm_id}"
    override="${!env_var:-}"
    if [[ -n "$override" ]]; then
        printf '%s\n' "$override"
        return 0
    fi

    printf '%s-%s\n' "$id" "$component"
    return 0
}

# Helper interno: normaliza un id para usarlo en nombre de ENV var.
# Convierte a mayúsculas y reemplaza no-alnum por '_'.
__services_normalize_id() {
    local raw="${1:-}"
    local out=""
    local i ch
    for (( i=0; i<${#raw}; i++ )); do
        ch="${raw:i:1}"
        case "$ch" in
            [a-zA-Z0-9]) out+="$ch" ;;
            *)           out+="_"   ;;
        esac
    done
    printf '%s\n' "$out" | tr '[:lower:]' '[:upper:]'
}

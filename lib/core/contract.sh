#!/usr/bin/env bash

devtools_strip_quotes() {
    local value="$1"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s\n' "$value"
}

devtools_trim() {
    local value="$1"
    printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

devtools_clean_yaml_value() {
    local raw="$1"
    local value=""
    value="$(devtools_trim "$raw")"
    value="${value%%[[:space:]]#*}"
    value="$(devtools_trim "$value")"
    value="$(devtools_strip_quotes "$value")"
    printf '%s\n' "$value"
}

devtools_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

devtools_resolve_path() {
    local repo_root="$1"
    local value="$2"
    local cleaned=""

    cleaned="$(devtools_clean_yaml_value "$value")"
    if [[ -z "$cleaned" ]]; then
        printf '\n'
        return 0
    fi

    if [[ "$cleaned" == /* ]]; then
        printf '%s\n' "$cleaned"
        return 0
    fi

    printf '%s/%s\n' "$repo_root" "$cleaned"
}

devtools_find_contract_file() {
    local repo_root="$1"
    local candidate=""

    if [[ -n "${DEVTOOLS_CONTRACT_FILE:-}" ]]; then
        candidate="$(devtools_resolve_path "$repo_root" "$DEVTOOLS_CONTRACT_FILE")"
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    for candidate in \
        "${repo_root}/devtools.repo.yaml" \
        "${repo_root}/devtools.yaml"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '\n'
}

devtools_parse_contract_registries() {
    local contract_file="$1"
    local build_registry_raw=""
    local deploy_registry_raw=""
    local in_registries=0
    local registries_indent=-1

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        local line="${raw_line%$'\r'}"
        local trimmed=""
        local indent_prefix=""
        local indent_len=0

        trimmed="$(devtools_trim "$line")"
        [[ -n "$trimmed" ]] || continue
        [[ "${trimmed:0:1}" == "#" ]] && continue

        indent_prefix="${line%%[![:space:]]*}"
        indent_len="${#indent_prefix}"

        if [[ "$trimmed" =~ ^registries:[[:space:]]*$ ]]; then
            in_registries=1
            registries_indent="$indent_len"
            continue
        fi

        if [[ "$in_registries" -eq 1 && "$indent_len" -le "$registries_indent" ]]; then
            in_registries=0
            registries_indent=-1
        fi

        if [[ "$trimmed" =~ ^(build_registry|apps_registry):[[:space:]]*(.*)$ ]]; then
            build_registry_raw="${BASH_REMATCH[2]}"
            continue
        fi

        if [[ "$trimmed" =~ ^(deploy_registry|services_registry):[[:space:]]*(.*)$ ]]; then
            deploy_registry_raw="${BASH_REMATCH[2]}"
            continue
        fi

        if [[ "$in_registries" -eq 1 ]]; then
            if [[ "$trimmed" =~ ^(build|apps):[[:space:]]*(.*)$ ]]; then
                build_registry_raw="${BASH_REMATCH[2]}"
                continue
            fi

            if [[ "$trimmed" =~ ^(deploy|services):[[:space:]]*(.*)$ ]]; then
                deploy_registry_raw="${BASH_REMATCH[2]}"
                continue
            fi
        fi
    done < "$contract_file"

    printf '%s\n' "$(devtools_clean_yaml_value "$build_registry_raw")"
    printf '%s\n' "$(devtools_clean_yaml_value "$deploy_registry_raw")"
}

devtools_load_contract() {
    local repo_root="${1:-}"
    local contract_file=""
    local build_registry="${DEVTOOLS_BUILD_REGISTRY:-}"
    local deploy_registry="${DEVTOOLS_DEPLOY_REGISTRY:-}"
    local parsed_build=""
    local parsed_deploy=""
    local parsed_lines=()

    if [[ -z "$repo_root" ]]; then
        repo_root="$(devtools_repo_root)"
    fi

    if [[ -n "$build_registry" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$build_registry")"
    fi

    if [[ -n "$deploy_registry" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$deploy_registry")"
    fi

    contract_file="$(devtools_find_contract_file "$repo_root")"
    if [[ -f "$contract_file" ]]; then
        mapfile -t parsed_lines < <(devtools_parse_contract_registries "$contract_file")
        parsed_build="${parsed_lines[0]:-}"
        parsed_deploy="${parsed_lines[1]:-}"
    fi

    if [[ -z "$build_registry" && -n "$parsed_build" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$parsed_build")"
    fi

    if [[ -z "$deploy_registry" && -n "$parsed_deploy" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$parsed_deploy")"
    fi

    if [[ -z "$build_registry" && -f "${repo_root}/config/apps.yaml" ]]; then
        build_registry="${repo_root}/config/apps.yaml"
    fi

    if [[ -z "$deploy_registry" && -f "${repo_root}/config/services.yaml" ]]; then
        deploy_registry="${repo_root}/config/services.yaml"
    fi

    # Compatibilidad temporal con repos vendoreados en .devtools/.
    if [[ -z "$build_registry" && -f "${repo_root}/.devtools/config/apps.yaml" ]]; then
        build_registry="${repo_root}/.devtools/config/apps.yaml"
    fi

    if [[ -z "$deploy_registry" && -f "${repo_root}/.devtools/config/services.yaml" ]]; then
        deploy_registry="${repo_root}/.devtools/config/services.yaml"
    fi

    export DEVTOOLS_REPO_ROOT="$repo_root"
    export DEVTOOLS_CONTRACT_FILE_RESOLVED="$contract_file"
    export DEVTOOLS_BUILD_REGISTRY="$build_registry"
    export DEVTOOLS_DEPLOY_REGISTRY="$deploy_registry"
}

devtools_require_build_registry() {
    local repo_root="${1:-}"

    devtools_load_contract "$repo_root"
    if [[ -z "${DEVTOOLS_BUILD_REGISTRY:-}" ]]; then
        echo "No se pudo resolver DEVTOOLS_BUILD_REGISTRY." >&2
        echo "Define registries.build en devtools.repo.yaml o crea config/apps.yaml." >&2
        return 1
    fi

    if [[ ! -f "${DEVTOOLS_BUILD_REGISTRY}" ]]; then
        echo "No existe el registro de apps: ${DEVTOOLS_BUILD_REGISTRY}" >&2
        return 1
    fi

    printf '%s\n' "${DEVTOOLS_BUILD_REGISTRY}"
}

devtools_require_deploy_registry() {
    local repo_root="${1:-}"

    devtools_load_contract "$repo_root"
    if [[ -z "${DEVTOOLS_DEPLOY_REGISTRY:-}" ]]; then
        echo "No se pudo resolver DEVTOOLS_DEPLOY_REGISTRY." >&2
        echo "Define registries.deploy en devtools.repo.yaml o crea config/services.yaml." >&2
        return 1
    fi

    if [[ ! -f "${DEVTOOLS_DEPLOY_REGISTRY}" ]]; then
        echo "No existe el registro de deploy: ${DEVTOOLS_DEPLOY_REGISTRY}" >&2
        return 1
    fi

    printf '%s\n' "${DEVTOOLS_DEPLOY_REGISTRY}"
}

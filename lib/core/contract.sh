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
    if [[ "$value" == "null" ]]; then
        value=""
    fi

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

devtools_parse_contract_with_yq() {
    local contract_file="$1"
    local build_registry=""
    local deploy_registry=""
    local vendor_dir=""
    local profile_file=""

    command -v yq >/dev/null 2>&1 || return 1

    build_registry="$(yq -r '.registries.build // .registries.apps // .build_registry // .apps_registry // ""' "$contract_file" 2>/dev/null || true)"
    deploy_registry="$(yq -r '.registries.deploy // .registries.services // .deploy_registry // .services_registry // ""' "$contract_file" 2>/dev/null || true)"
    vendor_dir="$(yq -r '.paths.vendor_dir // .vendor_dir // ""' "$contract_file" 2>/dev/null || true)"
    profile_file="$(yq -r '.config.profile_file // .profile_file // ""' "$contract_file" 2>/dev/null || true)"

    printf '%s\n' "$(devtools_clean_yaml_value "$build_registry")"
    printf '%s\n' "$(devtools_clean_yaml_value "$deploy_registry")"
    printf '%s\n' "$(devtools_clean_yaml_value "$vendor_dir")"
    printf '%s\n' "$(devtools_clean_yaml_value "$profile_file")"
}

devtools_parse_contract_fallback() {
    local contract_file="$1"
    local build_registry_raw=""
    local deploy_registry_raw=""
    local vendor_dir_raw=""
    local profile_file_raw=""
    local section=""
    local section_indent=-1

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

        if [[ "$trimmed" =~ ^(registries|paths|config):[[:space:]]*$ ]]; then
            section="${BASH_REMATCH[1]}"
            section_indent="$indent_len"
            continue
        fi

        if [[ -n "$section" && "$indent_len" -le "$section_indent" ]]; then
            section=""
            section_indent=-1
        fi

        if [[ "$trimmed" =~ ^(build_registry|apps_registry):[[:space:]]*(.*)$ ]]; then
            build_registry_raw="${BASH_REMATCH[2]}"
            continue
        fi
        if [[ "$trimmed" =~ ^(deploy_registry|services_registry):[[:space:]]*(.*)$ ]]; then
            deploy_registry_raw="${BASH_REMATCH[2]}"
            continue
        fi
        if [[ "$trimmed" =~ ^(vendor_dir):[[:space:]]*(.*)$ ]]; then
            vendor_dir_raw="${BASH_REMATCH[2]}"
            continue
        fi
        if [[ "$trimmed" =~ ^(profile_file):[[:space:]]*(.*)$ ]]; then
            profile_file_raw="${BASH_REMATCH[2]}"
            continue
        fi

        case "$section" in
            registries)
                if [[ "$trimmed" =~ ^(build|apps):[[:space:]]*(.*)$ ]]; then
                    build_registry_raw="${BASH_REMATCH[2]}"
                    continue
                fi
                if [[ "$trimmed" =~ ^(deploy|services):[[:space:]]*(.*)$ ]]; then
                    deploy_registry_raw="${BASH_REMATCH[2]}"
                    continue
                fi
                ;;
            paths)
                if [[ "$trimmed" =~ ^vendor_dir:[[:space:]]*(.*)$ ]]; then
                    vendor_dir_raw="${BASH_REMATCH[1]}"
                    continue
                fi
                ;;
            config)
                if [[ "$trimmed" =~ ^profile_file:[[:space:]]*(.*)$ ]]; then
                    profile_file_raw="${BASH_REMATCH[1]}"
                    continue
                fi
                ;;
        esac
    done < "$contract_file"

    printf '%s\n' "$(devtools_clean_yaml_value "$build_registry_raw")"
    printf '%s\n' "$(devtools_clean_yaml_value "$deploy_registry_raw")"
    printf '%s\n' "$(devtools_clean_yaml_value "$vendor_dir_raw")"
    printf '%s\n' "$(devtools_clean_yaml_value "$profile_file_raw")"
}

devtools_parse_contract_fields() {
    local contract_file="$1"

    if ! devtools_parse_contract_with_yq "$contract_file"; then
        devtools_parse_contract_fallback "$contract_file"
    fi
}

devtools_load_contract() {
    local repo_root="${1:-}"
    local contract_file=""
    local build_registry="${DEVTOOLS_BUILD_REGISTRY:-}"
    local deploy_registry="${DEVTOOLS_DEPLOY_REGISTRY:-}"
    local vendor_dir="${DEVTOOLS_VENDOR_DIR:-}"
    local profile_config="${DEVTOOLS_PROFILE_CONFIG:-}"
    local parsed_lines=()
    local parsed_build=""
    local parsed_deploy=""
    local parsed_vendor=""
    local parsed_profile=""

    if [[ -z "$repo_root" ]]; then
        repo_root="$(devtools_repo_root)"
    fi

    if [[ -n "$build_registry" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$build_registry")"
    fi
    if [[ -n "$deploy_registry" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$deploy_registry")"
    fi
    if [[ -n "$profile_config" ]]; then
        profile_config="$(devtools_resolve_path "$repo_root" "$profile_config")"
    fi

    contract_file="$(devtools_find_contract_file "$repo_root")"
    if [[ -f "$contract_file" ]]; then
        mapfile -t parsed_lines < <(devtools_parse_contract_fields "$contract_file")
        parsed_build="${parsed_lines[0]:-}"
        parsed_deploy="${parsed_lines[1]:-}"
        parsed_vendor="${parsed_lines[2]:-}"
        parsed_profile="${parsed_lines[3]:-}"
    fi

    # vendor_dir: contrato gana salvo override explicito.
    if [[ -n "$parsed_vendor" ]]; then
        if [[ -z "${vendor_dir:-}" || "$vendor_dir" == ".devtools" || "$vendor_dir" == "./.devtools" ]]; then
            vendor_dir="$parsed_vendor"
        fi
    fi

    vendor_dir="$(devtools_clean_yaml_value "$vendor_dir")"
    vendor_dir="${vendor_dir#./}"
    vendor_dir="${vendor_dir%/}"
    if [[ -z "$vendor_dir" ]]; then
        vendor_dir=".devtools"
    fi

    if [[ -z "$build_registry" && -n "$parsed_build" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$parsed_build")"
    fi
    if [[ -z "$deploy_registry" && -n "$parsed_deploy" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$parsed_deploy")"
    fi
    # profile_file: contrato gana cuando el valor previo esta vacio o en defaults legacy.
    if [[ -n "$parsed_profile" ]]; then
        if [[ -z "${profile_config:-}" \
            || "$profile_config" == ".git-acprc" \
            || "$profile_config" == "./.git-acprc" \
            || "$profile_config" == "${repo_root}/.git-acprc" \
            || "$profile_config" == "${repo_root}/.devtools/.git-acprc" ]]; then
            profile_config="$(devtools_resolve_path "$repo_root" "$parsed_profile")"
        fi
    fi

    if [[ -z "$build_registry" && -f "${repo_root}/config/apps.yaml" ]]; then
        build_registry="${repo_root}/config/apps.yaml"
    fi
    if [[ -z "$deploy_registry" && -f "${repo_root}/config/services.yaml" ]]; then
        deploy_registry="${repo_root}/config/services.yaml"
    fi

    # Compatibilidad con layout vendorizado.
    if [[ -z "$build_registry" && -f "${repo_root}/${vendor_dir}/config/apps.yaml" ]]; then
        build_registry="${repo_root}/${vendor_dir}/config/apps.yaml"
    fi
    if [[ -z "$deploy_registry" && -f "${repo_root}/${vendor_dir}/config/services.yaml" ]]; then
        deploy_registry="${repo_root}/${vendor_dir}/config/services.yaml"
    fi

    export DEVTOOLS_REPO_ROOT="$repo_root"
    export DEVTOOLS_CONTRACT_FILE_RESOLVED="$contract_file"
    export DEVTOOLS_BUILD_REGISTRY="$build_registry"
    export DEVTOOLS_DEPLOY_REGISTRY="$deploy_registry"
    export DEVTOOLS_VENDOR_DIR="$vendor_dir"
    export DEVTOOLS_PROFILE_CONFIG="$profile_config"
}

devtools_vendor_dir() {
    local repo_root="${1:-}"
    devtools_load_contract "$repo_root"
    printf '%s\n' "${DEVTOOLS_VENDOR_DIR:-.devtools}"
}

devtools_vendor_dir_path() {
    local repo_root="${1:-}"
    local vendor_dir=""
    devtools_load_contract "$repo_root"
    vendor_dir="${DEVTOOLS_VENDOR_DIR:-.devtools}"

    if [[ "$vendor_dir" == /* ]]; then
        printf '%s\n' "$vendor_dir"
        return 0
    fi

    printf '%s/%s\n' "${DEVTOOLS_REPO_ROOT:-$(devtools_repo_root)}" "$vendor_dir"
}

devtools_profile_config_file() {
    local repo_root="${1:-}"
    devtools_load_contract "$repo_root"
    printf '%s\n' "${DEVTOOLS_PROFILE_CONFIG:-}"
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

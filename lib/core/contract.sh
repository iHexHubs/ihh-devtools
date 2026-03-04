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

    # No permitimos escapes fuera del repo por defecto.
    if [[ "$cleaned" =~ (^|/)\.\.(/|$) ]]; then
        printf '\n'
        return 0
    fi

    if [[ "$cleaned" == /* ]]; then
        if [[ "${DEVTOOLS_ALLOW_ABSOLUTE_PATHS:-0}" == "1" ]]; then
            printf '%s\n' "$cleaned"
        else
            printf '\n'
        fi
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

    candidate="${repo_root}/devtools.repo.yaml"
    if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    printf '\n'
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
    devtools_parse_contract_fallback "$contract_file"
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
    local __dot_dir=".devtools"
    local __build_tail="config/apps.yaml"
    local __deploy_tail="ecosystem/services.yaml"
    local __allowed_build=""
    local __allowed_deploy=""
    local legacy_vendor_rc=""

    if [[ -z "$repo_root" ]]; then
        repo_root="$(devtools_repo_root)"
    fi
    __allowed_build="${repo_root}/${__dot_dir}/${__build_tail}"
    __allowed_deploy="${repo_root}/${__deploy_tail}"

    contract_file="$(devtools_find_contract_file "$repo_root")"
    if [[ -f "$contract_file" ]]; then
        mapfile -t parsed_lines < <(devtools_parse_contract_fields "$contract_file")
        parsed_build="${parsed_lines[0]:-}"
        parsed_deploy="${parsed_lines[1]:-}"
        parsed_vendor="${parsed_lines[2]:-}"
        parsed_profile="${parsed_lines[3]:-}"
    fi

    # vendor_dir: contrato gana salvo override explícito.
    if [[ -n "$parsed_vendor" ]]; then
        if [[ -z "${vendor_dir:-}" || "$vendor_dir" == ".devtools" || "$vendor_dir" == "./.devtools" ]]; then
            vendor_dir="$parsed_vendor"
        fi
    fi

    vendor_dir="$(devtools_clean_yaml_value "$vendor_dir")"
    vendor_dir="${vendor_dir#./}"
    vendor_dir="${vendor_dir%/}"
    if [[ "$vendor_dir" == /* ]]; then
        vendor_dir=""
    fi
    if [[ -z "$vendor_dir" ]]; then
        vendor_dir=".devtools"
    fi

    # Resolver overrides por entorno primero.
    if [[ -n "$build_registry" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$build_registry")"
    fi
    if [[ -n "$deploy_registry" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$deploy_registry")"
    fi
    if [[ -n "$profile_config" ]]; then
        profile_config="$(devtools_resolve_path "$repo_root" "$profile_config")"
    fi

    # Resolver contrato.
    if [[ -z "$build_registry" && -n "$parsed_build" ]]; then
        build_registry="$(devtools_resolve_path "$repo_root" "$parsed_build")"
    fi
    if [[ -z "$deploy_registry" && -n "$parsed_deploy" ]]; then
        deploy_registry="$(devtools_resolve_path "$repo_root" "$parsed_deploy")"
    fi

    # Enforce: solo permitimos los archivos de contrato de build/deploy.
    if [[ -n "${build_registry:-}" && "${build_registry}" != "${__allowed_build}" ]]; then
        echo "⚠️  Ignorando registries.build fuera de contrato: ${build_registry}" >&2
        build_registry=""
    fi
    if [[ -n "${deploy_registry:-}" && "${deploy_registry}" != "${__allowed_deploy}" ]]; then
        echo "⚠️  Ignorando registries.deploy fuera de contrato: ${deploy_registry}" >&2
        deploy_registry=""
    fi

    # profile_file: contrato gana cuando el valor previo está vacío o en defaults legacy.
    if [[ -n "$parsed_profile" ]]; then
        legacy_vendor_rc="${repo_root}/${vendor_dir}/.git-acprc"
        if [[ -z "${profile_config:-}" \
            || "$profile_config" == ".git-acprc" \
            || "$profile_config" == "./.git-acprc" \
            || "$profile_config" == "${repo_root}/.git-acprc" \
            || "$profile_config" == "$legacy_vendor_rc" ]]; then
            profile_config="$(devtools_resolve_path "$repo_root" "$parsed_profile")"
        fi
    fi

    # Defaults (solo paths permitidos por contrato):
    if [[ -z "$build_registry" && -f "${__allowed_build}" ]]; then
        build_registry="${__allowed_build}"
    fi
    if [[ -z "$deploy_registry" && -f "${__allowed_deploy}" ]]; then
        deploy_registry="${__allowed_deploy}"
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
    local __dot_dir=".devtools"

    devtools_load_contract "$repo_root"
    if [[ -z "${DEVTOOLS_BUILD_REGISTRY:-}" ]]; then
        echo "No se pudo resolver DEVTOOLS_BUILD_REGISTRY." >&2
        echo "Crea '${__dot_dir}/config/apps.yaml' (contrato) o define registries.build apuntando a ese mismo archivo." >&2
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
        echo "Crea 'ecosystem/services.yaml' (contrato) o define registries.deploy apuntando a ese mismo archivo." >&2
        return 1
    fi

    if [[ ! -f "${DEVTOOLS_DEPLOY_REGISTRY}" ]]; then
        echo "No existe el registro de deploy: ${DEVTOOLS_DEPLOY_REGISTRY}" >&2
        return 1
    fi

    printf '%s\n' "${DEVTOOLS_DEPLOY_REGISTRY}"
}

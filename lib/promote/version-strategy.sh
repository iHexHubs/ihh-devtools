#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/promote/version-strategy.sh
#
# Este módulo maneja las estrategias de versionado y etiquetado (Tagging).
# Determina dónde se encuentra el archivo de versión y quién es el responsable
# de crear los tags (el script local o un workflow de GitHub).

# ==============================================================================
# FASE 1: NORMALIZACIÓN ROBUSTA DE VERSION FILE (repo actual)
# ==============================================================================
# Objetivo:
# - Garantizar que siempre leemos VERSION desde el repo actual, NO desde .devtools embebido.
# - Mantener backward-compat: si REPO_ROOT no existe por algún motivo, lo inferimos.
# - Permitir que GitHub (release-please) sea el único que “decide” la versión (local no recalcula).

resolve_repo_version_file() {
    # Preferimos VERSION en la raíz del repo actual
    if [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/VERSION" ]]; then
        echo "${REPO_ROOT}/VERSION"
        return 0
    fi

    # Backward-compat (histórico): relativo a .devtools/bin (puede apuntar a .devtools/VERSION)
    # Nota: SCRIPT_DIR debe venir del script principal que hace el source.
    if [[ -n "${SCRIPT_DIR:-}" && -f "${SCRIPT_DIR}/../VERSION" ]]; then
        echo "${SCRIPT_DIR}/../VERSION"
        return 0
    fi

    # Fallback: relativo al cwd
    if [[ -f "VERSION" ]]; then
        echo "VERSION"
        return 0
    fi

    # Fallback final
    echo "VERSION"
}

# ==============================================================================
# FASE 2: UN SOLO DUEÑO DE TAGS (LOCAL vs GITHUB)
# ==============================================================================
# Objetivo:
# - Evitar duplicados/carreras cuando el repo ya tiene workflows que crean tags.
# - Regla:
#   - Si el repo TIENE workflows de tagging (tag-rc-on-staging / tag-final-on-main),
#     entonces GitHub es el dueño del tag y el promote local NO crea tags.
#   - Si no existen, el promote local sigue creando tags (comportamiento histórico).
#
# Overrides:
# - DEVTOOLS_FORCE_LOCAL_TAGS=1  -> fuerza tag local aunque existan workflows.
# - DEVTOOLS_DISABLE_GH_TAGGER=1 -> equivalente (compat semántica).

repo_has_workflow_file() {
    local wf_name="$1"
    # Asume que REPO_ROOT está seteado globalmente o por el script principal
    local root="${REPO_ROOT:-.}"
    local wf_dir="${root}/.github/workflows"
    [[ -f "${wf_dir}/${wf_name}.yaml" || -f "${wf_dir}/${wf_name}.yml" ]]
}

promote_resolve_tag_owner_for_env() {
    local env="$1"
    local owner="Local"
    local reason="workflow"

    if [[ "${DEVTOOLS_FORCE_LOCAL_TAGS:-0}" == "1" ]]; then
        owner="Local"
        reason="override:DEVTOOLS_FORCE_LOCAL_TAGS"
    elif [[ "${DEVTOOLS_DISABLE_GH_TAGGER:-0}" == "1" ]]; then
        owner="Local"
        reason="override:DEVTOOLS_DISABLE_GH_TAGGER"
    else
        case "$env" in
            staging)
                if repo_has_workflow_file "tag-rc-on-staging"; then
                    owner="GitHub"
                fi
                ;;
            prod)
                if repo_has_workflow_file "tag-final-on-main"; then
                    owner="GitHub"
                fi
                ;;
            *)
                return 1
                ;;
        esac
    fi

    PROMOTE_TAG_OWNER="$owner"
    PROMOTE_TAG_OWNER_REASON="$reason"
    return 0
}

promote_log_tag_owner_for_env() {
    local env="$1"
    promote_resolve_tag_owner_for_env "$env" || return 1

    local owner="${PROMOTE_TAG_OWNER:-Local}"
    local reason="${PROMOTE_TAG_OWNER_REASON:-workflow}"
    if declare -F log_info >/dev/null 2>&1; then
        log_info "Owner tags = ${owner} | Razón = ${reason}"
    else
        echo "Owner tags = ${owner} | Razón = ${reason}"
    fi
}

should_tag_locally_for_staging() {
    promote_resolve_tag_owner_for_env "staging" || return 1
    [[ "${PROMOTE_TAG_OWNER:-Local}" == "Local" ]]
}

should_tag_locally_for_prod() {
    promote_resolve_tag_owner_for_env "prod" || return 1
    [[ "${PROMOTE_TAG_OWNER:-Local}" == "Local" ]]
}

# ==============================================================================
# FASE 3: ESTRATEGIA DE TAGS POR ENTORNO (DEV / STAGING / PROD)
# ==============================================================================
# Contrato:
# - DEV: incrementa solo +build.N (mantiene versión + rc).
# - STAGING: incrementa -rc.N y reinicia build a 1.
# - PROD: versión limpia (sin rc ni build)..
# - Formato: [APP]-vX.Y.Z-rc.N+build.N

# ==============================================================================
# FASE 3.1: REV POR TAGS (LOCAL)
# ==============================================================================
# Contrato:
# - LOCAL: mantiene versión+rc+build actuales y solo incrementa -rev.N
# - Formato: [APP]-vX.Y.Z-rc.N+build.N-rev.N

promote_strip_rev_from_tag() {
    local tag="$1"
    if [[ "$tag" =~ -rev\.([0-9]+)$ ]]; then
        echo "${tag%-rev.${BASH_REMATCH[1]}}"
        return 0
    fi
    echo "$tag"
}

promote_next_rev_tag_for_base() {
    local base_tag="$1"
    [[ -n "${base_tag:-}" ]] || return 1

    local base
    base="$(promote_strip_rev_from_tag "$base_tag")"
    [[ -n "${base:-}" ]] || return 1

    local prefix_re
    if declare -F semver_escape_regex >/dev/null 2>&1; then
        prefix_re="$(semver_escape_regex "$base")"
    else
        prefix_re="$(echo "$base" | sed -e 's/[.[\\*^$()+?{}|\\\\]/\\\\&/g')"
    fi

    local tags
    tags="$(semver_get_tags "${base}-rev" 2>/dev/null || true)"
    local max=0
    while read -r t; do
        [[ -z "$t" ]] && continue
        if [[ "$t" =~ ^${prefix_re}-rev\.([0-9]+)$ ]]; then
            local n="${BASH_REMATCH[1]}"
            (( n > max )) && max="$n"
        fi
    done <<< "$tags"

    echo "${base}-rev.$((max + 1))"
}

promote_base_tag_for_local() {
    local dev_tag
    dev_tag="$(semver_last_dev_tag 2>/dev/null || true)"
    if [[ -z "${dev_tag:-}" ]]; then
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "No se encontró tag dev. Usando promote_next_tag_dev como base."
        fi
        dev_tag="$(promote_next_tag_dev "" 2>/dev/null || true)"
    fi
    [[ -n "${dev_tag:-}" ]] || return 1
    promote_strip_rev_from_tag "$dev_tag"
}

promote_next_tag_local() {
    local base_tag
    base_tag="$(promote_base_tag_for_local)" || return 1
    promote_next_rev_tag_for_base "$base_tag"
}

promote_infer_tag_prefix_from_tag() {
    local tag="$1"
    if [[ -z "${TAG_PREFIX:-}" && -z "${APP:-}" ]]; then
        if [[ "$tag" =~ ^([A-Za-z0-9._-]+)-v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            export TAG_PREFIX="${BASH_REMATCH[1]}"
        fi
    fi
}

promote_tag_file_path() {
    local root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    echo "${root}/.promote_tag"
}

promote_tag_cache_reset() {
    PROMOTE_TAG_CACHE_TAG=""
    PROMOTE_TAG_CACHE_BASE=""
    PROMOTE_TAG_CACHE_RC=""
    PROMOTE_TAG_CACHE_BUILD=""
    PROMOTE_TAG_CACHE_ENV=""
    PROMOTE_TAG_CACHE_TS=""
    PROMOTE_TAG_CACHE_SOURCE=""
}

promote_tag_exists_remote() {
    local tag="$1"
    local remote="${2:-origin}"
    local refs
    refs="$(git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null)"
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        return 2
    fi
    [[ -n "${refs:-}" ]]
}

promote_tag_exists_local() {
    local tag="$1"
    git tag -l "$tag" 2>/dev/null | grep -qx "$tag"
}

promote_tag_cache_is_valid() {
    local tag="$1"
    local remote="${2:-origin}"
    [[ -n "${tag:-}" ]] || return 1

    if promote_tag_exists_local "$tag"; then
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "El tag en .promote_tag ya existe localmente. Ignorando cache." >&2
        else
            echo "⚠️  El tag en .promote_tag ya existe localmente. Ignorando cache." >&2
        fi
        return 1
    fi

    promote_tag_exists_remote "$tag" "$remote"
    local rc=$?
    case "$rc" in
        0)
            if declare -F log_warn >/dev/null 2>&1; then
                log_warn "El tag en .promote_tag ya existe en ${remote}. Ignorando cache." >&2
            else
                echo "⚠️  El tag en .promote_tag ya existe en ${remote}. Ignorando cache." >&2
            fi
            return 1
            ;;
        1)
            # Validación concluyente: no existe en remoto, cache utilizable.
            return 0
            ;;
        *)
            if declare -F log_warn >/dev/null 2>&1; then
                log_warn "Cache no confiable: validación no concluyente en ${remote}; usando fallback local." >&2
            else
                echo "⚠️  Cache no confiable: validación no concluyente en ${remote}; usando fallback local." >&2
            fi
            return 1
            ;;
    esac
}

# Lee cache con compatibilidad:
# - formato viejo: una sola linea = tag
# - formato nuevo: key=value
promote_tag_read_cache() {
    local f="${1:-$(promote_tag_file_path)}"

    promote_tag_cache_reset
    [[ -f "$f" ]] || return 1

    local line
    while IFS= read -r line || [[ -n "${line:-}" ]]; do
        line="$(echo "${line:-}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "${line:-}" ]] && continue

        if [[ "$line" == *=* ]]; then
            local key="${line%%=*}"
            local val="${line#*=}"
            key="$(echo "$key" | tr -d '[:space:]')"
            val="$(echo "$val" | tr -d '[:space:]')"
            case "$key" in
                tag) PROMOTE_TAG_CACHE_TAG="$val" ;;
                base) PROMOTE_TAG_CACHE_BASE="$val" ;;
                rc) PROMOTE_TAG_CACHE_RC="$val" ;;
                build) PROMOTE_TAG_CACHE_BUILD="$val" ;;
                env) PROMOTE_TAG_CACHE_ENV="$val" ;;
                ts) PROMOTE_TAG_CACHE_TS="$val" ;;
                source) PROMOTE_TAG_CACHE_SOURCE="$val" ;;
            esac
        else
            # Compat: una sola linea con el tag
            if [[ -z "${PROMOTE_TAG_CACHE_TAG:-}" ]]; then
                PROMOTE_TAG_CACHE_TAG="$line"
            fi
        fi
    done < "$f"

    [[ -n "${PROMOTE_TAG_CACHE_TAG:-}" ]] || return 1

    if ! promote_tag_cache_is_valid "${PROMOTE_TAG_CACHE_TAG}"; then
        promote_tag_cache_reset
        return 1
    fi

    echo "${PROMOTE_TAG_CACHE_TAG}"
}

promote_tag_write_cache() {
    local tag="$1"
    local base="$2"
    local rc="$3"
    local build="$4"
    local env="$5"
    local source="${6:-}"
    local f="${7:-$(promote_tag_file_path)}"

    [[ -n "${tag:-}" ]] || return 1
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"

    {
        echo "tag=${tag}"
        echo "base=${base}"
        echo "rc=${rc}"
        echo "build=${build}"
        echo "env=${env}"
        echo "ts=${ts}"
        echo "source=${source}"
    } > "$f"
}

promote_last_tag_or_empty() {
    promote_tag_read_cache "$(promote_tag_file_path)"
}

promote_next_tag_hotfix() {
    local base_tag base_ver next_ver
    base_tag="$(get_last_stable_tag || true)"
    if [[ -z "${base_tag:-}" ]]; then
        base_tag="$(semver_bootstrap_tag)"
    fi
    base_ver="$(semver_normalize "$base_tag" || echo "0.0.0")"
    next_ver="$(semver_apply_bump "$base_ver" "patch")"
    echo "$(semver_format_tag "$next_ver" "" "")"
}

promote_next_tag_dev() {
    local range="${1:-}"

    local base_tag base_ver bump reason commits next_ver rc_number build_number

    local active_staging_tag active_dev_tag
    local staging_ver staging_rc staging_build
    local dev_ver dev_rc dev_build

    active_staging_tag="$(semver_last_staging_tag 2>/dev/null || true)"
    active_dev_tag="$(semver_last_dev_tag 2>/dev/null || true)"

    if [[ -n "${active_staging_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$active_staging_tag"
        if semver_parse_tag "$active_staging_tag" staging_ver staging_rc staging_build; then
            next_ver="$staging_ver"
            rc_number="${staging_rc:-1}"
        fi
    fi

    if [[ -z "${next_ver:-}" && -n "${active_dev_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$active_dev_tag"
        if semver_parse_tag "$active_dev_tag" dev_ver dev_rc dev_build; then
            next_ver="$dev_ver"
            rc_number="${dev_rc:-1}"
        fi
    fi

    if [[ -z "${next_ver:-}" ]]; then
        base_tag="$(get_last_stable_tag || true)"
        if [[ -z "${base_tag:-}" ]]; then
            base_tag="$(semver_bootstrap_tag)"
        fi
        base_ver="$(semver_normalize "$base_tag" || echo "0.0.0")"

        if [[ -n "${range:-}" ]]; then
            semver_analyze_range "$range" bump reason commits
        else
            bump="patch"
        fi
        next_ver="$(semver_apply_bump "$base_ver" "$bump")"
        rc_number=1
    fi

    [[ -n "${rc_number:-}" ]] || rc_number=1
    [[ "$rc_number" -lt 1 ]] && rc_number=1

    local dev_tag
    dev_tag="$(semver_last_dev_tag_for_version_rc "$next_ver" "$rc_number" 2>/dev/null || true)"
    if [[ -n "${dev_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$dev_tag"
        if semver_parse_tag "$dev_tag" dev_ver dev_rc dev_build; then
            build_number=$(( ${dev_build:-0} + 1 ))
        fi
    fi
    [[ -n "${build_number:-}" ]] || build_number=1
    [[ "$build_number" -lt 1 ]] && build_number=1

    echo "$(semver_format_tag "$next_ver" "$rc_number" "$build_number")"
}

promote_next_tag_staging() {
    local range="${1:-}"
    local dev_tag dev_ver dev_rc dev_build
    dev_tag="$(semver_last_dev_tag 2>/dev/null || true)"
    if [[ -n "${dev_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$dev_tag"
        if semver_parse_tag "$dev_tag" dev_ver dev_rc dev_build; then
            local next_rc=$(( ${dev_rc:-0} + 1 ))
            [[ "$next_rc" -lt 1 ]] && next_rc=1
            echo "$(semver_format_tag "$dev_ver" "$next_rc" "")"
            return 0
        fi
    fi

    local staging_tag staging_ver staging_rc staging_build
    staging_tag="$(semver_last_staging_tag 2>/dev/null || true)"
    if [[ -n "${staging_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$staging_tag"
        if semver_parse_tag "$staging_tag" staging_ver staging_rc staging_build; then
            local next_rc=$(( ${staging_rc:-0} + 1 ))
            [[ "$next_rc" -lt 1 ]] && next_rc=1
            echo "$(semver_format_tag "$staging_ver" "$next_rc" "")"
            return 0
        fi
    fi

    local base_tag base_ver bump reason commits next_ver rc_number
    base_tag="$(get_last_stable_tag || true)"
    if [[ -z "${base_tag:-}" ]]; then
        base_tag="$(semver_bootstrap_tag)"
    fi
    base_ver="$(semver_normalize "$base_tag" || echo "0.0.0")"

    if [[ -n "${range:-}" ]]; then
        semver_analyze_range "$range" bump reason commits
    else
        bump="patch"
    fi
    next_ver="$(semver_apply_bump "$base_ver" "$bump")"

    rc_number="$(next_rc_number "$next_ver" 2>/dev/null || echo "1")"
    [[ "$rc_number" -lt 1 ]] && rc_number=1

    echo "$(semver_format_tag "$next_ver" "$rc_number" "")"
}

promote_next_tag_prod() {
    local staging_tag staging_ver staging_rc staging_build
    staging_tag="$(semver_last_staging_tag 2>/dev/null || true)"
    if [[ -n "${staging_tag:-}" ]]; then
        promote_infer_tag_prefix_from_tag "$staging_tag"
        if semver_parse_tag "$staging_tag" staging_ver staging_rc staging_build; then
            if [[ -n "${staging_ver:-}" ]]; then
                echo "$(semver_format_tag "$staging_ver" "" "")"
                return 0
            fi
        fi
    fi

    local base_tag base_ver
    base_tag="$(get_last_stable_tag || true)"
    if [[ -z "${base_tag:-}" ]]; then
        base_tag="$(semver_bootstrap_tag)"
    fi
    base_ver="$(semver_normalize "$base_tag" || echo "0.0.0")"

    echo "$(semver_format_tag "$base_ver" "" "")"
}

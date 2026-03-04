#!/usr/bin/env bash
# Helpers semver compartidos.
# Utilidades SemVer reutilizables (parseo, validacion y ayudas de incremento)

# ==============================================================================
# 0. PREFIJOS DE TAG (APP / TAG_PREFIX)
# ==============================================================================

semver_escape_regex() {
    local raw="$1"
    # Escapa caracteres especiales para regex
    echo "$raw" | sed -e 's/[.[\*^$()+?{}|\\]/\\&/g'
}

semver_resolve_tag_prefix_base() {
    local raw="${1:-}"
    if [[ -z "$raw" ]]; then
        raw="${TAG_PREFIX:-}"
    fi
    if [[ -z "$raw" && -n "${APP:-}" ]]; then
        raw="$APP"
    fi

    raw="$(echo "$raw" | tr -d '[:space:]')"
    if [[ -z "$raw" || "$raw" == "v" ]]; then
        echo ""
        return 0
    fi

    if [[ "$raw" == *"-v" ]]; then
        raw="${raw%-v}"
    fi
    raw="${raw%-}"

    echo "$raw"
}

semver_tag_prefix() {
    local base
    base="$(semver_resolve_tag_prefix_base "${1:-}")"
    if [[ -z "$base" ]]; then
        echo "v"
    else
        echo "${base}-v"
    fi
}

semver_tag_prefix_regex() {
    local prefix
    prefix="$(semver_tag_prefix "${1:-}")"
    semver_escape_regex "$prefix"
}

semver_format_tag() {
    local ver="$1"
    local rc="${2:-}"
    local build="${3:-}"
    local prefix
    prefix="$(semver_tag_prefix "${4:-}")"

    local tag="${prefix}${ver}"
    if [[ -n "${rc:-}" ]]; then
        tag="${tag}-rc.${rc}"
    fi
    if [[ -n "${build:-}" ]]; then
        tag="${tag}+build.${build}"
    fi

    echo "$tag"
}

semver_to_image_tag() {
    local tag="$1"
    [[ -n "${tag:-}" ]] || return 1
    echo "${tag/+build./-build.}"
}

semver_parse_tag() {
    local tag="$1"
    local __ver_var="$2"
    local __rc_var="$3"
    local __build_var="$4"

    local prefix_re
    prefix_re="$(semver_tag_prefix_regex)"
    local re="^${prefix_re}([0-9]+\\.[0-9]+\\.[0-9]+)(-rc\\.([0-9]+))?([+-]build\\.([0-9]+))?$"

    if [[ "$tag" =~ $re ]]; then
        printf -v "$__ver_var" '%s' "${BASH_REMATCH[1]}"
        printf -v "$__rc_var" '%s' "${BASH_REMATCH[3]:-}"
        printf -v "$__build_var" '%s' "${BASH_REMATCH[5]:-}"
        return 0
    fi

    return 1
}

# ==============================================================================
# 1. VALIDACIÓN Y NORMALIZACIÓN
# ==============================================================================

# Valida SemVer estricto X.Y.Z (sin prefijo v)
semver_is_valid() {
    local ver="$1"
    [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Normaliza un string de version a X.Y.Z (sin prefijo v)
# Retorna vacio si no es valido
semver_normalize() {
    local ver="$1"

    if semver_is_valid "$ver"; then
        echo "$ver"
        return 0
    fi

    local prefix_re re
    prefix_re="$(semver_tag_prefix_regex)"
    re="^${prefix_re}([0-9]+\\.[0-9]+\\.[0-9]+)(-rc\\.[0-9]+)?([+-]build\\.[0-9]+)?$"
    if [[ "$ver" =~ $re ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    if [[ "$ver" =~ ^([A-Za-z0-9._-]+-)?v([0-9]+\\.[0-9]+\\.[0-9]+)(-rc\\.[0-9]+)?([+-]build\\.[0-9]+)?$ ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# ==============================================================================
# 2. PARSEO Y UTILIDADES
# ==============================================================================

# Descompone X.Y.Z en variables por referencia
# Uso: semver_parse "1.2.3" major minor patch
semver_parse() {
    local ver="$1"
    local __major_var="$2"
    local __minor_var="$3"
    local __patch_var="$4"

    ver="$(semver_normalize "$ver")" || return 1

    local _major _minor _patch
    IFS='.' read -r _major _minor _patch <<< "$ver"

    printf -v "$__major_var" '%s' "$_major"
    printf -v "$__minor_var" '%s' "$_minor"
    printf -v "$__patch_var" '%s' "$_patch"
}

# ==============================================================================
# 3. HELPERS PARA GIT TAGS
# ==============================================================================

# Valida si un tag es valido para Git
semver_valid_tag_ref() {
    local tag="$1"
    git check-ref-format --allow-onelevel "refs/tags/$tag" >/dev/null 2>&1
}

# Valida tag estable vX.Y.Z (sin sufijos)
semver_is_stable_tag() {
    local tag="$1"
    local prefix_re
    prefix_re="$(semver_tag_prefix_regex)"
    [[ "$tag" =~ ^${prefix_re}[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ==============================================================================
# 3.1 LISTADO DE TAGS (ORIGIN -> LOCAL)
# ==============================================================================

# Intenta leer tags desde un remoto con fetch. Si falla, retorna error para fallback local.
get_remote_tags() {
    local pattern="$1"
    local remote="${2:-origin}"

    GIT_TERMINAL_PROMPT=0 git fetch --tags "$remote" >/dev/null 2>&1 || return 1

    local refs
    refs="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" "refs/tags/${pattern}*" 2>/dev/null)" || return 1

    if [[ -z "${refs:-}" ]]; then
        echo ""
        return 0
    fi

    echo "$refs" \
        | awk '{print $2}' \
        | sed 's#refs/tags/##' \
        | sed 's/\\^{}$//' \
        | sort -u
}

# Obtiene tags priorizando remoto. Si no hay red o falla, usa tags locales.
# Setea SEMVER_TAG_SOURCE=remote|local para decisiones posteriores.
semver_get_tags() {
    local pattern="$1"
    local remote="${2:-origin}"

    local tags
    # Si el caller declara modo offline, evitamos intentos remotos.
    if [[ "${DEVTOOLS_PROMOTE_OFFLINE_OK:-0}" == "1" || "${DEVTOOLS_PROMOTE_OFFLINE:-0}" == "1" ]]; then
        SEMVER_TAG_SOURCE="local"
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "Modo OFFLINE: usando tags locales (sin verificacion remota)." >&2
        else
            echo "⚠️  Modo OFFLINE: usando tags locales (sin verificacion remota)." >&2
        fi
        git tag -l "${pattern}*"
        return 0
    fi

    if tags="$(get_remote_tags "$pattern" "$remote")"; then
        SEMVER_TAG_SOURCE="remote"
        echo "$tags"
        return 0
    fi

    SEMVER_TAG_SOURCE="local"
    if [[ "${DEVTOOLS_SEMVER_REQUIRE_REMOTE:-0}" == "1" ]]; then
        if declare -F log_error >/dev/null 2>&1; then
            log_error "No pude leer tags del remoto '${remote}' (modo estricto)." >&2
        else
            echo "❌ No pude leer tags del remoto '${remote}' (modo estricto)." >&2
        fi
        return 1
    fi

    if declare -F log_warn >/dev/null 2>&1; then
        log_warn "No pude leer tags del remoto '${remote}'; usando tags locales (skip red)." >&2
    else
        echo "⚠️  No pude leer tags del remoto '${remote}'; usando tags locales (skip red)." >&2
    fi
    git tag -l "${pattern}*"
}

# ==============================================================================
# 3.2 ORDENAMIENTO Y SELECCION DE TAGS
# ==============================================================================

# Compara dos versiones X.Y.Z. Retorna: 1 si a>b, -1 si a<b, 0 si iguales.
semver_compare_base_versions() {
    local a="$1"
    local b="$2"

    local a_major a_minor a_patch
    local b_major b_minor b_patch

    semver_parse "$a" a_major a_minor a_patch || return 1
    semver_parse "$b" b_major b_minor b_patch || return 1

    if (( a_major > b_major )); then
        echo 1
        return 0
    fi
    if (( a_major < b_major )); then
        echo -1
        return 0
    fi
    if (( a_minor > b_minor )); then
        echo 1
        return 0
    fi
    if (( a_minor < b_minor )); then
        echo -1
        return 0
    fi
    if (( a_patch > b_patch )); then
        echo 1
        return 0
    fi
    if (( a_patch < b_patch )); then
        echo -1
        return 0
    fi

    echo 0
}

# Selecciona el ultimo tag segun el tipo:
# - prod: vX.Y.Z
# - staging: vX.Y.Z-rc.N
# - dev: vX.Y.Z-rc.N+build.M
semver_select_latest_tag() {
    local mode="$1"
    local tags="$2"

    local best_tag="" best_ver="" best_rc="" best_build=""

    while read -r tag; do
        [[ -z "$tag" ]] && continue

        local ver rc build
        if ! semver_parse_tag "$tag" ver rc build; then
            continue
        fi

        case "$mode" in
            prod)
                [[ -z "${rc:-}" && -z "${build:-}" ]] || continue
                ;;
            staging)
                [[ -n "${rc:-}" && -z "${build:-}" ]] || continue
                ;;
            dev)
                [[ -n "${rc:-}" && -n "${build:-}" ]] || continue
                ;;
            *)
                return 1
                ;;
        esac

        if [[ -z "${best_tag:-}" ]]; then
            best_tag="$tag"
            best_ver="$ver"
            best_rc="${rc:-0}"
            best_build="${build:-0}"
            continue
        fi

        local cmp
        cmp="$(semver_compare_base_versions "$ver" "$best_ver")" || continue
        if [[ "$cmp" == "1" ]]; then
            best_tag="$tag"
            best_ver="$ver"
            best_rc="${rc:-0}"
            best_build="${build:-0}"
            continue
        fi
        if [[ "$cmp" == "-1" ]]; then
            continue
        fi

        if [[ "$mode" == "prod" ]]; then
            continue
        fi

        local rc_num="${rc:-0}"
        local best_rc_num="${best_rc:-0}"
        if (( rc_num > best_rc_num )); then
            best_tag="$tag"
            best_ver="$ver"
            best_rc="$rc_num"
            best_build="${build:-0}"
            continue
        fi
        if (( rc_num < best_rc_num )); then
            continue
        fi

        if [[ "$mode" == "dev" ]]; then
            local build_num="${build:-0}"
            local best_build_num="${best_build:-0}"
            if (( build_num > best_build_num )); then
                best_tag="$tag"
                best_ver="$ver"
                best_rc="$rc_num"
                best_build="$build_num"
            fi
        fi
    done <<< "$tags"

    [[ -n "${best_tag:-}" ]] || return 1
    echo "$best_tag"
}

semver_last_prod_tag() {
    local prefix tags
    prefix="$(semver_tag_prefix)"
    tags="$(semver_get_tags "$prefix")"
    [[ -n "${tags:-}" ]] || return 1
    semver_select_latest_tag "prod" "$tags"
}

semver_last_staging_tag() {
    local prefix tags
    prefix="$(semver_tag_prefix)"
    tags="$(semver_get_tags "$prefix")"
    [[ -n "${tags:-}" ]] || return 1
    semver_select_latest_tag "staging" "$tags"
}

semver_last_dev_tag() {
    local prefix tags
    prefix="$(semver_tag_prefix)"
    tags="$(semver_get_tags "$prefix")"
    [[ -n "${tags:-}" ]] || return 1
    semver_select_latest_tag "dev" "$tags"
}

semver_last_staging_tag_for_version() {
    local base_ver="$1"
    base_ver="$(semver_normalize "$base_ver")" || return 1

    local prefix tags
    prefix="$(semver_tag_prefix)"
    tags="$(semver_get_tags "$prefix")"
    [[ -n "${tags:-}" ]] || return 1

    local best_tag="" best_rc=0
    while read -r tag; do
        [[ -z "$tag" ]] && continue
        local ver rc build
        if ! semver_parse_tag "$tag" ver rc build; then
            continue
        fi
        [[ "$ver" == "$base_ver" ]] || continue
        [[ -n "${rc:-}" && -z "${build:-}" ]] || continue

        local rc_num="${rc:-0}"
        if (( rc_num > best_rc )); then
            best_rc="$rc_num"
            best_tag="$tag"
        fi
    done <<< "$tags"

    [[ -n "${best_tag:-}" ]] || return 1
    echo "$best_tag"
}

semver_last_dev_tag_for_version_rc() {
    local base_ver="$1"
    local rc_number="$2"
    base_ver="$(semver_normalize "$base_ver")" || return 1
    [[ -n "${rc_number:-}" ]] || return 1

    local prefix tags
    prefix="$(semver_tag_prefix)"
    tags="$(semver_get_tags "$prefix")"
    [[ -n "${tags:-}" ]] || return 1

    local best_tag="" best_build=0
    while read -r tag; do
        [[ -z "$tag" ]] && continue
        local ver rc build
        if ! semver_parse_tag "$tag" ver rc build; then
            continue
        fi
        [[ "$ver" == "$base_ver" ]] || continue
        [[ -n "${rc:-}" && -n "${build:-}" ]] || continue
        [[ "$rc" == "$rc_number" ]] || continue

        local build_num="${build:-0}"
        if (( build_num > best_build )); then
            best_build="$build_num"
            best_tag="$tag"
        fi
    done <<< "$tags"

    [[ -n "${best_tag:-}" ]] || return 1
    echo "$best_tag"
}

# ==============================================================================
# 4. BUMP DE VERSIONES POR CONVENTIONAL COMMITS
# ==============================================================================

# Analiza un rango de commits y detecta el tipo de bump y su motivo
# Uso: semver_analyze_range "base..head" bump_var reason_var commits_var
semver_analyze_range() {
    local range="$1"
    local __bump_var="$2"
    local __reason_var="$3"
    local __commits_var="$4"

    local subjects
    local commit_count
    commit_count="$(git rev-list --count "$range" 2>/dev/null || echo 0)"

    if [[ "${commit_count}" -eq 0 ]]; then
        printf -v "$__bump_var" '%s' "none"
        printf -v "$__reason_var" '%s' "sin_commits"
        printf -v "$__commits_var" '%s' ""
        return 0
    fi

    subjects="$(git log "$range" --format="%s" 2>/dev/null || true)"
    if [[ -z "$subjects" ]]; then
        subjects="(sin subject)"
    fi

    local breaking_commits feat_commits fix_commits other_commits
    local limit="${SEMVER_COMMITS_LIMIT:-50}"

    breaking_commits="$(
        git log "$range" --format="%s%x1f%b%x1e" 2>/dev/null \
        | awk -v RS='\x1e' -v FS='\x1f' '{
            subject=$1; body=$2;
            if (subject ~ /!:/ || body ~ /BREAKING CHANGE/) print subject
        }' \
        | sed '/^$/d' || true
    )"

    if [[ -n "$breaking_commits" ]]; then
        breaking_commits="$(echo "$breaking_commits" | head -n "$limit")"
        printf -v "$__bump_var" '%s' "major"
        printf -v "$__reason_var" '%s' "breaking"
        printf -v "$__commits_var" '%s' "$breaking_commits"
        return 0
    fi

    feat_commits="$(echo "$subjects" | grep -E '^feat(\(.*\))?:' || true)"
    if [[ -n "$feat_commits" ]]; then
        feat_commits="$(echo "$feat_commits" | head -n "$limit")"
        printf -v "$__bump_var" '%s' "minor"
        printf -v "$__reason_var" '%s' "feat"
        printf -v "$__commits_var" '%s' "$feat_commits"
        return 0
    fi

    fix_commits="$(echo "$subjects" | grep -E '^fix(\(.*\))?:' || true)"
    if [[ -n "$fix_commits" ]]; then
        fix_commits="$(echo "$fix_commits" | head -n "$limit")"
        printf -v "$__bump_var" '%s' "patch"
        printf -v "$__reason_var" '%s' "fix"
        printf -v "$__commits_var" '%s' "$fix_commits"
        return 0
    fi

    other_commits="$(echo "$subjects" | head -n "$limit")"
    printf -v "$__bump_var" '%s' "patch"
    printf -v "$__reason_var" '%s' "otros"
    printf -v "$__commits_var" '%s' "$other_commits"
}

# Aplica un bump a una version base
semver_apply_bump() {
    local current_ver="$1"
    local bump="$2"

    if ! semver_is_valid "$current_ver"; then
        current_ver="0.0.0"
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_ver"

    case "$bump" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        none)
            ;;
        *)
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Calcula la siguiente versión SemVer a partir de commits
# - feat -> minor
# - fix -> patch
# - BREAKING CHANGE o ! -> major
# - Otros -> patch
semver_next_from_commits() {
    local current_ver="$1"

    if ! semver_is_valid "$current_ver"; then
        current_ver="0.0.0"
    fi

    local rev_range
    local tag_ref
    tag_ref="$(semver_format_tag "$current_ver")"
    if git rev-parse "$tag_ref" >/dev/null 2>&1; then
        rev_range="${tag_ref}..HEAD"
    else
        rev_range="HEAD"
    fi

    local bump reason commits
    semver_analyze_range "$rev_range" bump reason commits
    semver_apply_bump "$current_ver" "$bump"
}

# ==============================================================================
# 5. RC INCREMENTAL
# ==============================================================================

# Dada una base X.Y.Z, retorna el siguiente rc.N
semver_next_rc() {
    local base_ver="$1"

    base_ver="$(semver_normalize "$base_ver")" || return 1

    local tag_prefix prefix_re ver_re
    tag_prefix="$(semver_tag_prefix)"
    prefix_re="$(semver_escape_regex "$tag_prefix")"
    ver_re="$(echo "$base_ver" | sed 's/\./\\./g')"

    local pattern="${tag_prefix}${base_ver}-rc"
    local max=0

    local tags
    tags="$(semver_get_tags "${pattern}")"

    if [[ -z "$tags" ]]; then
        echo "1"
        return 0
    fi

    while read -r t; do
        [[ -z "$t" ]] && continue
        if [[ "$t" =~ ^${prefix_re}${ver_re}-rc\.([0-9]+)([+-]build\.[0-9]+)?$ ]]; then
            local n="${BASH_REMATCH[1]}"
            (( n > max )) && max="$n"
        fi
    done <<< "$tags"

    echo $((max + 1))
}

semver_next_build() {
    local base_ver="$1"
    local rc_number="$2"

    base_ver="$(semver_normalize "$base_ver")" || return 1

    if [[ -z "${rc_number:-}" ]]; then
        echo "1"
        return 0
    fi

    local tag_prefix prefix_re ver_re
    tag_prefix="$(semver_tag_prefix)"
    prefix_re="$(semver_escape_regex "$tag_prefix")"
    ver_re="$(echo "$base_ver" | sed 's/\./\\./g')"

    local pattern="${tag_prefix}${base_ver}-rc.${rc_number}"
    local max=0

    local tags
    tags="$(semver_get_tags "${pattern}")"

    if [[ -z "$tags" ]]; then
        echo "1"
        return 0
    fi

    while read -r t; do
        [[ -z "$t" ]] && continue
        if [[ "$t" =~ ^${prefix_re}${ver_re}-rc\.${rc_number}[+-]build\.([0-9]+)$ ]]; then
            local n="${BASH_REMATCH[1]}"
            (( n > max )) && max="$n"
        fi
    done <<< "$tags"

    echo $((max + 1))
}

# ==============================================================================
# 6. RESOLVER ULTIMO TAG ESTABLE
# ==============================================================================

# Resuelve referencia de main (prioriza origin/main)
semver_resolve_main_ref() {
    if git show-ref --verify --quiet "refs/remotes/origin/main"; then
        echo "origin/main"
        return 0
    fi
    if git show-ref --verify --quiet "refs/heads/main"; then
        echo "main"
        return 0
    fi
    if git show-ref --verify --quiet "refs/remotes/origin/master"; then
        echo "origin/master"
        return 0
    fi
    if git show-ref --verify --quiet "refs/heads/master"; then
        echo "master"
        return 0
    fi
    return 1
}

# Verifica si el tag pertenece al historial de un ref
semver_tag_is_on_ref() {
    local tag="$1"
    local ref="$2"
    git merge-base --is-ancestor "$tag" "$ref" >/dev/null 2>&1
}

# Verifica ancestry con resultado trivalente:
# 0: tag es ancestro de ref
# 1: verificación concluyente negativa (no ancestro)
# 2: verificación no concluyente (objetos faltantes/error)
semver_tag_is_on_ref_checked() {
    local tag="$1"
    local ref="$2"

    git rev-parse --verify --quiet "${tag}^{commit}" >/dev/null 2>&1 || return 2
    git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1 || return 2

    git merge-base --is-ancestor "$tag" "$ref" >/dev/null 2>&1
    local rc=$?
    case "$rc" in
        0|1) return "$rc" ;;
        *) return 2 ;;
    esac
}

# Devuelve el ultimo tag estable en main (vX.Y.Z)
semver_last_stable_tag() {
    local main_ref="${1:-}"

    if [[ -z "$main_ref" ]]; then
        main_ref="$(semver_resolve_main_ref)" || return 1
    fi

    local tag
    local prefix
    prefix="$(semver_tag_prefix)"
    local remote="${SEMVER_TAG_REMOTE:-origin}"

    local tags_file source
    tags_file="$(mktemp 2>/dev/null)" || return 1
    if ! semver_get_tags "${prefix}" "$remote" >"$tags_file"; then
        rm -f "$tags_file"
        return 1
    fi
    source="${SEMVER_TAG_SOURCE:-local}"
    local remote_fallback_needed=0

    if [[ ! -s "$tags_file" ]]; then
        rm -f "$tags_file"
        return 1
    fi

    while read -r tag; do
        semver_is_stable_tag "$tag" || continue

        if [[ "$source" == "remote" ]]; then
            semver_tag_is_on_ref_checked "$tag" "$main_ref"
            local ancestry_rc=$?
            case "$ancestry_rc" in
                0)
                    echo "$tag"
                    rm -f "$tags_file"
                    return 0
                    ;;
                1)
                    continue
                    ;;
                *)
                    remote_fallback_needed=1
                    break
                    ;;
            esac
        fi

        if semver_tag_is_on_ref "$tag" "$main_ref"; then
            echo "$tag"
            rm -f "$tags_file"
            return 0
        fi
    done < <(sed '/^$/d' "$tags_file" | sort -V | tac)

    if [[ "$source" == "remote" && "$remote_fallback_needed" -eq 1 ]]; then
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "No pude verificar ancestry real para tags estables remotos en ${main_ref}; usando fallback local seguro." >&2
        else
            echo "⚠️  No pude verificar ancestry real para tags estables remotos en ${main_ref}; usando fallback local seguro." >&2
        fi

        while read -r tag; do
            semver_is_stable_tag "$tag" || continue
            if semver_tag_is_on_ref "$tag" "$main_ref"; then
                echo "$tag"
                rm -f "$tags_file"
                return 0
            fi
        done < <(git tag -l "${prefix}*" | sed '/^$/d' | sort -V | tac)
    fi

    rm -f "$tags_file"
    return 1
}

# Tag base si no existen tags estables
semver_bootstrap_tag() {
    local base="${SEMVER_BOOTSTRAP_VERSION:-0.1.0}"
    base="$(semver_normalize "$base")" || base="0.1.0"
    echo "$(semver_format_tag "$base")"
}

# Devuelve ultimo tag estable o fallback de arranque
semver_last_stable_tag_or_bootstrap() {
    local tag
    if tag="$(semver_last_stable_tag "$@")"; then
        echo "$tag"
        return 0
    fi
    semver_bootstrap_tag
}

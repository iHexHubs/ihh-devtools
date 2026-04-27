#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

task_exists() {
    command -v task >/dev/null 2>&1 || return 1
    local wanted="${1:-}"
    local listed=""

    [[ -n "${wanted:-}" ]] || return 1

    # go-task >=3 imprime "* taskname: desc"; extraemos taskname de esas líneas.
    listed="$(
        NO_COLOR=1 task --list 2>/dev/null \
            | sed -n 's/^[[:space:]]*\*[[:space:]]*\(.*\):[[:space:]].*$/\1/p'
    )"

    # Fallback defensivo para formatos antiguos.
    if [[ -z "${listed:-}" ]]; then
        listed="$(
            NO_COLOR=1 task -l 2>/dev/null \
                | sed -n 's/^[[:space:]]*\([[:alnum:]_.:-][[:alnum:]_.:-]*\):[[:space:]].*$/\1/p'
        )"
    fi

    printf '%s\n' "${listed:-}" | grep -Fxq "${wanted}"
}



promote_local_is_valid_tag_name() {
    local tag="${1:-}"
    [[ -n "${tag:-}" ]] || return 1
    [[ "${tag}" =~ ^[0-9A-Za-z._+\-]+$ ]]
}



promote_local_read_overlay_tag_from_text() {
    # Lee el primer newTag: (asumiendo backend/frontend comparten tag)
    awk '/newTag:/{print $2; exit}'
}



promote_local_get_previous_tag() {
    local overlay_file="$1"
    local remote="${2:-origin}"
    local branch="${3:-local}"

    # 1) Preferir origin/local:<overlay>
    GIT_TERMINAL_PROMPT=0 git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    if git show-ref --verify --quiet "refs/remotes/${remote}/${branch}"; then
        local content=""
        content="$(git show "${remote}/${branch}:${overlay_file}" 2>/dev/null || true)"
        if [[ -n "${content:-}" ]]; then
            echo "$content" | promote_local_read_overlay_tag_from_text
            return 0
        fi
    fi

    # 2) Fallback: overlay en working tree
    if [[ -f "$overlay_file" ]]; then
        promote_local_read_overlay_tag_from_text < "$overlay_file"
        return 0
    fi

    echo ""
    return 0
}



promote_local_next_tag_from_previous() {
    # Calcula rev.N basándose en el tag que está desplegado (origin/local overlay).
    # - base: último dev tag (git semver, con +build)
    # - compara contra previous en formato imagen (-build)
    local previous_image_tag="$1"   # ej: <service>-v1.2.3-rc.4-build.7-rev.3

    local base_dev_tag=""
    base_dev_tag="$(promote_base_tag_for_local | tail -n 1)" || return 1
    base_dev_tag="$(promote_strip_rev_from_tag "$base_dev_tag")"

    local base_dev_image_tag="$base_dev_tag"
    if declare -F semver_to_image_tag >/dev/null 2>&1; then
        base_dev_image_tag="$(semver_to_image_tag "$base_dev_tag")"
    else
        base_dev_image_tag="${base_dev_tag/+build./-build.}"
    fi

    local prev_base=""
    prev_base="$(promote_strip_rev_from_tag "$previous_image_tag")"

    local prev_rev=0
    if [[ "$prev_base" == "$base_dev_image_tag" && "$previous_image_tag" =~ -rev\.([0-9]+)$ ]]; then
        prev_rev="${BASH_REMATCH[1]}"
    fi

    local next_rev=$((prev_rev + 1))
    # final_tag en formato "git semver" (con +build), luego semver_to_image_tag lo vuelve "-build"
    echo "${base_dev_tag}-rev.${next_rev}"
}



promote_local_tag_points_to_sha() {
    local tag="$1"
    local sha="$2"
    local tag_sha=""
    tag_sha="$(git rev-list -n 1 "$tag" 2>/dev/null || true)"
    [[ -n "${tag_sha:-}" && "${tag_sha}" == "${sha}" ]]
}



promote_local_strip_rev_suffix() {
    local tag="$1"
    printf '%s\n' "${tag%-rev.*}"
}



promote_local_next_rev_for_base() {
    local base="$1"
    local max_rev=""

    GIT_TERMINAL_PROMPT=0 git fetch --tags --quiet >/dev/null 2>&1 || true
    max_rev="$(
        git tag -l "${base}-rev.*" \
            | sed -n 's/.*-rev\.\([0-9]\+\)$/\1/p' \
            | sort -n \
            | tail -n 1
    )"

    if [[ -z "${max_rev:-}" ]]; then
        printf '%s\n' "1"
        return 0
    fi

    printf '%s\n' "$((max_rev + 1))"
    return 0
}



promote_local_app_name() {
    local repo_root=""
    local app_name=""

    if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT}" ]]; then
        repo_root="${REPO_ROOT}"
    else
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    [[ -n "${repo_root:-}" ]] || repo_root="$(pwd)"

    app_name="$(basename "$repo_root")"
    app_name="$(printf '%s' "$app_name" | tr -cs 'A-Za-z0-9._-' '-')"
    app_name="${app_name#-}"
    app_name="${app_name%-}"
    [[ -n "${app_name:-}" ]] || app_name="app"

    export APP="$app_name"
    export TAG_PREFIX="$app_name"
    printf '%s\n' "$app_name"
}



promote_local_base_version() {
    local repo_root=""
    local version_file=""
    local version=""

    if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT}" ]]; then
        repo_root="${REPO_ROOT}"
    else
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    [[ -n "${repo_root:-}" ]] || repo_root="$(pwd)"

    version_file="${repo_root}/VERSION"
    [[ -f "$version_file" ]] || return 1

    version="$(sed -n '1p' "$version_file" | tr -d '[:space:]')"
    version="${version#v}"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$version"
}



promote_local_regex_escape() {
    printf '%s' "${1:-}" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}



promote_local_parse_tag_components() {
    local tag="$1"
    local app="$2"
    local version="$3"
    local out_rc_var="$4"
    local out_build_var="$5"
    local out_rev_var="${6:-}"
    local app_rx=""
    local version_rx=""
    local rc_val=""
    local build_val=""
    local rev_val="0"

    app_rx="$(promote_local_regex_escape "$app")"
    version_rx="$(promote_local_regex_escape "$version")"

    if [[ "$tag" =~ ^${app_rx}-v${version_rx}\.rc\.([0-9]+)-build\.([0-9]+)(-rev\.([0-9]+))?$ ]]; then
        rc_val="${BASH_REMATCH[1]}"
        build_val="${BASH_REMATCH[2]}"
        rev_val="${BASH_REMATCH[4]:-0}"
    elif [[ "$tag" =~ ^${app_rx}-v${version_rx}-rc\.([0-9]+)\+build\.([0-9]+)(-rev\.([0-9]+))?$ ]]; then
        rc_val="${BASH_REMATCH[1]}"
        build_val="${BASH_REMATCH[2]}"
        rev_val="${BASH_REMATCH[4]:-0}"
    elif [[ "$tag" =~ ^v${version_rx}\.rc\.([0-9]+)-build\.([0-9]+)(-rev\.([0-9]+))?$ ]]; then
        rc_val="${BASH_REMATCH[1]}"
        build_val="${BASH_REMATCH[2]}"
        rev_val="${BASH_REMATCH[4]:-0}"
    elif [[ "$tag" =~ ^v${version_rx}-rc\.([0-9]+)\+build\.([0-9]+)(-rev\.([0-9]+))?$ ]]; then
        rc_val="${BASH_REMATCH[1]}"
        build_val="${BASH_REMATCH[2]}"
        rev_val="${BASH_REMATCH[4]:-0}"
    else
        return 1
    fi

    printf -v "$out_rc_var" '%s' "$rc_val"
    printf -v "$out_build_var" '%s' "$build_val"
    if [[ -n "${out_rev_var:-}" ]]; then
        printf -v "$out_rev_var" '%s' "$rev_val"
    fi
    return 0
}



promote_local_select_rc_build() {
    local app="$1"
    local version="$2"
    local out_rc_var="$3"
    local out_build_var="$4"
    local pattern_new=""
    local pattern_legacy=""
    local pattern_new_noprefix=""
    local pattern_legacy_noprefix=""
    local tag=""
    local parsed_rc=""
    local parsed_build=""
    local selected_rc="1"
    local selected_build="1"
    local found=0

    pattern_new="${app}-v${version}.rc.*-build.*"
    pattern_legacy="${app}-v${version}-rc.*+build.*"
    pattern_new_noprefix="v${version}.rc.*-build.*"
    pattern_legacy_noprefix="v${version}-rc.*+build.*"
    GIT_TERMINAL_PROMPT=0 git fetch --tags --quiet >/dev/null 2>&1 || true

    while IFS= read -r tag; do
        [[ -n "${tag:-}" ]] || continue
        promote_local_parse_tag_components "$tag" "$app" "$version" parsed_rc parsed_build || continue
        if [[ "$found" -eq 0 ]] \
            || (( 10#${parsed_rc} > 10#${selected_rc} )) \
            || (( 10#${parsed_rc} == 10#${selected_rc} && 10#${parsed_build} > 10#${selected_build} )); then
            selected_rc="$parsed_rc"
            selected_build="$parsed_build"
            found=1
        fi
    done < <(
        {
            git tag -l "$pattern_new"
            git tag -l "$pattern_legacy"
            git tag -l "$pattern_new_noprefix"
            git tag -l "$pattern_legacy_noprefix"
        } | sort -u
    )

    printf -v "$out_rc_var" '%s' "$selected_rc"
    printf -v "$out_build_var" '%s' "$selected_build"
    return 0
}



promote_local_next_rev() {
    local app="$1"
    local version="$2"
    local rc="$3"
    local build="$4"
    local pattern_new=""
    local pattern_legacy=""
    local pattern_new_noprefix=""
    local pattern_legacy_noprefix=""
    local max_rev="0"
    local tag=""
    local parsed_rc=""
    local parsed_build=""
    local parsed_rev="0"

    pattern_new="${app}-v${version}.rc.${rc}-build.${build}-rev.*"
    pattern_legacy="${app}-v${version}-rc.${rc}+build.${build}-rev.*"
    pattern_new_noprefix="v${version}.rc.${rc}-build.${build}-rev.*"
    pattern_legacy_noprefix="v${version}-rc.${rc}+build.${build}-rev.*"
    GIT_TERMINAL_PROMPT=0 git fetch --tags --quiet >/dev/null 2>&1 || true

    while IFS= read -r tag; do
        [[ -n "${tag:-}" ]] || continue
        promote_local_parse_tag_components "$tag" "$app" "$version" parsed_rc parsed_build parsed_rev || continue
        if (( 10#${parsed_rc} == 10#${rc} && 10#${parsed_build} == 10#${build} && 10#${parsed_rev} > 10#${max_rev} )); then
            max_rev="${parsed_rev}"
        fi
    done < <(
        {
            git tag -l "$pattern_new"
            git tag -l "$pattern_legacy"
            git tag -l "$pattern_new_noprefix"
            git tag -l "$pattern_legacy_noprefix"
        } | sort -u
    )

    printf '%s\n' "$((max_rev + 1))"
}



promote_local_tag_name() {
    local app="$1"
    local version="$2"
    local rc="$3"
    local build="$4"
    local rev="$5"

    printf '%s\n' "${app}-v${version}.rc.${rc}-build.${build}-rev.${rev}"
}



promote_local_remote_tag_sha_or_empty_fallback() {
    local tag="${1:-}"
    local remote="${2:-origin}"
    local resolved=""

    [[ -n "${tag:-}" ]] || {
        printf '%s\n' ""
        return 0
    }

    resolved="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "${remote}" "refs/tags/${tag}^{}" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ -z "${resolved:-}" ]]; then
        resolved="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "${remote}" "refs/tags/${tag}" 2>/dev/null | awk 'NR==1 {print $1}')"
    fi
    printf '%s\n' "${resolved:-}"
    return 0
}



promote_local_create_tag() {
    local tag="$1"
    local target_sha="${2:-}"
    local push_tags="${DEVTOOLS_PUSH_LOCAL_TAGS:-1}"
    local existing_sha=""
    local remote_sha=""
    local created_local=0

    [[ -n "${tag:-}" ]] || return 1
    [[ -n "${target_sha:-}" ]] || target_sha="$(git rev-parse "refs/heads/local" 2>/dev/null || true)"
    [[ -n "${target_sha:-}" ]] || return 1

    if [[ "${DEVTOOLS_DRY_RUN:-0}" != "1" && "${push_tags}" == "1" ]]; then
        if declare -F promote_local_remote_tag_sha_or_empty >/dev/null 2>&1; then
            remote_sha="$(promote_local_remote_tag_sha_or_empty "${tag}" "origin" 2>/dev/null || true)"
        else
            remote_sha="$(promote_local_remote_tag_sha_or_empty_fallback "${tag}" "origin")"
        fi
        if [[ -n "${remote_sha:-}" && "${remote_sha}" != "${target_sha}" ]]; then
            return 1
        fi
    fi

    if git show-ref --verify --quiet "refs/tags/${tag}"; then
        existing_sha="$(git rev-list -n 1 "${tag}" 2>/dev/null || true)"
        [[ "${existing_sha:-}" == "${target_sha}" ]] || return 1
    else
        git tag -a "$tag" "$target_sha" -m "promote local: ${tag}" || return 1
        created_local=1
    fi

    if [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]; then
        return 0
    fi

    if [[ "$push_tags" == "1" ]]; then
        if [[ -n "${remote_sha:-}" ]]; then
            return 0
        fi
        if ! GIT_TERMINAL_PROMPT=0 git push origin "$tag"; then
            if [[ "$created_local" -eq 1 ]]; then
                git tag -d "$tag" >/dev/null 2>&1 || true
            fi
            return 1
        fi
    fi
    return 0
}

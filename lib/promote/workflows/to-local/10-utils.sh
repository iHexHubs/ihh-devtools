#!/usr/bin/env bash
# Module loaded by to-local.sh. Must not execute actions on load (only define functions/vars).

task_exists() {
    # Fallback si no existe en tu framework
    command -v task >/dev/null 2>&1 || return 1
    task -l 2>/dev/null | awk '{print $1}' | grep -qx "$1"
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
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
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
    local previous_image_tag="$1"   # ej: pmbok-v1.2.3-rc.4-build.7-rev.3

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

    git fetch --tags --quiet >/dev/null 2>&1 || true
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

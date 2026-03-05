#!/usr/bin/env bash
# shellcheck shell=bash

# Contrato de RC en un solo lugar..
RC_OK=0
RC_INCONSISTENT=1
RC_PRECONDITION=2
RC_USAGE=64

# Flags globales para el CLI nuevo.
PROMOTE_JSON="${PROMOTE_JSON:-0}"
PROMOTE_QUIET="${PROMOTE_QUIET:-0}"
PROMOTE_DRY_RUN="${PROMOTE_DRY_RUN:-0}"
PROMOTE_NO_DOCKER="${PROMOTE_NO_DOCKER:-0}"

__PROMOTE_TMPFILES=()

now_iso() {
    date -Iseconds 2>/dev/null || date
}

redact() {
    local value="$*"
    value="$(printf '%s' "$value" | sed -E \
        -e 's/((SECRET_KEY|DB_PASSWORD|POSTGRES_PASSWORD|ARGO_PWD|TOKEN|API[_-]?KEY|PASSWORD|PASS|adminPassword)[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1***/Ig' \
        -e 's/("?(SECRET_KEY|DB_PASSWORD|POSTGRES_PASSWORD|ARGO_PWD|TOKEN|API[_-]?KEY|PASSWORD|PASS|adminPassword)"?[[:space:]]*:[[:space:]]*")([^"]+)(")/\1***\4/Ig')"
    printf '%s' "$value"
}

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() {
        printf '%s [INFO] %s\n' "$(now_iso)" "$(redact "$*")" >&2
    }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() {
        printf '%s [WARN] %s\n' "$(now_iso)" "$(redact "$*")" >&2
    }
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_error() {
        printf '%s [ERROR] %s\n' "$(now_iso)" "$(redact "$*")" >&2
    }
fi

die_rc() {
    local rc="${1:-1}"
    shift || true
    log_error "$*"
    exit "$rc"
}

# Compatibilidad: en este repo die() históricamente usa 1 solo argumento.
if ! declare -F die >/dev/null 2>&1; then
    die() {
        local rc=1
        if [[ $# -ge 2 && "${1:-}" =~ ^[0-9]+$ ]]; then
            rc="$1"
            shift
        fi
        die_rc "$rc" "$*"
    }
fi

require_cmd() {
    local cmd=""
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die_rc "$RC_PRECONDITION" "Falta comando requerido: $cmd"
    done
}

run() {
    local rendered=""
    local arg=""
    for arg in "$@"; do
        rendered+=" $(printf '%q' "$arg")"
    done

    log_info "RUN:${rendered}"
    if [[ "${PROMOTE_DRY_RUN:-0}" == "1" ]]; then
        return 0
    fi

    "$@"
}

run_quiet() {
    if [[ "${PROMOTE_DRY_RUN:-0}" == "1" ]]; then
        run "$@"
        return 0
    fi

    "$@" >/dev/null 2>&1
}

mktemp_track() {
    local template="${1:-/tmp/promote_local_XXXXXX}"
    local tmp_file=""

    tmp_file="$(mktemp "$template")"
    __PROMOTE_TMPFILES+=("$tmp_file")
    printf '%s\n' "$tmp_file"
}

cleanup() {
    local tmp_file=""
    for tmp_file in "${__PROMOTE_TMPFILES[@]:-}"; do
        [[ -n "$tmp_file" && -e "$tmp_file" ]] && rm -f "$tmp_file" || true
    done
}

core_enable_cleanup_trap() {
    trap cleanup EXIT
}

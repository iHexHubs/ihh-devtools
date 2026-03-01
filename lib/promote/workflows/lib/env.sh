#!/usr/bin/env bash
# shellcheck shell=bash

cmd_env() {
    local task_bin=""
    task_bin="$(command -v task 2>/dev/null || true)"

    if [[ "${PROMOTE_JSON:-0}" == "1" ]]; then
        printf '{"shell":"%s","task":"%s","path_set":%s,"no_docker":%s}\n' \
            "${SHELL:-unknown}" \
            "${task_bin:-}" \
            "$([[ -n "${PATH:-}" ]] && echo true || echo false)" \
            "$([[ "${PROMOTE_NO_DOCKER:-0}" == "1" ]] && echo true || echo false)"
        return "$RC_OK"
    fi

    printf 'SHELL=%s\n' "${SHELL:-unknown}"
    printf 'task=%s\n' "${task_bin:-NO disponible en PATH}"
    printf 'PATH=%s\n' "$(redact "${PATH:-}")"
    printf 'PROMOTE_NO_DOCKER=%s\n' "${PROMOTE_NO_DOCKER:-0}"
    printf 'PROMOTE_DRY_RUN=%s\n' "${PROMOTE_DRY_RUN:-0}"

    return "$RC_OK"
}

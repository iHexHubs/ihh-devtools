#!/usr/bin/env bash
# shellcheck shell=bash

cmd_docker() {
    local sub="${1:-status}"
    shift || true

    if [[ "${PROMOTE_NO_DOCKER:-0}" == "1" ]]; then
        die_rc "$RC_PRECONDITION" "Modo --no-docker activo: omito subcomando docker"
    fi

    case "$sub" in
        status)
            require_cmd docker
            docker ps
            ;;
        sock)
            ls -l /var/run/docker.sock
            ;;
        *)
            die_rc "$RC_USAGE" "Subcomando docker desconocido: $sub (usa: status|sock)"
            ;;
    esac
}

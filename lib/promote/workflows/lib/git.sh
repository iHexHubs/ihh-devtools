#!/usr/bin/env bash
# shellcheck shell=bash

cmd_git() {
    local sub="${1:-status}"
    shift || true

    case "$sub" in
        status)
            git status -sb
            ;;
        current)
            git branch --show-current
            ;;
        *)
            die_rc "$RC_USAGE" "Subcomando git desconocido: $sub (usa: status|current)"
            ;;
    esac
}

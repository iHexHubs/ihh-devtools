#!/usr/bin/env bash
# shellcheck shell=bash

CLI_REMAINING_ARGS=()

usage() {
    cat <<'USAGE'
Uso:
  to-local.sh <comando> [opciones]

Comandos:
  promote      Ejecuta flujo legacy de promote local (default)
  env          Diagnóstico rápido de shell/PATH/toolchain
  git          Operaciones read-only de Git (status/current)
  docker       Diagnóstico read-only de Docker (status/sock)
  doctor       Reservado para migración del dominio doctor
  gateway      Reservado para migración del dominio gateway
  app          Reservado para migración del dominio apps
  help         Mostrar ayuda

Opciones globales:
  --json        Salida JSON (donde aplique)
  --quiet       Reduce logs informativos
  --dry-run     Muestra comandos sin ejecutar
  --no-docker   Modo readonly sin acciones docker
  --readonly    Alias de --no-docker
  -h, --help    Ayuda
USAGE
}

cli_parse_global_flags() {
    CLI_REMAINING_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                PROMOTE_JSON=1
                shift
                ;;
            --quiet)
                PROMOTE_QUIET=1
                shift
                ;;
            --dry-run)
                PROMOTE_DRY_RUN=1
                shift
                ;;
            --no-docker|--readonly)
                PROMOTE_NO_DOCKER=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    CLI_REMAINING_ARGS+=("$1")
                    shift
                done
                return 0
                ;;
            -*)
                die_rc "$RC_USAGE" "Opción desconocida: $1"
                ;;
            *)
                while [[ $# -gt 0 ]]; do
                    CLI_REMAINING_ARGS+=("$1")
                    shift
                done
                return 0
                ;;
        esac
    done

    return 0
}

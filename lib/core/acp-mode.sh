#!/usr/bin/env bash
# lib/core/acp-mode.sh
# Helpers para resolver el modo de staging del wrapper git-acp y aplicar la
# estrategia correspondiente. Cierra H-IHH-14 (P1) + T-IHH-15.
#
# Modos soportados:
#   confirm      muestra git status --short y pide [Y/n] antes de git add .
#   staged       no toca el index; commitea exactamente lo que ya estaba staged
#   interactive  invoca git add -p antes del commit
#   yes          git add . directo (comportamiento legacy)
#
# Flags reconocidos en bin/git-acp.sh:
#   --staged-only / --no-add       => staged
#   --interactive  / -p            => interactive
#   --yes          / --no-confirm  => yes
#
# Precedencia: flag CLI > DEVTOOLS_ACP_DEFAULT_MODE > "confirm".
#
# Códigos de salida usados por las funciones públicas:
#   0  OK; el flujo puede continuar.
#   2  modo inválido (configuración o argumento).
#   3  TTY ausente cuando el modo lo requiere.
#   4  el operador cancela en modo confirm (respuesta n).
#   5  index vacío en modo staged o interactive tras git add -p.
#   6  git add -p falla o el operador cancela el modo interactive.

# acp_resolve_mode <cli_mode_or_empty>
# Imprime el modo resuelto a stdout. Devuelve no-cero si el valor no es válido.
acp_resolve_mode() {
    local cli_mode="${1:-}"
    local resolved
    if [[ -n "$cli_mode" ]]; then
        resolved="$cli_mode"
    else
        resolved="${DEVTOOLS_ACP_DEFAULT_MODE:-confirm}"
    fi
    case "$resolved" in
        confirm|staged|interactive|yes)
            printf '%s\n' "$resolved"
            return 0
            ;;
        *)
            log_error "Modo de git-acp inválido: '${resolved}'."
            echo "   Valores aceptados: confirm | staged | interactive | yes." >&2
            return 2
            ;;
    esac
}

# acp_check_flag_compat <token1> [<token2> ...]
# Recibe tokens correspondientes a flags CLI ya parseados (cada uno: staged,
# interactive o yes). Devuelve no-cero si hay más de uno (combinación
# incompatible).
acp_check_flag_compat() {
    local count=0
    local seen=""
    local token
    for token in "$@"; do
        [[ -z "$token" ]] && continue
        count=$((count + 1))
        seen="${seen:+$seen, }${token}"
    done
    if (( count > 1 )); then
        log_error "Flags de modo incompatibles: ${seen}. Elige uno solo."
        return 1
    fi
    return 0
}

# acp_run_add_strategy <mode>
# Aplica la estrategia de staging. Devuelve 0 si el flujo puede continuar al
# commit; cualquier valor no-cero significa abortar sin commit.
acp_run_add_strategy() {
    local mode="${1:-}"
    case "$mode" in
        confirm)
            log_info "Cambios sin staging:"
            git status --short
            local answer=""
            if ! read -r -p "Continuar con 'git add .'? [Y/n] " answer; then
                log_warn "stdin cerrado sin respuesta. Aborto sin commit."
                return 4
            fi
            case "${answer}" in
                ""|y|Y|yes|Yes|YES|s|S|si|Si|SI|sí|Sí|SÍ)
                    git add .
                    return 0
                    ;;
                n|N|no|No|NO)
                    log_warn "Operación cancelada por el operador. Working tree intacto, sin commit."
                    return 4
                    ;;
                *)
                    log_error "Respuesta no reconocida: '${answer}'. Aborto sin commit."
                    return 4
                    ;;
            esac
            ;;
        staged)
            if git diff --cached --quiet 2>/dev/null; then
                log_error "Modo --staged-only: el index está vacío, no hay nada que commitear."
                echo "   Stagea con 'git add <path>' o usa otro modo (--yes, --interactive o el default 'confirm')." >&2
                return 5
            fi
            return 0
            ;;
        interactive)
            if [[ ! -t 0 ]]; then
                log_error "Modo --interactive (-p) requiere stdin TTY interactivo."
                echo "   Usa --yes o --staged-only en entornos sin terminal." >&2
                return 3
            fi
            if ! git add -p; then
                log_warn "git add -p canceló o falló. Sin commit."
                return 6
            fi
            if git diff --cached --quiet 2>/dev/null; then
                log_error "Modo --interactive: tras 'git add -p' el index sigue vacío."
                return 5
            fi
            return 0
            ;;
        yes)
            git add .
            return 0
            ;;
        *)
            log_error "acp_run_add_strategy: modo inválido '${mode}'."
            return 2
            ;;
    esac
}

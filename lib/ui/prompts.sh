#!/usr/bin/env bash
# Prompts UI compartidos.

# Lee un carácter del usuario (o una cadena si no es modo raw)
# Uso: choice=$(ui_read_option "   Opción > ")
ui_read_option() {
    local prompt="${1:-> }"
    local input
    # Preferir /dev/tty si existe (interactivo incluso dentro de pipes); si no, degradar sin bloquear.
    if [[ -r /dev/tty && -t 0 && -t 1 ]]; then
        read -r -p "$prompt" input < /dev/tty
        printf '%s\n' "$input"
        return 0
    fi
    printf '%s\n' ""
}

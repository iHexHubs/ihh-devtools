#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/bin/git-rp.sh
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# 1. BOOTSTRAP DE LIBRERÍAS.
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/core/utils.sh"       # UI: log_warn, log_error, ask_yes_no
source "${LIB_DIR}/core/git-ops.sh"    # Git: ensure_repo
source "${LIB_DIR}/git-flow.sh"    # Logic: is_protected_branch

# ==============================================================================
# 2. VALIDACIONES DE SEGURIDAD
# ==============================================================================
ensure_repo

CURRENT_BRANCH=$(git branch --show-current)

# Usamos la lógica centralizada de ramas protegidas
if is_protected_branch "$CURRENT_BRANCH"; then
    log_error "🛑 PELIGRO: No puedes ejecutar 'git rp' en la rama protegida '$CURRENT_BRANCH'."
    echo "   Este comando destruye historial. Úsalo solo en tus ramas feature/**."
    exit 1
fi

# ==============================================================================
# 3. INTERACCIÓN CON EL USUARIO
# ==============================================================================

log_warn "⚠️  ESTÁS A PUNTO DE ELIMINAR EL ÚLTIMO COMMIT DE: $CURRENT_BRANCH"
echo "   Esta acción borrará el commit de tu local y forzará el borrado en el remoto."
echo
echo "   Commit a destruir:"
echo "   ------------------------------------------------"
git log -1 --format="%C(red)%h%C(reset) - %s %C(bold blue)<%an>%C(reset) (%ar)"
echo "   ------------------------------------------------"
echo

# Usamos el helper de utils.sh para la confirmación
if ! ask_yes_no "¿Estás 100% seguro de destruir este commit?"; then
    log_info "❌ Operación cancelada a petición del usuario."
    exit 0
fi

# ==============================================================================
# 4. EJECUCIÓN (RESET & PUSH)
# ==============================================================================

log_info "🔥 Destruyendo commit en local..."
git reset --hard HEAD~1

log_info "☁️  Sincronizando destrucción con el remoto (Force Push)..."
if git push origin "$CURRENT_BRANCH" --force; then
    echo
    log_success "✅ Listo. Has retrocedido en el tiempo 1 commit en '$CURRENT_BRANCH'."
else
    log_error "Falló el push al remoto. Tu local está reseteado, pero el remoto no."
    exit 1
fi
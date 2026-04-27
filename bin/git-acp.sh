#!/usr/bin/env bash
# Add/commit/push con asistente de flujo.
set -euo pipefail
IFS=$'\n\t'
__repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ==============================================================================
# DISPATCHER DE CONTEXTO (repo raíz -> script correcto)
# ==============================================================================
if [[ "${DEVTOOLS_DISPATCH_DONE:-0}" != "1" ]]; then
    __read_vendor_dir_from_contract() {
        local contract_file="$1"
        [[ -f "$contract_file" ]] || return 0
        awk '
            function clean(v) {
                gsub(/["\047]/, "", v)
                sub(/[[:space:]]+#.*/, "", v)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                return v
            }
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next }
            in_paths && /^[^[:space:]]/ { in_paths=0 }
            in_paths && /^[[:space:]]*vendor_dir:[[:space:]]*/ {
                line=$0
                sub(/^[[:space:]]*vendor_dir:[[:space:]]*/, "", line)
                print clean(line)
                exit
            }
            /^[[:space:]]*vendor_dir:[[:space:]]*/ {
                line=$0
                sub(/^[[:space:]]*vendor_dir:[[:space:]]*/, "", line)
                print clean(line)
                exit
            }
        ' "$contract_file" 2>/dev/null || true
    }

    __self_path="${BASH_SOURCE[0]}"
    __self_real="$(cd "$(dirname "${__self_path}")" && pwd)/$(basename "${__self_path}")"
    __repo_root="${__repo_root:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    __script_name="$(basename "${__self_path}")"
    __dispatch_target=""
    __vendor_dir="$(__read_vendor_dir_from_contract "${__repo_root}/devtools.repo.yaml")"

    if [[ -n "${__vendor_dir:-}" ]]; then
        __vendor_dir="${__vendor_dir#./}"
        __vendor_dir="${__vendor_dir%/}"
    fi

    __candidates=("${__repo_root}/bin/${__script_name}")
    if [[ -n "${__vendor_dir:-}" ]]; then
        __candidates+=("${__repo_root}/${__vendor_dir}/bin/${__script_name}")
    fi

    for __candidate in "${__candidates[@]}"; do
        [[ -f "${__candidate}" ]] || continue
        __candidate_real="$(cd "$(dirname "${__candidate}")" && pwd)/$(basename "${__candidate}")"
        if [[ "${__candidate_real}" != "${__self_real}" ]]; then
            __dispatch_target="${__candidate}"
            break
        fi
        __dispatch_target="${__candidate}"
        break
    done

    [[ -n "${__dispatch_target:-}" ]] || { echo "❌ No encontré ${__script_name} para dispatch (REPO_ROOT=${__repo_root})." >&2; exit 127; }
    export DEVTOOLS_DISPATCH_REPO_ROOT="${__repo_root}"
    export DEVTOOLS_DISPATCH_TO="${__dispatch_target}"
    if [[ "${__dispatch_target}" != "${__self_real}" ]]; then
        if [[ "${DEVTOOLS_DEBUG_DISPATCH:-0}" == "1" ]]; then
            echo "ℹ️  DISPATCH_REPO_ROOT=${DEVTOOLS_DISPATCH_REPO_ROOT}"
            echo "ℹ️  DISPATCH_TO=${DEVTOOLS_DISPATCH_TO}"
        fi
        export DEVTOOLS_DISPATCH_DONE=1
        exec bash "${__dispatch_target}" "$@"
    fi
fi

# ==============================================================================
# 1. BOOTSTRAP DE LIBRERÍAS
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Estructura esperada: bin/script.sh -> lib/
LIB_DIR="${SCRIPT_DIR}/../lib"

# Orden de carga importante
source "${LIB_DIR}/core/utils.sh"       # Helpers UI, Logs, TTY
source "${LIB_DIR}/core/acp-mode.sh"    # Modo de staging (--staged-only, --interactive, --yes; H-IHH-14)
export DEVTOOLS_DEFER_PERSISTENT_CONFIG=1
source "${LIB_DIR}/core/config.sh"      # Configuración y Defaults
unset DEVTOOLS_DEFER_PERSISTENT_CONFIG
source "${LIB_DIR}/ui/styles.sh"        # <--- FIX: CARGAMOS ESTILOS (ui_step_header, gum)
source "${LIB_DIR}/git-flow.sh"         # Políticas de ramas
source "${LIB_DIR}/ssh-ident.sh"        # Identidad SSH/GPG
source "${LIB_DIR}/ci-workflow.sh"      # Flujo Post-Push (CI/PR)

# Defaults "set -u safe" (si config/rc no los define)
: "${SIMPLE_MODE:=false}"
: "${DAY_START:=00:00}"
: "${REFS_LABEL:=Conteo: commit}"
: "${DAILY_GOAL:=10}"

TOOL_NAME="$(basename "${__repo_root}")"
[[ -n "${TOOL_NAME:-}" ]] || TOOL_NAME="devtools"
echo "🟢 [${TOOL_NAME}] Ejecutando git-acp..."

# ==============================================================================
# 2. VALIDACIONES INICIALES Y ARGUMENTOS
# ==============================================================================

# Parseo preliminar para detectar --force antes de las guardas
ORIG_ARGS=("$@")
FORCE=0
for __a in "$@"; do
  case "$__a" in
    --force|--i-know-what-im-doing) FORCE=1 ;;
  esac
done
(( FORCE )) && export DISABLE_NO_ACP_GUARD=1

# Validación básica de Git
git rev-parse --is-inside-work-tree &>/dev/null || {
  log_error "No estás dentro de un repositorio Git."
  exit 1
}

# Gatekeeper: Verifica si este repo bloquea el uso de ACP (Superrepos)
check_superrepo_guard "$0" "${ORIG_ARGS[@]}"

# ==============================================================================
# 3. PARSEO DE ARGUMENTOS DE COMANDO
# ==============================================================================

NO_PUSH=false
DRY_RUN=false
ACP_MODE_CLI=""
ACP_FLAGS_SEEN=()
ARGS=()

while (( $# )); do
  case "$1" in
    --no-push) NO_PUSH=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --staged-only|--no-add) ACP_FLAGS_SEEN+=("staged"); shift ;;
    --interactive|-p) ACP_FLAGS_SEEN+=("interactive"); shift ;;
    --yes|--no-confirm) ACP_FLAGS_SEEN+=("yes"); shift ;;
    --force|--i-know-what-im-doing) shift ;; # Ya procesado, lo saltamos
    *) ARGS+=("$1"); shift ;;
  esac
done

# Validar combinación de flags de modo y resolver el modo CLI explícito.
acp_check_flag_compat "${ACP_FLAGS_SEEN[@]:-}" || exit 1
ACP_MODE_CLI="${ACP_FLAGS_SEEN[0]:-}"

MSG="${ARGS[*]:-}"
if [[ -z "${MSG//[[:space:]]/}" ]]; then
  log_error "Debes proporcionar un mensaje para git acp."
  echo 'Uso: git acp "<texto_aquí>"' >&2
  exit 1
fi

if declare -F devtools_apply_persistent_config_side_effects >/dev/null 2>&1; then
  devtools_apply_persistent_config_side_effects
fi

# ==============================================================================
# 4. SETUP DE IDENTIDAD
# ==============================================================================

if ! $SIMPLE_MODE; then
    # Lógica compleja de SSH/GPG delegada a la librería
    setup_git_identity
else
    echo "⚡ Modo Estándar (Sin gestión de identidades avanzada)."
fi

# Si setup_git_identity no exportó push_target, usamos origin.
: "${push_target:=origin}"

INTERACTIVE=false

# ==============================================================================
# 5. FUNCIONES CORE (Específicas de este script)
# ==============================================================================

get_today()   { date +%F; }
count_today() { git rev-list --count --since="$1 $DAY_START" HEAD; }

do_commit() {
  local msg="$1"
  local count="$2"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M')"

  # Estrategia de staging delegada a acp_run_add_strategy en EJECUCIÓN
  # PRINCIPAL (H-IHH-14). Aquí solo commiteamos lo que esté en el index.

  if $INTERACTIVE; then
      git commit
  else
      git commit -m "$msg" -m "📅 Fecha: $timestamp" -m "${REFS_LABEL} #$count"
  fi
}

do_push() {
  local remote="$1"
  local branch
  branch="$(git branch --show-current 2>/dev/null || echo "")"
  [[ -n "${branch:-}" ]] || { log_error "HEAD desacoplado. No puedo pushear."; return 1; }
  
  echo "📡 Enviando a '$remote' (Ref: $branch)..."

  # Intentamos push normal o upstream
  local push_success=false
  
  if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
      if GIT_TERMINAL_PROMPT=0 git push -u "$remote" "$branch"; then push_success=true; fi
  else
      if GIT_TERMINAL_PROMPT=0 git push "$remote" "$branch"; then push_success=true; fi
  fi

  # Si falla, intentamos estrategia de rebase (auto-heal)
  if [ "$push_success" = false ]; then
      log_warn "El push fue rechazado. Intentando pull --rebase..."
      if GIT_TERMINAL_PROMPT=0 git pull --rebase "$remote" "$branch"; then
          log_success "Rebase exitoso. Reintentando push..."
          # T-IHH-19: stdout silenciado, stderr filtrado para mostrar solo
          # los avisos de tag-clobber (sin --force, git rechaza tags
          # divergentes con un mensaje útil que antes se perdía).
          local fetch_stderr
          fetch_stderr="$(GIT_TERMINAL_PROMPT=0 git fetch --tags "$remote" 2>&1 >/dev/null || true)"
          if [[ -n "$fetch_stderr" ]]; then
              local clobber_msgs
              clobber_msgs="$(printf '%s\n' "$fetch_stderr" | grep -E 'rejected|clobber' || true)"
              if [[ -n "$clobber_msgs" ]]; then
                  log_warn "Tags locales preservados (no se sobrescriben con --force):"
                  printf '%s\n' "$clobber_msgs" | sed 's/^/    /' >&2
              fi
          fi
          if GIT_TERMINAL_PROMPT=0 git push "$remote" "$branch"; then
              push_success=true
          fi
      else
          log_error "Conflicto irresoluble. Resuélvelo y haz push manual."
          exit 1
      fi
  fi

  # Si todo salió bien, ejecutamos el flujo post-push (CI/PR)
  if [ "$push_success" = true ]; then
      local current_branch="$branch"
      local base_branch="${PR_BASE_BRANCH:-dev}"
      POST_PUSH_FLOW=true run_post_push_flow "$current_branch" "$base_branch"
      return 0
  fi
  
  return 1
}

# ==============================================================================
# 6. EJECUCIÓN PRINCIPAL
# ==============================================================================
TODAY=$(get_today)
COUNT_BEFORE=$(count_today "$TODAY")
NEXT=$((COUNT_BEFORE + 1))

if ! $DRY_RUN; then
  # A. Validar/Renombrar rama Feature
  before_branch="$(git branch --show-current 2>/dev/null || echo "(detached)")"
  ensure_feature_branch_before_commit
  after_branch="$(git branch --show-current 2>/dev/null || echo "(detached)")"

  if [[ "$before_branch" != "$after_branch" ]]; then
    ui_header "✅ Seguridad aplicada"
    ui_warn "Se evitó commitear en rama protegida."
    ui_success "Commit se hará en: $after_branch"
    ui_info "Antes estabas en: $before_branch"
    echo
  fi

  # B. Resolver modo de staging y aplicar la estrategia (H-IHH-14, T-IHH-15).
  RESOLVED_ACP_MODE="$(acp_resolve_mode "${ACP_MODE_CLI:-}")"
  acp_run_add_strategy "$RESOLVED_ACP_MODE"

  # C. Commit
  do_commit "${MSG:-}" "$NEXT"

  # D. Push
  if ! $NO_PUSH; then
    # $push_target viene exportado desde setup_git_identity (o es origin)
    do_push "$push_target"
  else
    log_warn "Se omitió el push (--no-push)."
  fi
fi

# ==============================================================================
# 7. REPORTE DE PROGRESO
# ==============================================================================
TOTAL_TODAY=$(count_today "$TODAY")
show_daily_progress "$TOTAL_TODAY" "$DAILY_GOAL" "$DRY_RUN"

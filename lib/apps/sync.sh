#!/usr/bin/env bash

__devtools_apps_sync_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../core/utils.sh
source "${__devtools_apps_sync_dir}/../core/utils.sh"
# shellcheck source=../core/contract.sh
source "${__devtools_apps_sync_dir}/../core/contract.sh"
# shellcheck source=./apps_config_parser.sh
source "${__devtools_apps_sync_dir}/apps_config_parser.sh"

if ! declare -F resolve_repo_root_or_die >/dev/null 2>&1; then
  resolve_repo_root_or_die() {
    git rev-parse --show-toplevel 2>/dev/null || die "Debes ejecutar este comando dentro de un repositorio Git."
  }
fi

apps_sync_usage() {
  cat <<'EOF'
Uso:
  devtools apps sync [--only <app>]

Opciones:
  --only <app>   Sincroniza solo una app por nombre

Notas:
  - DEVTOOLS_DRY_RUN=1: solo imprime acciones (sin clone/fetch/pull)
EOF
}

is_dry_run() {
  [[ "${DEVTOOLS_DRY_RUN:-0}" == "1" ]]
}

sync_app_entry() {
  local workspace_root="$1"
  local app_name="$2"
  local app_repo="$3"
  local app_dest="${workspace_root}/apps/${app_name}"

  if [[ -d "${app_dest}/.git" ]]; then
    if is_dry_run; then
      log_warn "DRY-RUN: update ${app_name} (${app_dest}) [git fetch --prune + git pull --ff-only]"
      return 0
    fi

    log_info "Update ${app_name}: ${app_dest}"
    git -C "$app_dest" fetch --prune
    git -C "$app_dest" pull --ff-only
    log_ok "App actualizada: ${app_name}"
    return 0
  fi

  if is_dry_run; then
    if [[ -e "$app_dest" && ! -d "${app_dest}/.git" ]]; then
      log_warn "DRY-RUN: destino existente no-git para ${app_name}: ${app_dest}. Se intentaria clonar encima (revisar manualmente)."
      log_warn "DRY-RUN: clone ${app_repo} -> ${app_dest}"
      return 0
    fi

    log_warn "DRY-RUN: clone ${app_repo} -> ${app_dest}"
    return 0
  fi

  if [[ -e "$app_dest" && ! -d "${app_dest}/.git" ]]; then
    die "Destino invalido para ${app_name}: ${app_dest} existe pero no es un repo Git."
  fi

  log_info "Clone ${app_name}: ${app_repo} -> ${app_dest}"
  mkdir -p "$(dirname "$app_dest")"
  git clone "$app_repo" "$app_dest"
  log_ok "App clonada: ${app_name}"
}

apps_sync() {
  local only_app=""

  while (( $# )); do
    case "$1" in
      --only)
        only_app="${2:-}"
        [[ -n "$only_app" ]] || die "Falta valor para --only"
        shift 2
        ;;
      -h|--help)
        apps_sync_usage
        return 0
        ;;
      *)
        die "Opcion desconocida para 'apps sync': $1"
        ;;
    esac
  done

  local repo_root
  repo_root="$(resolve_repo_root_or_die)"

  local config_file=""
  if ! config_file="$(devtools_require_build_registry "$repo_root")"; then
    die "No se pudo resolver el registro de apps para ${repo_root}. Revisa devtools.repo.yaml."
  fi

  local -a app_entries=()
  local parsed_entries_raw=""

  if ! parsed_entries_raw="$(parse_apps_config_or_die "$config_file")"; then
    return 1
  fi

  if [[ -n "$parsed_entries_raw" ]]; then
    mapfile -t app_entries <<< "$parsed_entries_raw"
  fi

  log_info "Repo raiz: ${repo_root}"
  log_info "Config apps: ${config_file}"

  local -a selected_entries=()
  local entry
  for entry in "${app_entries[@]}"; do
    local app_name="${entry%%|*}"
    local app_repo="${entry#*|}"

    [[ -n "$app_name" ]] || die "Config invalida en ${config_file}: item sin name."
    [[ -n "$app_repo" ]] || die "Config invalida en ${config_file}: item sin repo (app=${app_name})."

    if [[ -n "$only_app" && "$app_name" != "$only_app" ]]; then
      continue
    fi

    selected_entries+=("${entry}")
  done

  if [[ -n "$only_app" && "${#selected_entries[@]}" -eq 0 ]]; then
    die "La app '${only_app}' no existe en ${config_file}."
  fi

  local selected_count="${#selected_entries[@]}"
  for entry in "${selected_entries[@]}"; do
    local app_name="${entry%%|*}"
    local app_repo="${entry#*|}"
    sync_app_entry "$repo_root" "$app_name" "$app_repo"
  done

  log_ok "apps sync completado (${selected_count} apps)."
}

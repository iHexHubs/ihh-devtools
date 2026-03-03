#!/usr/bin/env bash

strip_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  echo "$value"
}

default_repo_for_app() {
  local app_name="$1"
  local owner="${DEVTOOLS_APPS_SYNC_OWNER:-iHexHubs}"
  echo "git@github.com:${owner}/${app_name}.git"
}

derive_name_from_path() {
  local app_path="$1"
  app_path="$(strip_quotes "$app_path")"
  app_path="${app_path%/}"

  if [[ "$app_path" =~ ^apps/([^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$app_path" == */* ]]; then
    echo "${app_path##*/}"
    return 0
  fi

  echo "$app_path"
}

# Prints one line per app using format: name|repo
parse_apps_config_or_die() {
  local config_file="$1"
  [[ -f "$config_file" ]] || die "Falta el registro de apps (ruta esperada: ${config_file})"

  local -a entries=()

  local in_container=0
  local container_indent=-1
  local item_name=""
  local item_repo=""
  local item_path=""
  local line_no=0

  finalize_item_or_die() {
    if [[ -z "$item_name" && -n "$item_path" ]]; then
      item_name="$(derive_name_from_path "$item_path")"
    fi

    if [[ -n "$item_name" || -n "$item_repo" || -n "$item_path" ]]; then
      [[ -n "$item_name" ]] || die "Config invalida en ${config_file}: item incompleto cerca de linea ${line_no} (falta name/id)."

      if [[ -z "$item_repo" ]]; then
        item_repo="$(default_repo_for_app "$item_name")"
      fi

      entries+=("${item_name}|${item_repo}")
    fi

    item_name=""
    item_repo=""
    item_path=""
  }

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_no=$((line_no + 1))

    local line="${raw_line%$'\r'}"
    local trimmed
    trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    local indent_prefix="${line%%[![:space:]]*}"
    local indent_len="${#indent_prefix}"

    [[ -z "$trimmed" ]] && continue
    [[ "${trimmed:0:1}" == "#" ]] && continue

    if [[ "$trimmed" =~ ^(apps|repos|repositories|projects):[[:space:]]*$ ]]; then
      finalize_item_or_die
      in_container=1
      container_indent="$indent_len"
      continue
    fi

    if [[ "$in_container" -eq 1 && "$indent_len" -le "$container_indent" ]]; then
      finalize_item_or_die
      in_container=0
      container_indent=-1
    fi

    if [[ "$in_container" -eq 1 && "$indent_len" -eq $((container_indent + 2)) && "$trimmed" =~ ^([A-Za-z0-9._-]+):[[:space:]]*$ ]]; then
      finalize_item_or_die
      item_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
      finalize_item_or_die
      item_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      item_repo=""
      item_path=""
      continue
    fi

    if [[ "$trimmed" =~ ^-[[:space:]]*id:[[:space:]]*(.+)$ ]]; then
      finalize_item_or_die
      item_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      item_repo=""
      item_path=""
      continue
    fi

    if [[ "$trimmed" =~ ^name:[[:space:]]*(.+)$ ]]; then
      item_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^id:[[:space:]]*(.+)$ ]]; then
      item_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^path:[[:space:]]*(.+)$ ]]; then
      item_path="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^repo:[[:space:]]*(.+)$ ]]; then
      item_repo="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^repository:[[:space:]]*(.+)$ ]]; then
      item_repo="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^repo_url:[[:space:]]*(.+)$ ]]; then
      item_repo="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^url:[[:space:]]*(.+)$ ]]; then
      item_repo="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$trimmed" =~ ^git:[[:space:]]*(.+)$ ]]; then
      item_repo="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi
  done < "$config_file"

  finalize_item_or_die

  [[ "${#entries[@]}" -gt 0 ]] || die "Config invalida en ${config_file}: no se encontraron apps. Formas soportadas: apps/repos/repositories/projects como lista (name|id + repo opcional), mapa (clave -> repo) o lista top-level."

  printf '%s\n' "${entries[@]}"
}

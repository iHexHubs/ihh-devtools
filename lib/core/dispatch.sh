#!/usr/bin/env bash

# shellcheck source=./contract.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/contract.sh"

# Dispatches the current script to the canonical path in the active repo context.
# Search order: <repo_root>/bin/<script>, <repo_root>/<vendor_dir>/bin/<script>
devtools_dispatch_if_needed() {
  if [[ "${DEVTOOLS_DISPATCH_DONE:-0}" == "1" ]]; then
    return 0
  fi

  local self_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  local self_real=""
  local repo_root=""
  local script_name=""
  local dispatch_target=""
  local vendor_dir=""
  local vendor_bin_path=""
  local candidate=""
  local candidate_real=""
  local -a candidates=()

  __dispatch_debug() {
    [[ "${DEVTOOLS_DEBUG_DISPATCH:-0}" == "1" ]] || return 0
    echo "DEBUG(dispatch): $*" >&2
  }

  self_real="$(cd "$(dirname "${self_path}")" && pwd)/$(basename "${self_path}")"
  repo_root="$(devtools_repo_root)"
  script_name="$(basename "${self_path}")"
  vendor_dir="$(devtools_vendor_dir "$repo_root")"
  vendor_bin_path=""

  # Evitamos dispatch fuera del repo por rutas absolutas en vendor_dir.
  if [[ -n "${vendor_dir:-}" && "${vendor_dir}" != /* ]]; then
    vendor_bin_path="${repo_root}/${vendor_dir}/bin/${script_name}"
  else
    [[ -n "${vendor_dir:-}" ]] && __dispatch_debug "vendor_dir absoluto ignorado: '${vendor_dir}'"
  fi

  candidates+=("${repo_root}/bin/${script_name}")
  [[ -n "${vendor_bin_path:-}" ]] && candidates+=("${vendor_bin_path}")

  __dispatch_debug "self_real='${self_real}' repo_root='${repo_root}' vendor_dir='${vendor_dir}'"

  for candidate in "${candidates[@]}"; do
    [[ -f "${candidate}" ]] || continue
    candidate_real="$(cd "$(dirname "${candidate}")" && pwd)/$(basename "${candidate}")"

    if [[ "${candidate_real}" != "${self_real}" ]]; then
      dispatch_target="${candidate}"
      break
    fi

    dispatch_target="${candidate}"
    break
  done

  if [[ -z "${dispatch_target}" ]]; then
    echo "ERROR: No encontré '${script_name}' para dispatch (repo_root='${repo_root}')." >&2
    echo "       Busqué en '${repo_root}/bin/' y en '<vendor_dir>/bin/' según devtools.repo.yaml." >&2
    return 127
  fi

  export DEVTOOLS_DISPATCH_REPO_ROOT="${repo_root}"
  export DEVTOOLS_DISPATCH_TO="${dispatch_target}"

  if [[ "${dispatch_target}" != "${self_real}" ]]; then
    export DEVTOOLS_DISPATCH_DONE=1
    exec bash "${dispatch_target}" "$@"
  fi
}

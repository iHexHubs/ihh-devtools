#!/usr/bin/env bash

# Dispatches the current script to the canonical path in the active repo context.
# Search order: <repo_root>/bin/<script>, <repo_root>/.devtools/bin/<script>
devtools_dispatch_if_needed() {
  if [[ "${DEVTOOLS_DISPATCH_DONE:-0}" == "1" ]]; then
    return 0
  fi

  local self_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  local self_real=""
  local repo_root=""
  local script_name=""
  local dispatch_target=""
  local candidate=""
  local candidate_real=""

  self_real="$(cd "$(dirname "${self_path}")" && pwd)/$(basename "${self_path}")"
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  script_name="$(basename "${self_path}")"

  for candidate in \
    "${repo_root}/bin/${script_name}" \
    "${repo_root}/.devtools/bin/${script_name}"
  do
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
    echo "ERROR: No encontre ${script_name} para dispatch (REPO_ROOT=${repo_root})." >&2
    return 127
  fi

  export DEVTOOLS_DISPATCH_REPO_ROOT="${repo_root}"
  export DEVTOOLS_DISPATCH_TO="${dispatch_target}"

  if [[ "${dispatch_target}" != "${self_real}" ]]; then
    export DEVTOOLS_DISPATCH_DONE=1
    exec bash "${dispatch_target}" "$@"
  fi
}

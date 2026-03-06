#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "devtools_dispatch_if_needed dispatches to repo bin script" {
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/bin" "${tdir}/.devtools/bin"
  git -C "$tdir" init -q

  cat > "${tdir}/bin/git-promote.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "TARGET_EXECUTED"
echo "DISPATCH_TO=${DEVTOOLS_DISPATCH_TO:-}"
echo "DISPATCH_ROOT=${DEVTOOLS_DISPATCH_REPO_ROOT:-}"
SH
  chmod +x "${tdir}/bin/git-promote.sh"

  cat > "${tdir}/.devtools/bin/git-promote.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
source "${REPO_ROOT}/lib/core/dispatch.sh"
devtools_dispatch_if_needed "\$@"
echo "SELF_EXECUTED"
SH
  chmod +x "${tdir}/.devtools/bin/git-promote.sh"

  run bash -lc "cd '${tdir}' && '${tdir}/.devtools/bin/git-promote.sh' doctor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TARGET_EXECUTED"* ]]
  [[ "$output" == *"DISPATCH_TO=${tdir}/bin/git-promote.sh"* ]]
  [[ "$output" == *"DISPATCH_ROOT=${tdir}"* ]]
  [[ "$output" != *"SELF_EXECUTED"* ]]
}

@test "devtools_dispatch_if_needed does not re-dispatch canonical script" {
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/bin"
  git -C "$tdir" init -q

  cat > "${tdir}/bin/git-promote.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
source "${REPO_ROOT}/lib/core/dispatch.sh"
devtools_dispatch_if_needed "\$@"
echo "CANONICAL_EXECUTED"
SH
  chmod +x "${tdir}/bin/git-promote.sh"

  run bash -lc "cd '${tdir}' && '${tdir}/bin/git-promote.sh' doctor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CANONICAL_EXECUTED"* ]]
}

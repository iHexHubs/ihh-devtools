#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
  DEVTOOLS_BIN="${REPO_ROOT}/bin/devtools"
  export DEVTOOLS_WIZARD_MODE=true
}

@test "DEVTOOLS_DRY_RUN does not invoke clone/fetch/pull git commands" {
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/.devtools/config" "${tdir}/mockbin"
  mk_git_repo "$tdir"

  cat > "${tdir}/.devtools/config/apps.yaml" <<'YAML'
apps:
  - name: pmbok
    repo: git@github.com:iHexHubs/pmbok.git
YAML

  cat > "${tdir}/mockbin/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
  /usr/bin/git "$@"
  exit $?
fi
if [[ "${1:-}" == "config" && "${2:-}" == "user.name" ]]; then
  /usr/bin/git "$@"
  exit $?
fi
if [[ "${1:-}" == "config" && "${2:-}" == "--global" && "${3:-}" == "init.defaultBranch" ]]; then
  exit 0
fi
echo "UNEXPECTED_GIT:$*" >> "${MOCK_GIT_LOG:?}"
exit 99
SH
  chmod +x "${tdir}/mockbin/git"

  export MOCK_GIT_LOG="${tdir}/unexpected_git_calls.log"
  : > "$MOCK_GIT_LOG"

  run bash -lc "cd '${tdir}' && DEVTOOLS_DRY_RUN=1 PATH='${tdir}/mockbin:$PATH' '${DEVTOOLS_BIN}' apps sync"
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_GIT_LOG" ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "apps sync --only limits output to selected app" {
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/.devtools/config"
  mk_git_repo "$tdir"

  cat > "${tdir}/.devtools/config/apps.yaml" <<'YAML'
apps:
  - name: pmbok
    repo: git@github.com:iHexHubs/pmbok.git
  - name: ihh
    repo: git@github.com:iHexHubs/ihh.git
YAML

  run bash -lc "cd '${tdir}' && DEVTOOLS_DRY_RUN=1 '${DEVTOOLS_BIN}' apps sync --only pmbok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pmbok"* ]]
  [[ "$output" != *"ihh"* ]]
  [[ "$output" == *"completado (1 apps)"* ]]
}

@test "apps sync --only errors for unknown app" {
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/.devtools/config"
  mk_git_repo "$tdir"

  cat > "${tdir}/.devtools/config/apps.yaml" <<'YAML'
apps:
  - name: pmbok
    repo: git@github.com:iHexHubs/pmbok.git
YAML

  run bash -lc "cd '${tdir}' && DEVTOOLS_DRY_RUN=1 '${DEVTOOLS_BIN}' apps sync --only no-existe"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no existe"* ]]
}

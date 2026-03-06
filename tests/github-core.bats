#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
  tdir="$(mktemp -d)"
  mkdir -p "${tdir}/mockbin"

  cat > "${tdir}/mockbin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  exit "${MOCK_GH_AUTH_STATUS:-0}"
fi

if [[ "${1:-}" == "pr" && "${2:-}" == "view" ]]; then
  shift 3
  case "${1:-}" in
    --json)
      case "${2:-}" in
        merged)
          echo "${MOCK_GH_MERGED:-false}"
          exit 0
          ;;
        state)
          echo "${MOCK_GH_STATE:-OPEN}"
          exit 0
          ;;
        mergeCommit)
          echo "${MOCK_GH_MERGE_SHA:-abc123}"
          exit 0
          ;;
      esac
      ;;
  esac
fi

if [[ "${1:-}" == "pr" && "${2:-}" == "list" ]]; then
  echo "${MOCK_GH_PR_LIST_COUNT:-0}"
  exit 0
fi

if [[ "${1:-}" == "pr" && "${2:-}" == "create" ]]; then
  if [[ "${MOCK_GH_CREATE_FAIL:-0}" == "1" ]]; then
    exit 1
  fi
  echo "https://github.com/iHexHubs/ihh/pull/1"
  exit 0
fi

exit 1
SH
  chmod +x "${tdir}/mockbin/gh"

  export PATH="${tdir}/mockbin:${PATH}"
  source "${REPO_ROOT}/lib/core/log.sh"
  source "${REPO_ROOT}/lib/github-core.sh"
}

@test "wait_for_pr_merge_and_get_sha returns merge sha" {
  export MOCK_GH_AUTH_STATUS=0
  export MOCK_GH_MERGED=true
  export MOCK_GH_MERGE_SHA=deadbeef

  run wait_for_pr_merge_and_get_sha 123
  [ "$status" -eq 0 ]
  [ "$output" = "deadbeef" ]
}

@test "wait_for_pr_merge_and_get_sha times out" {
  export MOCK_GH_AUTH_STATUS=0
  export MOCK_GH_MERGED=false
  export MOCK_GH_STATE=OPEN
  export DEVTOOLS_PR_MERGE_TIMEOUT_SECONDS=0
  export DEVTOOLS_PR_MERGE_POLL_SECONDS=0

  run wait_for_pr_merge_and_get_sha 999
  [ "$status" -ne 0 ]
  [[ "$output" == *"Timeout"* ]]
}

@test "pr_exists returns success when open prs exist" {
  export MOCK_GH_PR_LIST_COUNT=1

  run pr_exists feature/x dev
  [ "$status" -eq 0 ]
}

@test "pr_exists returns failure when no open prs" {
  export MOCK_GH_PR_LIST_COUNT=0

  run pr_exists feature/x dev
  [ "$status" -ne 0 ]
}

@test "create_pr returns success on gh create success" {
  export MOCK_GH_CREATE_FAIL=0

  run create_pr feature/x dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR creado exitosamente"* ]]
}

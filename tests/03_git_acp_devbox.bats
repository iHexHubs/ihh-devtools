#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

assert_output_contains() {
  [[ "$output" == *"$1"* ]]
}

assert_output_not_contains() {
  [[ "$output" != *"$1"* ]]
}

make_flow_repo() {
  local dir
  dir="$(mktemp -d "${BATS_TEST_TMPDIR}/git-acp-devbox.XXXXXX")"
  mkdir -p "$dir/subdir"
  mk_git_repo "$dir"
  git -C "$dir" config commit.gpgsign false

  echo "base" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "init"

  echo "dirty" >> "$dir/README.md"
  printf '%s\n' "$dir"
}

run_git_acp_script() {
  local workdir="$1"
  shift

  run env \
    REPO_ROOT="$REPO_ROOT" \
    WORKDIR="$workdir" \
    CI=1 \
    DEVTOOLS_DISPATCH_DONE=1 \
    bash -lc 'cd "$WORKDIR" && bash "$REPO_ROOT/bin/git-acp.sh" "$@" </dev/null' \
    git-acp-devbox "$@"
}

@test "git-acp-devbox rejects execution when message is missing" {
  local repo
  local before_head
  local after_head

  repo="$(make_flow_repo)"
  before_head="$(git -C "$repo" rev-parse HEAD)"

  run_git_acp_script "$repo"

  [ "$status" -eq 1 ]
  assert_output_contains "Debes proporcionar un mensaje para git acp."
  assert_output_not_contains "📡 Enviando a"

  after_head="$(git -C "$repo" rev-parse HEAD)"
  [ "$before_head" = "$after_head" ]
}

@test "git-acp-devbox --dry-run does not create commit or push side effects" {
  local repo
  local before_head
  local after_head
  local status_after

  repo="$(make_flow_repo)"
  before_head="$(git -C "$repo" rev-parse HEAD)"

  run_git_acp_script "$repo" --dry-run "ajuste docs"

  [ "$status" -eq 0 ]
  assert_output_contains "⚗️  Simulación (--dry-run)."
  assert_output_not_contains "📡 Enviando a"

  after_head="$(git -C "$repo" rev-parse HEAD)"
  [ "$before_head" = "$after_head" ]

  status_after="$(git -C "$repo" status --short)"
  [[ "$status_after" == *" M README.md"* ]]
}

@test "git-acp-devbox accepts execution from a subdirectory and exposes visible composed closure" {
  local repo

  repo="$(make_flow_repo)"

  run_git_acp_script "$repo/subdir" --dry-run "desde subdir"

  [ "$status" -eq 0 ]
  assert_output_contains "🟢 ["
  assert_output_contains "⚗️  Simulación (--dry-run)."
  assert_output_contains "📊 Commits hoy:"
}

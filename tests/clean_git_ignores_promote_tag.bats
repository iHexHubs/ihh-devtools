#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "ensure_clean_git ignores untracked .promote_tag" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q
  git -C "$tdir" config user.name "Test Bot"
  git -C "$tdir" config user.email "test@example.com"
  git -C "$tdir" config commit.gpgsign false
  echo "ok" > "${tdir}/README.md"
  git -C "$tdir" add README.md
  git -C "$tdir" commit -m "init" >/dev/null 2>&1

  echo "tag=v0.1.0" > "${tdir}/.promote_tag"

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/git-ops.sh' && ensure_clean_git"
  [ "$status" -eq 0 ]
}

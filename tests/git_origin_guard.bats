#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "ensure_origin_is_github_com_or_die accepts github remote" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q
  git -C "$tdir" remote add origin git@github.com:iHexHubs/ihh.git

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/utils.sh' && source '${REPO_ROOT}/lib/core/git-ops.sh' && ensure_origin_is_github_com_or_die"
  [ "$status" -eq 0 ]
}

@test "ensure_origin_is_github_com_or_die rejects non github remote" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q
  git -C "$tdir" remote add origin git@bitbucket.org:team/project.git

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/utils.sh' && source '${REPO_ROOT}/lib/core/git-ops.sh' && ensure_origin_is_github_com_or_die"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no apunta a github.com"* ]]
}

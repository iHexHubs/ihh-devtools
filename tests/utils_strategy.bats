#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "promote_choose_strategy_or_die accepts preset ff-only" {
  run bash -lc "source '${REPO_ROOT}/lib/core/utils.sh'; DEVTOOLS_PROMOTE_STRATEGY=ff-only promote_choose_strategy_or_die"
  [ "$status" -eq 0 ]
  [ "$output" = "ff-only" ]
}

@test "promote_choose_strategy_or_die fails on invalid preset" {
  run bash -lc "source '${REPO_ROOT}/lib/core/utils.sh'; DEVTOOLS_PROMOTE_STRATEGY=invalid promote_choose_strategy_or_die"
  [ "$status" -ne 0 ]
  [[ "$output" == *"DEVTOOLS_PROMOTE_STRATEGY inválida"* || "$output" == *"DEVTOOLS_PROMOTE_STRATEGY invalida"* ]]
}

#!/usr/bin/env bats

load "helpers/common.bash"

@test "scripts/vendorize.sh validates required paths" {
  REPO_ROOT="$(repo_root)"
  run "${REPO_ROOT}/scripts/vendorize.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"placeholder passed"* ]]
}

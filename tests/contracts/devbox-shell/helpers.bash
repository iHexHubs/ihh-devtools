#!/usr/bin/env bash

repo_root() {
  cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P
}

make_temp_repo_copy() {
  local root
  local tmpdir

  root="$(repo_root)"
  tmpdir="$(mktemp -d /tmp/devbox-shell-contract.XXXXXX)"
  mkdir -p "${tmpdir}/repo"
  cp -a "${root}/." "${tmpdir}/repo/"
  printf '%s\n' "${tmpdir}/repo"
}

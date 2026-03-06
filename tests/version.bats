#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "devtools_version reads VERSION from repo root" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q
  echo "1.2.3" > "${tdir}/VERSION"

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/version.sh' && devtools_version"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "devtools_version falls back to .devtools/VERSION" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q
  mkdir -p "${tdir}/.devtools"
  echo "2.3.4" > "${tdir}/.devtools/VERSION"

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/version.sh' && devtools_version"
  [ "$status" -eq 0 ]
  [ "$output" = "2.3.4" ]
}

@test "devtools_version defaults to 0.1.0 when no version files exist" {
  tdir="$(mktemp -d)"
  git -C "$tdir" init -q

  run bash -lc "cd '${tdir}' && source '${REPO_ROOT}/lib/core/version.sh' && devtools_version"
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0" ]
}

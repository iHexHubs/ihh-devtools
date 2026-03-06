#!/usr/bin/env bats

load "helpers/common.bash"

setup() {
  REPO_ROOT="$(repo_root)"
  export DEVTOOLS_WIZARD_MODE=true

  source "${REPO_ROOT}/lib/core/log.sh"
  source "${REPO_ROOT}/lib/apps/apps_config_parser.sh"
}

@test "derive_name_from_path handles apps prefix" {
  run derive_name_from_path "apps/pmbok/backend"
  [ "$status" -eq 0 ]
  [ "$output" = "pmbok" ]
}

@test "derive_name_from_path handles nested path" {
  run derive_name_from_path "services/ihh/mobile"
  [ "$status" -eq 0 ]
  [ "$output" = "mobile" ]
}

@test "parse_apps_config_or_die parses list with name and repo" {
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/list_name_repo.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "pmbok|git@github.com:org/pmbok.git" ]
}

@test "parse_apps_config_or_die parses id and default repo" {
  export DEVTOOLS_APPS_SYNC_OWNER="acme"
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/list_id_default.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "ihh|git@github.com:acme/ihh.git" ]
}

@test "parse_apps_config_or_die uses iHexHubs as default owner" {
  unset DEVTOOLS_APPS_SYNC_OWNER
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/list_id_default.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "ihh|git@github.com:iHexHubs/ihh.git" ]
}

@test "parse_apps_config_or_die parses map under apps" {
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/map_apps_repo.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "pmbok|git@github.com:org/pmbok.git" ]
}

@test "parse_apps_config_or_die derives name from path" {
  export DEVTOOLS_APPS_SYNC_OWNER="acme"
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/list_path_only.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "pmbok|git@github.com:acme/pmbok.git" ]
}

@test "parse_apps_config_or_die fails when item has no name or id" {
  run parse_apps_config_or_die "${REPO_ROOT}/tests/fixtures/apps/invalid_missing_name.yaml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"falta name/id"* ]]
}

#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  cd "$REPO_ROOT"
}

@test "help exposes the supported shell flags" {
  run devbox shell --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"devbox shell [flags]"* ]]
  [[ "$output" == *"--print-env"* ]]
  [[ "$output" == *"--config"* ]]
  [[ "$output" == *"--env"* ]]
}

@test "print-env exposes the base repo environment" {
  run devbox shell --print-env

  [ "$status" -eq 0 ]
  [[ "$output" == *'export DEVBOX_ENV_NAME="IHH";'* ]]
  [[ "$output" == *"export DEVBOX_PROJECT_ROOT=\"$REPO_ROOT\";"* ]]
}

@test "contract resolver keeps vendor_dir and profile_file aligned with the repo contract" {
  source "$REPO_ROOT/lib/core/contract.sh"

  profile_file="$(devtools_profile_config_file "$REPO_ROOT")"
  vendor_dir="$(devtools_vendor_dir "$REPO_ROOT")"

  [ "$profile_file" = "$REPO_ROOT/.git-acprc" ]
  [ "$vendor_dir" = ".devtools" ]
}

@test "setup wizard wiring keeps the contract-resolved profile file" {
  grep -Fq 'PROFILE_CONFIG_FILE="$(devtools_profile_config_file "$REAL_ROOT" || true)"' "$REPO_ROOT/bin/setup-wizard.sh"
  grep -Fq 'export DEVTOOLS_WIZARD_RC_FILE="${PROFILE_CONFIG_FILE}"' "$REPO_ROOT/bin/setup-wizard.sh"
  grep -Fq 'local rc_file="${DEVTOOLS_WIZARD_RC_FILE:-.git-acprc}"' "$REPO_ROOT/lib/wizard/step-04-profile.sh"
}

@test "init_hook keeps readiness gated by verification" {
  init_hook_file="$BATS_TEST_TMPDIR/init_hook.txt"

  jq -r '.shell.init_hook[]' "$REPO_ROOT/devbox.json" > "$init_hook_file"

  grep -Fq 'DEVBOX_SESSION_READY=1' "$init_hook_file"
  grep -Fq 'if [[ "$DEVTOOLS_SPEC_VARIANT" == "1" ]]; then DEVBOX_SESSION_READY=0; fi' "$init_hook_file"
  grep -Fq 'if [ -f "$DT_ROOT/.setup_completed" ]; then WIZARD_ARGS="--verify-only"; fi' "$init_hook_file"
  grep -Fq 'if [ ! -t 0 ] || [ ! -t 1 ]; then WIZARD_ARGS="--verify-only"; fi' "$init_hook_file"
  grep -Fq 'se omite la ruta lista/contextualizada' "$init_hook_file"
}

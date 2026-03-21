#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/helpers.bash"

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "devbox.json fija la rama estricta del gate cuando hay marker, tty y wizard activo" {
  run python3 -c '
import json, sys
hook = "\n".join(json.load(open(sys.argv[1]))["shell"]["init_hook"])
required = [
    "DEVTOOLS_SPEC_VARIANT=0;",
    "if [ -f \"$DT_ROOT/.setup_completed\" ] && [ -t 0 ] && [ -t 1 ] && [[ \"${DEVTOOLS_SKIP_WIZARD:-0}\" != \"1\" ]]; then DEVTOOLS_SPEC_VARIANT=1; fi",
    "if [[ \"$DEVTOOLS_SPEC_VARIANT\" == \"1\" ]]; then DEVBOX_SESSION_READY=0; fi",
    "if bash \"$WIZARD_SCRIPT\" $WIZARD_ARGS; then",
    "echo '\''❌ Devbox shell: verificación requerida no satisfecha; se omite la ruta lista/contextualizada.'\''"
]
missing = [item for item in required if item not in hook]
if missing:
    print("missing:", missing)
    raise SystemExit(1)
' "${REPO_ROOT}/devbox.json"
  [ "$status" -eq 0 ]
}

@test "setup-wizard verify-only exige GH y SSH para la verificacion contractual" {
  run python3 -c '
import sys
text = open(sys.argv[1]).read()
required = [
    "VERIFY_ONLY=true",
    "REQUIRED_TOOLS=\"git gh ssh grep\"",
    "gh auth status --hostname github.com",
    "ssh -T \"git@$TEST_HOST\"",
    "Ejecuta '\''./bin/setup-wizard.sh --force'\'' para reparar."
]
missing = [item for item in required if item not in text]
if missing:
    print("missing:", missing)
    raise SystemExit(1)
' "${REPO_ROOT}/bin/setup-wizard.sh"
  [ "$status" -eq 0 ]
}

@test "common.sh sigue trazado a la subfrontera print-env para git-cliff" {
  run python3 -c '
import sys
text = open(sys.argv[1]).read()
required = [
    "devbox_env=\"$(devbox shell --print-env 2>/dev/null)\"",
    "eval \"$devbox_env\"",
    "git-cliff --config \"$config_file\""
]
missing = [item for item in required if item not in text]
if missing:
    print("missing:", missing)
    raise SystemExit(1)
' "${REPO_ROOT}/lib/promote/workflows/common.sh"
  [ "$status" -eq 0 ]
}

@test "print-env expone la superficie no interactiva requerida en una copia temporal" {
  local repo_copy
  local tmp_root

  repo_copy="$(make_temp_repo_copy)"
  tmp_root="$(dirname "${repo_copy}")"

  run bash -lc 'cd "$1" && DEVTOOLS_SKIP_VERSION_CHECK=1 DEVTOOLS_SKIP_WIZARD=1 devbox shell --print-env' _ "${repo_copy}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export DEVBOX_PROJECT_ROOT=\"${repo_copy}\";"* ]]
  [[ "$output" == *'export DEVBOX_ENV_NAME="IHH";'* ]]
  [[ "$output" == *'.devbox/nix/profile/default/bin'* ]]
  [[ "$output" == *'git-cliff'* ]]
  rm -rf "${tmp_root}"
}

@test "print-env no deja aliases git persistentes en la copia temporal observada" {
  local repo_copy
  local tmp_root

  repo_copy="$(make_temp_repo_copy)"
  tmp_root="$(dirname "${repo_copy}")"

  run bash -lc 'cd "$1" && DEVTOOLS_SKIP_VERSION_CHECK=1 DEVTOOLS_SKIP_WIZARD=1 devbox shell --print-env >/dev/null 2>/dev/null && git config --local --get-regexp "^alias\\." || true' _ "${repo_copy}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "${tmp_root}"
}

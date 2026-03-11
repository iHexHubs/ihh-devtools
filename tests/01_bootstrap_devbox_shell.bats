#!/usr/bin/env bats

repo_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd
}

run_devbox_shell_pty_smoke() {
  FLOW_REPO_ROOT="$(repo_root)" python3 - <<'PY'
import os
import pty
import select
import subprocess
import sys
import time

cwd = os.environ["FLOW_REPO_ROOT"]
master, slave = pty.openpty()
proc = subprocess.Popen(["devbox", "shell"], cwd=cwd, stdin=slave, stdout=slave, stderr=slave)
os.close(slave)

buf = b""
sent_choice = False
sent_commands = False
deadline = time.time() + 90

while time.time() < deadline:
    ready, _, _ = select.select([master], [], [], 0.5)
    if master in ready:
        data = os.read(master, 8192)
        if not data:
            break
        buf += data

        if (not sent_choice) and b"Selecciona tu Rol:" in buf:
            os.write(master, b"\r")
            sent_choice = True
            time.sleep(0.5)
            os.write(master, b"printf '__PWD__:%s\\n' \"$PWD\"\n")
            os.write(master, b"exit\n")
            sent_commands = True

    if proc.poll() is not None and sent_commands:
        break

try:
    proc.wait(timeout=10)
except Exception:
    proc.kill()
    proc.wait()

sys.stdout.buffer.write(buf)
sys.exit(proc.returncode)
PY
}

file_devbox_json() {
  printf '%s/devbox.json\n' "$(repo_root)"
}

file_hooks() {
  printf '%s/.devbox/gen/scripts/.hooks.sh\n' "$(repo_root)"
}

file_setup_wizard() {
  printf '%s/bin/setup-wizard.sh\n' "$(repo_root)"
}

file_contract() {
  printf '%s/lib/core/contract.sh\n' "$(repo_root)"
}

file_step4() {
  printf '%s/lib/wizard/step-04-profile.sh\n' "$(repo_root)"
}

line_no_fixed() {
  local file="$1"
  local needle="$2"
  local out
  out="$(grep -nF -- "$needle" "$file" | head -n1 || true)"
  printf '%s\n' "${out%%:*}"
}

assert_file_exists() {
  local file="$1"
  [ -f "$file" ]
}

assert_contains_fixed() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file"
}

assert_order_fixed() {
  local file="$1"
  local first="$2"
  local second="$3"
  local l1 l2
  l1="$(line_no_fixed "$file" "$first")"
  l2="$(line_no_fixed "$file" "$second")"
  [ -n "$l1" ]
  [ -n "$l2" ]
  [ "$l1" -lt "$l2" ]
}

@test "A1: devbox.json define shell.init_hook como bootstrap principal" {
  local f
  f="$(file_devbox_json)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" '"shell": {'
  assert_contains_fixed "$f" '"init_hook": ['
}

@test "A2: el hook generado existe y materializa el bootstrap del workspace" {
  local f
  f="$(file_hooks)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'root_guess='
  assert_contains_fixed "$f" 'export PATH="$root/bin:$DT_BIN:$PATH"'
}

@test "A3: el hook resuelve root antes de exportar PATH" {
  local f
  f="$(file_hooks)"
  assert_order_fixed "$f" 'root_guess=' 'export PATH="$root/bin:$DT_BIN:$PATH"'
}

@test "A4: el hook guarda localmente la ruta lista/contextualizada detras del verify-only exitoso" {
  local f
  f="$(file_devbox_json)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'DEVBOX_SESSION_READY=1'
  assert_contains_fixed "$f" 'if [[ "$DEVTOOLS_SPEC_VARIANT" == "1" ]]; then DEVBOX_SESSION_READY=0; fi'
  assert_contains_fixed "$f" 'if bash "$WIZARD_SCRIPT" $WIZARD_ARGS; then'
  assert_contains_fixed "$f" "echo '❌ Devbox shell: verificación requerida no satisfecha; se omite la ruta lista/contextualizada.'"
  assert_contains_fixed "$f" 'if [[ "$DEVBOX_SESSION_READY" == "1" ]]; then'
  assert_order_fixed "$f" 'if bash "$WIZARD_SCRIPT" $WIZARD_ARGS; then' 'if [[ "$DEVBOX_SESSION_READY" == "1" ]]; then'
}

@test "A5: setup-wizard resuelve PROFILE_CONFIG_FILE por contrato antes del fallback vendor" {
  local f
  f="$(file_setup_wizard)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'PROFILE_CONFIG_FILE="$(devtools_profile_config_file "$REAL_ROOT" || true)"'
  assert_contains_fixed "$f" 'PROFILE_CONFIG_FILE="${VENDOR_DIR_ABS}/.git-acprc"'
  assert_order_fixed \
    "$f" \
    'PROFILE_CONFIG_FILE="$(devtools_profile_config_file "$REAL_ROOT" || true)"' \
    'PROFILE_CONFIG_FILE="${VENDOR_DIR_ABS}/.git-acprc"'
}

@test "A6: contract.sh trata vendor profile como compatibilidad heredada" {
  local f
  f="$(file_contract)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'legacy_vendor_rc='
  assert_contains_fixed "$f" 'profile_file: contrato gana cuando el valor previo está vacío o en defaults legacy'
}

@test "A7: step-04 escribe en rc_file y no recalcula el path canónico" {
  local f
  f="$(file_step4)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'local rc_file="${DEVTOOLS_WIZARD_RC_FILE:-.git-acprc}"'
  assert_contains_fixed "$f" 'mkdir -p "$(dirname "$rc_file")"'

  if grep -Fq -- 'devtools_profile_config_file' "$f"; then
    echo "step-04 no debería recalcular el path contractual"
    false
  fi

  if grep -Fq -- 'devtools_load_contract' "$f"; then
    echo "step-04 no debería cargar contrato por su cuenta"
    false
  fi
}

@test "A8: el wizard entra en verify-only si existe marker y no hay --force" {
  local f
  f="$(file_setup_wizard)"
  assert_contains_fixed "$f" 'if [ -f "$MARKER_FILE" ] && [ "$FORCE" != true ]; then'
  assert_contains_fixed "$f" 'VERIFY_ONLY=true'
}

@test "A9: el wizard degrada a verify-only cuando no hay TTY" {
  local f
  f="$(file_setup_wizard)"
  assert_contains_fixed "$f" 'if ! is_tty && [ "$VERIFY_ONLY" != true ]; then'
  assert_contains_fixed "$f" 'Cambiando automáticamente a modo --verify-only.'
}

@test "A10: la ausencia de starship tiene fallback explícito" {
  local f
  f="$(file_hooks)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'command -v starship >/dev/null 2>&1'
  assert_contains_fixed "$f" 'export PROMPT='
  assert_contains_fixed "$f" 'export PS1='
}

@test "A11: la variante contractual ya inicializada evita mutaciones previas incompatibles" {
  local f
  f="$(file_devbox_json)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'DEVTOOLS_SPEC_VARIANT=0;'
  assert_contains_fixed "$f" 'if [ -f "$DT_ROOT/.setup_completed" ] && [ -t 0 ] && [ -t 1 ] && [[ "${DEVTOOLS_SKIP_WIZARD:-0}" != "1" ]]; then DEVTOOLS_SPEC_VARIANT=1; fi'
  assert_contains_fixed "$f" 'if [[ "$DEVTOOLS_SPEC_VARIANT" != "1" ]]; then git -C "$root" submodule sync --recursive >/dev/null 2>&1 || true; fi'
  assert_contains_fixed "$f" 'if [[ "$DEVTOOLS_SPEC_VARIANT" != "1" ]]; then git -C "$root" submodule update --init --recursive "$DEVTOOLS_PATH" >/dev/null 2>&1 || true; fi'
  assert_contains_fixed "$f" 'if [[ "$DEVTOOLS_SPEC_VARIANT" != "1" ]]; then git config --local --unset alias.$tool >/dev/null 2>&1 || true; fi'
  assert_contains_fixed "$f" 'if [[ "$DEVTOOLS_SPEC_VARIANT" != "1" ]]; then chmod +x "$REPO_SCRIPT" >/dev/null 2>&1 || true; fi'
}

@test "A12: verify-only conserva SSH operativo sin known_hosts persistente" {
  local f
  f="$(file_setup_wizard)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'ssh -T "git@$TEST_HOST"'
  assert_contains_fixed "$f" 'StrictHostKeyChecking=accept-new'
  assert_contains_fixed "$f" 'UserKnownHostsFile=/dev/null'
}

@test "A13: smoke PTY de exito alcanza verificacion contextualizacion y handoff real al repo" {
  run run_devbox_shell_pty_smoke

  [ "$status" -eq 0 ]
  [[ "$output" == *"ESTADO SALUDABLE"* ]]
  [[ "$output" == *"Selecciona tu Rol:"* ]]
  [[ "$output" == *__PWD__:/webapps/ihh-devtools* ]]
}

#!/usr/bin/env bats

repo_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd
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

@test "A4: el hook busca setup-wizard, respeta DEVTOOLS_SKIP_WIZARD y lo ejecuta como no fatal" {
  local f
  f="$(file_hooks)"
  assert_file_exists "$f"
  assert_contains_fixed "$f" 'WIZARD_SCRIPT='
  assert_contains_fixed "$f" 'DEVTOOLS_SKIP_WIZARD'
  assert_contains_fixed "$f" 'bash "$WIZARD_SCRIPT" $WIZARD_ARGS || true'
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

@test "smoke controlado de verify-only queda diferido hasta tener sandbox" {
  skip "Siguiente paso: ejecutar bin/setup-wizard.sh en sandbox temporal con gh y ssh stubbeados"
}

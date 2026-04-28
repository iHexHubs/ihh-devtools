#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/semver.bats
# Iteración: T-AMBOS-5 (2026-04-28)

load "../../lib/core/semver.sh"

setup() {
  export GIT_TERMINAL_PROMPT=0
  export DEVTOOLS_PROMOTE_OFFLINE_OK=1
}

init_test_repo() {
  git init -b main >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false
  git config tag.gpgsign false
}

assert_last_output_line() {
  local expected="$1"
  local last_line
  last_line="$(printf '%s\n' "$output" | tail -n 1)"
  [ "$last_line" = "$expected" ]
}

@test "semver_is_valid acepta 1.2.3" {
  run semver_is_valid "1.2.3"
  [ "$status" -eq 0 ]
}

@test "semver_is_valid rechaza prefijo v" {
  run semver_is_valid "v1.2.3"
  [ "$status" -ne 0 ]
}

@test "semver_normalize elimina prefijo v" {
  run semver_normalize "v2.3.4"
  [ "$status" -eq 0 ]
  [ "$output" = "2.3.4" ]
}

@test "semver_parse descompone version" {
  semver_parse "3.4.5" major minor patch
  [ "$major" = "3" ]
  [ "$minor" = "4" ]
  [ "$patch" = "5" ]
}

@test "semver_format_tag usa +build para metadata" {
  run semver_format_tag "1.2.3" "4" "5"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3-rc.4+build.5" ]
}

@test "semver_parse_tag acepta +build y -build por compatibilidad" {
  local ver rc build

  semver_parse_tag "v1.2.3-rc.4+build.5" ver rc build
  [ "$ver" = "1.2.3" ]
  [ "$rc" = "4" ]
  [ "$build" = "5" ]

  semver_parse_tag "v1.2.3-rc.4-build.6" ver rc build
  [ "$ver" = "1.2.3" ]
  [ "$rc" = "4" ]
  [ "$build" = "6" ]
}

@test "semver_to_image_tag mantiene formato docker con -build" {
  run semver_to_image_tag "v1.2.3-rc.4+build.5"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3-rc.4-build.5" ]

  run semver_to_image_tag "v1.2.3-rc.4-build.5"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3-rc.4-build.5" ]
}

@test "semver_is_stable_tag acepta estable" {
  run semver_is_stable_tag "v1.2.3"
  [ "$status" -eq 0 ]
}

@test "semver_is_stable_tag rechaza rc" {
  run semver_is_stable_tag "v1.2.3-rc.1"
  [ "$status" -ne 0 ]
}

@test "semver_valid_tag_ref valida un tag valido" {
  run semver_valid_tag_ref "v1.2.3"
  [ "$status" -eq 0 ]
}

@test "semver_valid_tag_ref rechaza tag invalido" {
  run semver_valid_tag_ref "v1..3"
  [ "$status" -ne 0 ]
}

@test "semver_apply_bump aplica major minor patch y none" {
  run semver_apply_bump "1.2.3" major
  [ "$output" = "2.0.0" ]

  run semver_apply_bump "1.2.3" minor
  [ "$output" = "1.3.0" ]

  run semver_apply_bump "1.2.3" patch
  [ "$output" = "1.2.4" ]

  run semver_apply_bump "1.2.3" none
  [ "$output" = "1.2.3" ]
}

@test "semver_analyze_range detecta major por breaking" {
  local tmp original bump reason commits
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  echo "b" > archivo.txt
  git commit -am "feat!: cambio" >/dev/null

  semver_analyze_range "HEAD~1..HEAD" bump reason commits
  [ "$bump" = "major" ]
  [ "$reason" = "breaking" ]
  echo "$commits" | grep -q "feat!: cambio"

  cd "$original"
  rm -rf "$tmp"
}

@test "semver_analyze_range detecta patch por fix" {
  local tmp original bump reason commits
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "chore: init" >/dev/null

  echo "b" > archivo.txt
  git commit -am "fix: bug" >/dev/null

  semver_analyze_range "HEAD~1..HEAD" bump reason commits
  [ "$bump" = "patch" ]
  [ "$reason" = "fix" ]
  echo "$commits" | grep -q "fix: bug"

  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_stable_tag ignora rc y tags fuera de main" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null
  git tag v0.1.0

  echo "b" > archivo.txt
  git commit -am "fix: second" >/dev/null
  git tag v0.2.0-rc.1

  echo "c" > archivo.txt
  git commit -am "feat: third" >/dev/null
  git tag v0.2.0

  git checkout -b hotfix/x >/dev/null
  echo "d" > archivo.txt
  git commit -am "fix: hotfix" >/dev/null
  git tag v0.3.0

  git checkout main >/dev/null

  run semver_last_stable_tag
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0"

  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_stable_tag en remote omite tag no local (fail-safe)" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  semver_get_tags() {
    SEMVER_TAG_SOURCE="remote"
    printf '%s\n' "v9.9.9"
  }

  run semver_last_stable_tag
  [ "$status" -ne 0 ]

  unset -f semver_get_tags
  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_stable_tag en remote devuelve tag materializado y valido" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null
  git tag v0.2.0

  semver_get_tags() {
    SEMVER_TAG_SOURCE="remote"
    printf '%s\n' "v0.2.0"
  }

  run semver_last_stable_tag
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0"

  unset -f semver_get_tags
  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_stable_tag_or_bootstrap devuelve base si no hay tags" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "chore: init" >/dev/null

  run semver_last_stable_tag_or_bootstrap
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.1.0"

  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_*_tag selecciona prod staging dev" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.1.0
  git tag v0.1.1-rc.1
  git tag v0.1.1-rc.1+build.1
  git tag v0.1.1-rc.1+build.3
  git tag v0.1.1-rc.2
  git tag v0.1.1-rc.2+build.2
  git tag v0.1.1
  git tag v0.2.0-rc.1
  git tag v0.2.0-rc.1+build.2
  git tag v0.2.0-rc.2+build.1

  run semver_last_prod_tag
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.1.1"

  run semver_last_staging_tag
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0-rc.1"

  run semver_last_dev_tag
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0-rc.2+build.1"

  cd "$original"
  rm -rf "$tmp"
}

@test "semver_last_staging_tag_for_version y semver_last_dev_tag_for_version_rc" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.1.0
  git tag v0.2.0-rc.1
  git tag v0.2.0-rc.1+build.1
  git tag v0.2.0-rc.1+build.3
  git tag v0.2.0-rc.2
  git tag v0.2.0-rc.2+build.1
  git tag v0.3.0-rc.1

  run semver_last_staging_tag_for_version "0.2.0"
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0-rc.2"

  run semver_last_dev_tag_for_version_rc "0.2.0" "1"
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0-rc.1+build.3"

  run semver_last_dev_tag_for_version_rc "0.2.0" "2"
  [ "$status" -eq 0 ]
  assert_last_output_line "v0.2.0-rc.2+build.1"

  cd "$original"
  rm -rf "$tmp"
}

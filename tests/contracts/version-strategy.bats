#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/version-strategy.bats
# Iteración: T-AMBOS-5 (2026-04-28)

load "../../lib/core/semver.sh"
load "../../lib/release-flow.sh"
load "../../lib/promote/version-strategy.sh"

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

@test "promote_next_tag_staging usa ultimo dev y no agrega build" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.2.0-rc.1+build.2
  git tag v0.2.0-rc.1+build.5

  run promote_next_tag_staging ""
  [ "$status" -eq 0 ]
  [ "$output" = "v0.2.0-rc.2" ]
  [[ "$output" != *"+build"* ]]

  cd "$original"
  rm -rf "$tmp"
}

@test "promote_next_tag_staging usa ultimo staging si no hay dev" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.3.0-rc.3

  run promote_next_tag_staging ""
  [ "$status" -eq 0 ]
  [ "$output" = "v0.3.0-rc.4" ]
  [[ "$output" != *"+build"* ]]

  cd "$original"
  rm -rf "$tmp"
}

@test "promote_next_tag_prod usa ultimo staging y limpia rc/build" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.4.0-rc.3
  git tag v0.4.0-rc.4
  git tag v0.4.0-rc.4+build.2

  run promote_next_tag_prod
  [ "$status" -eq 0 ]
  [ "$output" = "v0.4.0" ]

  cd "$original"
  rm -rf "$tmp"
}

@test "promote_next_tag_dev mantiene base y suma build si hay rc en curso" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v0.1.2
  git tag v0.1.2-rc.5
  git tag v0.1.2-rc.5+build.2

  run promote_next_tag_dev ""
  [ "$status" -eq 0 ]
  [ "$output" = "v0.1.2-rc.5+build.3" ]

  cd "$original"
  rm -rf "$tmp"
}

@test "promote_strip_rev_from_tag conserva base con +build" {
  run promote_strip_rev_from_tag "v1.2.3-rc.4+build.7-rev.9"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3-rc.4+build.7" ]
}

@test "promote_next_rev_tag_for_base usa max rev + 1 con base +build" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo
  export DEVTOOLS_PROMOTE_OFFLINE_OK=1

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git tag v1.2.3-rc.4+build.7-rev.1
  git tag v1.2.3-rc.4+build.7-rev.3
  git tag v1.2.3-rc.4+build.7-rev.2

  run promote_next_rev_tag_for_base "v1.2.3-rc.4+build.7"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3-rc.4+build.7-rev.4" ]

  cd "$original"
  rm -rf "$tmp"
}

@test "owner tags staging usa GitHub cuando detecta workflow" {
  local tmp original old_repo_root
  tmp="$(mktemp -d)"
  original="$PWD"
  old_repo_root="${REPO_ROOT:-}"

  cd "$tmp"
  mkdir -p ".github/workflows"
  : > ".github/workflows/tag-rc-on-staging.yml"
  export REPO_ROOT="$tmp"
  unset DEVTOOLS_FORCE_LOCAL_TAGS DEVTOOLS_DISABLE_GH_TAGGER

  promote_resolve_tag_owner_for_env "staging"
  [ "$PROMOTE_TAG_OWNER" = "GitHub" ]
  [ "$PROMOTE_TAG_OWNER_REASON" = "workflow" ]

  run promote_log_tag_owner_for_env "staging"
  [ "$status" -eq 0 ]
  [ "$output" = "Owner tags = GitHub | Razón = workflow" ]

  export REPO_ROOT="$old_repo_root"
  cd "$original"
  rm -rf "$tmp"
}

@test "owner tags prod usa GitHub cuando detecta workflow" {
  local tmp original old_repo_root
  tmp="$(mktemp -d)"
  original="$PWD"
  old_repo_root="${REPO_ROOT:-}"

  cd "$tmp"
  mkdir -p ".github/workflows"
  : > ".github/workflows/tag-final-on-main.yaml"
  export REPO_ROOT="$tmp"
  unset DEVTOOLS_FORCE_LOCAL_TAGS DEVTOOLS_DISABLE_GH_TAGGER

  promote_resolve_tag_owner_for_env "prod"
  [ "$PROMOTE_TAG_OWNER" = "GitHub" ]
  [ "$PROMOTE_TAG_OWNER_REASON" = "workflow" ]

  run promote_log_tag_owner_for_env "prod"
  [ "$status" -eq 0 ]
  [ "$output" = "Owner tags = GitHub | Razón = workflow" ]

  export REPO_ROOT="$old_repo_root"
  cd "$original"
  rm -rf "$tmp"
}

@test "owner tags overrides fuerzan Local con razón explícita" {
  local tmp original old_repo_root
  tmp="$(mktemp -d)"
  original="$PWD"
  old_repo_root="${REPO_ROOT:-}"

  cd "$tmp"
  mkdir -p ".github/workflows"
  : > ".github/workflows/tag-rc-on-staging.yml"
  : > ".github/workflows/tag-final-on-main.yml"
  export REPO_ROOT="$tmp"

  export DEVTOOLS_FORCE_LOCAL_TAGS=1
  unset DEVTOOLS_DISABLE_GH_TAGGER
  promote_resolve_tag_owner_for_env "staging"
  [ "$PROMOTE_TAG_OWNER" = "Local" ]
  [ "$PROMOTE_TAG_OWNER_REASON" = "override:DEVTOOLS_FORCE_LOCAL_TAGS" ]

  unset DEVTOOLS_FORCE_LOCAL_TAGS
  export DEVTOOLS_DISABLE_GH_TAGGER=1
  promote_resolve_tag_owner_for_env "prod"
  [ "$PROMOTE_TAG_OWNER" = "Local" ]
  [ "$PROMOTE_TAG_OWNER_REASON" = "override:DEVTOOLS_DISABLE_GH_TAGGER" ]

  export REPO_ROOT="$old_repo_root"
  unset DEVTOOLS_FORCE_LOCAL_TAGS DEVTOOLS_DISABLE_GH_TAGGER
  cd "$original"
  rm -rf "$tmp"
}

@test "promote_tag_cache_is_valid con ls-remote rc=2 usa fallback local e invalida cache" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo
  export DEVTOOLS_PROMOTE_OFFLINE_OK=1

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null

  git() {
    if [[ "${1:-}" == "ls-remote" ]]; then
      return 2
    fi
    command git "$@"
  }

  run promote_tag_cache_is_valid "v9.9.9"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cache no confiable"* ]]

  unset -f git
  cd "$original"
  rm -rf "$tmp"
}

@test "promote_tag_read_cache invalida cache cuando el tag ya existe localmente" {
  local tmp original
  tmp="$(mktemp -d)"
  original="$PWD"

  cd "$tmp"
  init_test_repo
  export DEVTOOLS_PROMOTE_OFFLINE_OK=1

  echo "a" > archivo.txt
  git add archivo.txt
  git commit -m "feat: init" >/dev/null
  git tag v1.2.3

  cat > ".promote_tag" <<'EOF'
tag=v1.2.3
base=1.2.3
rc=
build=
env=prod
source=test
EOF

  run promote_tag_read_cache ".promote_tag"
  [ "$status" -eq 1 ]
  [ -z "${PROMOTE_TAG_CACHE_TAG:-}" ]

  cd "$original"
  rm -rf "$tmp"
}

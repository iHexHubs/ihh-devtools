#!/usr/bin/env bash

repo_root() {
  cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd -P
}

mk_git_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.name "Test Bot"
  git -C "$dir" config user.email "test@example.com"
}

#!/usr/bin/env bats

@test "bootstrap.devbox-shell spec exists" {
  [ -f "specs/flows/bootstrap.devbox-shell.md" ]
}

@test "bootstrap.devbox-shell has not been validated yet" {
  skip "Pending discovery -> spec-first -> spec-anchored"
}

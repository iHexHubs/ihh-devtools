#!/usr/bin/env bats

@test "git-promote.to-local spec placeholder exists" {
  [ -f "specs/flows/git-promote.to-local.md" ]
}

@test "git-promote.to-local validation is pending" {
  skip "Flow not started yet"
}

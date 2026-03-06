#!/usr/bin/env bats

@test "git-acp.post-push spec placeholder exists" {
  [ -f "specs/flows/git-acp.post-push.md" ]
}

@test "git-acp.post-push validation is pending" {
  skip "Flow not started yet"
}

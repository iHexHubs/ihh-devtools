#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/git-core.bats
# Iteración: T-AMBOS-5 (2026-04-28)

load "../../lib/utils.sh"

@test "log_success imprime en verde" {
  run log_success "Hola"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hola"* ]]
}
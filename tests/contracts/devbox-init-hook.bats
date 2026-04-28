#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/devbox-init-hook.bats
# Iteración: T-AMBOS-5 (2026-04-28)
#
# Adaptación: el repo canónico (ihh-devtools) refactorizó el init_hook
# para usar variables ($DT_ROOT, $DT_BIN, $DEVTOOLS_PATH) en lugar de
# strings literales con el path ".devtools". Los grep -F del test
# original se actualizan a la forma con variables que figura en el
# devbox.json canónico actual. El invariante validado es idéntico:
#   - init_hook resuelve root con pwd -P
#   - init_hook itera la lista de candidates con find -L
#   - init_hook exporta fallback PATH con bin locales
#   - init_hook registra alias por tool en GIT_CONFIG efímero

setup() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd -P)"
}

@test "init_hook resuelve root real con pwd -P" {
  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "pwd -P"'
  [ "$status" -eq 0 ]
}

@test "init_hook declara candidates y busca con find -L" {
  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "for d in \"\$DT_ROOT\" \"\$DT_BIN\" \"\$DT_ROOT/\$DEVTOOLS_PATH\" \"\$DT_ROOT/\$DEVTOOLS_PATH/bin\" \"\$root/bin\" \"\$root\"; do"'
  [ "$status" -eq 0 ]

  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "find -L \"\$d\" -maxdepth 4 -type f"'
  [ "$status" -eq 0 ]
}

@test "init_hook incluye fallback PATH para bin locales" {
  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "export PATH=\"\$root/bin:\$DT_BIN:\$PATH\""'
  [ "$status" -eq 0 ]

  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "hash -r >/dev/null 2>&1 || true"'
  [ "$status" -eq 0 ]
}

@test "init_hook intenta registrar alias.gp en GIT_CONFIG efimero" {
  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "for tool in acp gp rp promote feature pr lim devtools-update devtools-evidence-e2e; do"'
  [ "$status" -eq 0 ]

  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "printf -v \"GIT_CONFIG_KEY_\$idx\" '\''%s'\'' \"alias.\$tool\""'
  [ "$status" -eq 0 ]

  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "git rev-parse --show-toplevel 2>/dev/null || pwd"'
  [ "$status" -eq 0 ]

  run bash -lc 'cd "$REPO_ROOT" && jq -r ".shell.init_hook[]" devbox.json | grep -F "bash: git-\$tool script no encontrado"'
  [ "$status" -eq 0 ]
}

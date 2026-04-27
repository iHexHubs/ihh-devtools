#!/usr/bin/env bats
# tests/contracts/git-acp.bats
# Suite contractual para bin/git-acp.sh tras refactor opción F (H-IHH-14, T-IHH-15).
#
# Cubre los 4 modos de staging:
#   - confirm      (default; pide [Y/n] tras git status --short)
#   - staged       (--staged-only/--no-add; no toca el index)
#   - interactive  (--interactive/-p; git add -p)
#   - yes          (--yes/--no-confirm; git add . directo, legacy)
#
# Variable de entorno DEVTOOLS_ACP_DEFAULT_MODE controla el default cuando no
# se pasa flag explícito. Flag CLI siempre gana sobre la variable.

setup() {
    REPO_ROOT="$(git -C "${BATS_TEST_DIRNAME}" rev-parse --show-toplevel)"
    GIT_ACP_SCRIPT="${REPO_ROOT}/bin/git-acp.sh"

    # Repo efímero por test
    TMPDIR_FIXTURE="$(mktemp -d)"
    REPO="${TMPDIR_FIXTURE}/repo"
    git init -q -b feature/test "$REPO"
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" config user.name "Test"
    git -C "$REPO" config commit.gpgsign false
    git -C "$REPO" config tag.gpgsign false

    # Commit inicial vacío para tener HEAD
    git -C "$REPO" commit --allow-empty -qm "init"

    # Env para saltar dispatcher, identidad, guardas externas
    export DEVTOOLS_DISPATCH_DONE=1
    export SIMPLE_MODE=true
    export DISABLE_NO_ACP_GUARD=1
    export ENFORCE_FEATURE_BRANCH=false
    export AUTO_RENAME_TO_FEATURE=false
    export CI=1                         # Evita side effects de git config global
    unset DEVTOOLS_ACP_DEFAULT_MODE     # baseline limpio por test
}

teardown() {
    if [[ -n "${TMPDIR_FIXTURE:-}" && -d "$TMPDIR_FIXTURE" ]]; then
        rm -rf "$TMPDIR_FIXTURE"
    fi
}

# Helpers
_add_unstaged() {
    local name="${1:-extra.txt}"
    printf 'unstaged content\n' > "$REPO/$name"
}

_add_staged() {
    local name="${1:-staged.txt}"
    printf 'staged content\n' > "$REPO/$name"
    git -C "$REPO" add "$name"
}

_head_sha() {
    git -C "$REPO" rev-parse HEAD
}

# ============================================================
# Modo confirm (default)
# ============================================================

@test "confirm + stdin y => commit creado, incluye archivos no-staged" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && printf 'y\n' | bash '$GIT_ACP_SCRIPT' --no-push 'msg confirm yes'"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    # El commit incluye extra.txt
    git -C "$REPO" log -1 --name-only | grep -q "extra.txt"
}

@test "confirm + stdin n => exit no-cero, sin commit, working tree intacto" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && printf 'n\n' | bash '$GIT_ACP_SCRIPT' --no-push 'msg confirm no'"
    [ "$status" -ne 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]

    # El archivo sigue en working tree, no staged
    [ -f "$REPO/extra.txt" ]
    ! git -C "$REPO" diff --cached --quiet --exit-code 2>/dev/null
    git -C "$REPO" diff --cached --quiet
}

# ============================================================
# Modo staged (--staged-only / --no-add)
# ============================================================

@test "--staged-only con index lleno => commit incluye SOLO los paths staged" {
    _add_staged "staged.txt"
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --staged-only --no-push 'msg staged only' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    # staged.txt está en el commit
    git -C "$REPO" log -1 --name-only | grep -q "staged.txt"
    # extra.txt NO está en el commit (sigue como untracked)
    ! git -C "$REPO" log -1 --name-only | grep -q "^extra.txt$"
    [ -f "$REPO/extra.txt" ]
}

@test "--staged-only con index vacío => exit no-cero, mensaje claro, sin commit" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --staged-only --no-push 'msg staged empty' </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"staged"* ]] || [[ "$output" == *"index"* ]]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

@test "--no-add (alias) se comporta idéntico a --staged-only con index vacío" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --no-add --no-push 'msg no-add empty' </dev/null"
    [ "$status" -ne 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

# ============================================================
# Modo yes (--yes / --no-confirm)
# ============================================================

@test "--yes => git add . directo, commit incluye todo" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --yes --no-push 'msg yes' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    git -C "$REPO" log -1 --name-only | grep -q "extra.txt"
}

@test "--no-confirm (alias) se comporta idéntico a --yes" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --no-confirm --no-push 'msg no-confirm' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    git -C "$REPO" log -1 --name-only | grep -q "extra.txt"
}

# ============================================================
# Modo interactive (--interactive / -p)
# ============================================================

@test "--interactive sin TTY => exit no-cero (TTY required), sin commit" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --interactive --no-push 'msg interactive' </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TTY"* ]] || [[ "$output" == *"interactive"* ]] || [[ "$output" == *"-p"* ]]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

@test "-p (alias) sin TTY => exit no-cero idéntico a --interactive" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' -p --no-push 'msg dash p' </dev/null"
    [ "$status" -ne 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

# ============================================================
# Variable de entorno DEVTOOLS_ACP_DEFAULT_MODE
# ============================================================

@test "DEVTOOLS_ACP_DEFAULT_MODE=staged + index vacío => exit no-cero (precedencia respeta env)" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && DEVTOOLS_ACP_DEFAULT_MODE=staged bash '$GIT_ACP_SCRIPT' --no-push 'msg env staged empty' </dev/null"
    [ "$status" -ne 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

@test "Flag CLI gana sobre DEVTOOLS_ACP_DEFAULT_MODE: --yes con env=staged" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && DEVTOOLS_ACP_DEFAULT_MODE=staged bash '$GIT_ACP_SCRIPT' --yes --no-push 'msg cli wins' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    git -C "$REPO" log -1 --name-only | grep -q "extra.txt"
}

@test "DEVTOOLS_ACP_DEFAULT_MODE=foo (inválido) => exit no-cero antes de tocar el index" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && DEVTOOLS_ACP_DEFAULT_MODE=foo bash '$GIT_ACP_SCRIPT' --no-push 'msg invalid env' </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"foo"* ]] || [[ "$output" == *"inválid"* ]] || [[ "$output" == *"aceptados"* ]]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]

    # Index sigue limpio (no se tocó)
    git -C "$REPO" diff --cached --quiet
}

# ============================================================
# Tests adicionales (recomendados, suman robustez)
# ============================================================

@test "Flags incompatibles --staged-only --yes => exit no-cero" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --staged-only --yes --no-push 'msg incompat' </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"incompatibles"* ]] || [[ "$output" == *"incompat"* ]]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

@test "Mensaje obligatorio: ausencia de MSG => exit no-cero (preservado)" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --yes --no-push </dev/null"
    [ "$status" -ne 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

@test "--no-push evita push en cualquier modo: --yes --no-push no toca remote" {
    # Sin remote configurado, un push real fallaría. --no-push debe evitarlo
    # y aún así commitear.
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --yes --no-push 'msg no-push' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" != "$after" ]

    # No hay remote y aún así pasamos: prueba que --no-push se respetó
    run git -C "$REPO" remote
    [ -z "$output" ]
}

@test "--dry-run sigue siendo no-op: working tree intacto, sin commit" {
    _add_unstaged "extra.txt"
    local before
    before="$(_head_sha)"

    run bash -c "cd '$REPO' && bash '$GIT_ACP_SCRIPT' --dry-run 'msg dry run' </dev/null"
    [ "$status" -eq 0 ]

    local after
    after="$(_head_sha)"
    [ "$before" = "$after" ]
}

# ============================================================
# Invariantes del helper (lib/core/acp-mode.sh)
# ============================================================

@test "lib/core/acp-mode.sh: define las funciones públicas esperadas" {
    run grep -E "^(acp_resolve_mode|acp_check_flag_compat|acp_run_add_strategy)\(\)" "$REPO_ROOT/lib/core/acp-mode.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"acp_resolve_mode"* ]]
    [[ "$output" == *"acp_check_flag_compat"* ]]
    [[ "$output" == *"acp_run_add_strategy"* ]]
}

@test "lib/core/acp-mode.sh: invoca git add -p en modo interactive" {
    run grep -E "git add -p" "$REPO_ROOT/lib/core/acp-mode.sh"
    [ "$status" -eq 0 ]
}

@test "bin/git-acp.sh: ya no contiene 'git add .' literal directo" {
    # Permitido: dentro de strings o referencias de comentarios.
    # Prohibido: como statement ejecutable directo del script.
    # Verificación ligera: 'git add \.' como statement aparece 0 veces.
    run grep -nE "^[[:space:]]*git add \.[[:space:]]*$" "$REPO_ROOT/bin/git-acp.sh"
    [ "$status" -ne 0 ]
}

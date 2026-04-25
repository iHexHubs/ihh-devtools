#!/usr/bin/env bats
# Suite BATS para lib/core/vendor.sh
# Fase 2B: validación dry-run de vendorización (P-AMBOS-3 opción C).
#
# Casos cubiertos: 18 tests.
#  - vendor_resolve_tag (4 tests)
#  - vendor_is_excluded_tag (2 tests)
#  - vendor_compute_tree_sha (2 tests)
#  - vendor_validate_lock (5 tests)
#  - vendor_check_drift (3 tests)
#  - invariantes de la librería (2 tests)

setup() {
    REPO_ROOT="$(git -C "${BATS_TEST_DIRNAME}" rev-parse --show-toplevel)"
    source "$REPO_ROOT/lib/core/vendor.sh"
    TMPDIR_FIXTURE="$(mktemp -d)"
    FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"
}

teardown() {
    if [[ -n "${TMPDIR_FIXTURE:-}" && -d "$TMPDIR_FIXTURE" ]]; then
        rm -rf "$TMPDIR_FIXTURE"
    fi
}

# Helper: crea repo git efímero con un commit y opcionalmente un tag.
_make_repo_with_tag() {
    local dir="$1"
    local tag="${2:-}"
    git init -q -b main "$dir"
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "Test"
    git -C "$dir" config commit.gpgsign false
    git -C "$dir" config tag.gpgsign false
    printf 'hello\n' > "$dir/file.txt"
    git -C "$dir" add file.txt
    git -C "$dir" commit -qm "init"
    if [[ -n "$tag" ]]; then
        git -C "$dir" tag "$tag"
    fi
}

# ============================================================
# vendor_resolve_tag
# ============================================================

@test "vendor_resolve_tag: tag existente resuelve a SHA correcto" {
    local repo="$TMPDIR_FIXTURE/repo"
    _make_repo_with_tag "$repo" "v1.0.0"

    run vendor_resolve_tag "$repo" "v1.0.0"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{40}$ ]]

    # Cross-check: el SHA devuelto es el commit real
    local expected
    expected="$(git -C "$repo" rev-parse "v1.0.0^{commit}")"
    [ "$output" = "$expected" ]
}

@test "vendor_resolve_tag: tag inexistente falla con exit 4" {
    local repo="$TMPDIR_FIXTURE/repo"
    _make_repo_with_tag "$repo" "v1.0.0"

    run vendor_resolve_tag "$repo" "v9.9.9"
    [ "$status" -eq 4 ]
    [[ "$output" == *"v9.9.9"* ]]
    [[ "$output" == *"no existe"* ]]
}

@test "vendor_resolve_tag: tag backup/* excluido con exit 7" {
    local repo="$TMPDIR_FIXTURE/repo"
    _make_repo_with_tag "$repo" "backup/main-pre-cleanup-20260425T135148Z"

    run vendor_resolve_tag "$repo" "backup/main-pre-cleanup-20260425T135148Z"
    [ "$status" -eq 7 ]
    [[ "$output" == *"excluido"* ]]
}

@test "vendor_resolve_tag: tag archived/* excluido con exit 7" {
    local repo="$TMPDIR_FIXTURE/repo"
    _make_repo_with_tag "$repo" "archived/foo"

    run vendor_resolve_tag "$repo" "archived/foo"
    [ "$status" -eq 7 ]
    [[ "$output" == *"excluido"* ]]
}

# ============================================================
# vendor_is_excluded_tag
# ============================================================

@test "vendor_is_excluded_tag: tags válidos NO están excluidos" {
    run vendor_is_excluded_tag "v1.0.0"
    [ "$status" -eq 0 ]

    run vendor_is_excluded_tag "v0.1.0-rc.7"
    [ "$status" -eq 0 ]

    run vendor_is_excluded_tag "release/2026.04"
    [ "$status" -eq 0 ]
}

@test "vendor_is_excluded_tag: tags excluidos retornan exit 7" {
    run vendor_is_excluded_tag "backup/foo"
    [ "$status" -eq 7 ]

    run vendor_is_excluded_tag "archived/bar"
    [ "$status" -eq 7 ]

    run vendor_is_excluded_tag "backup/dev-pre-cleanup-20260425T135148Z"
    [ "$status" -eq 7 ]
}

# ============================================================
# vendor_compute_tree_sha
# ============================================================

@test "vendor_compute_tree_sha: directorio válido devuelve SHA hex 40 chars" {
    local repo="$TMPDIR_FIXTURE/repo"
    _make_repo_with_tag "$repo"

    run vendor_compute_tree_sha "$repo"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{40}$ ]]

    # Cross-check: el SHA coincide con HEAD^{tree}
    local expected
    expected="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
    [ "$output" = "$expected" ]
}

@test "vendor_compute_tree_sha: directorio que no es repo git falla con exit 1" {
    local notrepo="$TMPDIR_FIXTURE/notrepo"
    mkdir -p "$notrepo"
    printf 'hello\n' > "$notrepo/file.txt"

    run vendor_compute_tree_sha "$notrepo"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no es un repo git"* ]]
}

# ============================================================
# vendor_validate_lock
# ============================================================

@test "vendor_validate_lock: lock v1.0 sin tree_sha es válido (retrocompatibilidad)" {
    run vendor_validate_lock "$FIXTURES_DIR/lock-v1-valid.yaml"
    [ "$status" -eq 0 ]
}

@test "vendor_validate_lock: lock v1.1 con tree_sha es válido" {
    run vendor_validate_lock "$FIXTURES_DIR/lock-v1.1-valid.yaml"
    [ "$status" -eq 0 ]
}

@test "vendor_validate_lock: lock sin vendor.version falla con exit 3" {
    run vendor_validate_lock "$FIXTURES_DIR/lock-missing-version.yaml"
    [ "$status" -eq 3 ]
    [[ "$output" == *"version"* ]]
}

@test "vendor_validate_lock: lock con tree_sha mal formado falla con exit 3" {
    run vendor_validate_lock "$FIXTURES_DIR/lock-bad-tree-sha.yaml"
    [ "$status" -eq 3 ]
    [[ "$output" == *"tree_sha"* ]] || [[ "$output" == *"pattern"* ]]
}

@test "vendor_validate_lock: archivo no parseable como YAML falla con exit 1 o 3" {
    # Aceptamos exit 1 (YAML no legible) o 3 (estructura inválida tras parse parcial).
    run vendor_validate_lock "$FIXTURES_DIR/lock-bad-yaml.yaml"
    [ "$status" -eq 1 ] || [ "$status" -eq 3 ]
}

# ============================================================
# vendor_check_drift
# ============================================================

@test "vendor_check_drift: lock + repo coinciden, exit 0 con tree_sha verificado" {
    # Source repo con tag.
    local source="$TMPDIR_FIXTURE/source"
    _make_repo_with_tag "$source" "v0.1.0-rc.7"
    local source_sha source_tree
    source_sha="$(git -C "$source" rev-parse 'v0.1.0-rc.7^{commit}')"
    source_tree="$(git -C "$source" rev-parse 'v0.1.0-rc.7^{tree}')"

    # Consumer dir: .devtools como copia del source (mismo tree).
    local consumer="$TMPDIR_FIXTURE/consumer"
    mkdir -p "$consumer/.devtools"
    git init -q -b main "$consumer/.devtools"
    git -C "$consumer/.devtools" config user.email "test@example.com"
    git -C "$consumer/.devtools" config user.name "Test"
    git -C "$consumer/.devtools" config commit.gpgsign false
    printf 'hello\n' > "$consumer/.devtools/file.txt"
    git -C "$consumer/.devtools" add file.txt
    git -C "$consumer/.devtools" commit -qm "vendor"
    local consumer_tree
    consumer_tree="$(git -C "$consumer/.devtools" rev-parse 'HEAD^{tree}')"

    # Lock declara los SHAs reales del source y el tree real del consumer.
    cat > "$consumer/.devtools/lock" <<EOF
lock_version: 1
contract_schema_version: 1
vendor:
  source: github.com/example/source
  version: v0.1.0-rc.7
  ref: v0.1.0-rc.7
  sha: "$source_sha"
  tree_sha: "$consumer_tree"
  scope: full
  vendor_dir: .devtools
generated_at: "2026-04-25T18:00:00Z"
generator:
  name: ihh-devtools
  version: "0.2.0"
EOF

    run vendor_check_drift "$consumer" "$source"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "vendor_check_drift: SHA declarado distinto al real, exit 5 (drift de referencia)" {
    local source="$TMPDIR_FIXTURE/source"
    _make_repo_with_tag "$source" "v0.1.0-rc.7"

    local consumer="$TMPDIR_FIXTURE/consumer"
    mkdir -p "$consumer/.devtools"

    # Lock con SHA ficticio (no coincide con el real del tag).
    cat > "$consumer/.devtools/lock" <<'EOF'
lock_version: 1
contract_schema_version: 1
vendor:
  source: github.com/example/source
  version: v0.1.0-rc.7
  ref: v0.1.0-rc.7
  sha: "deadbeef00000000000000000000000000000000"
  scope: full
  vendor_dir: .devtools
generated_at: "2026-04-25T18:00:00Z"
generator:
  name: ihh-devtools
  version: "0.1.5"
EOF

    run vendor_check_drift "$consumer" "$source"
    [ "$status" -eq 5 ]
    [[ "$output" == *"drift-de-referencia"* ]]
}

@test "vendor_check_drift: lock sin tree_sha emite warning y exit 0" {
    local source="$TMPDIR_FIXTURE/source"
    _make_repo_with_tag "$source" "v0.1.0-rc.7"
    local source_sha
    source_sha="$(git -C "$source" rev-parse 'v0.1.0-rc.7^{commit}')"

    local consumer="$TMPDIR_FIXTURE/consumer"
    mkdir -p "$consumer/.devtools"

    cat > "$consumer/.devtools/lock" <<EOF
lock_version: 1
contract_schema_version: 1
vendor:
  source: github.com/example/source
  version: v0.1.0-rc.7
  ref: v0.1.0-rc.7
  sha: "$source_sha"
  scope: full
  vendor_dir: .devtools
generated_at: "2026-04-25T18:00:00Z"
generator:
  name: ihh-devtools
  version: "0.1.5"
EOF

    run vendor_check_drift "$consumer" "$source"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
    # El warning aparece en stderr; con run, BATS combina stderr en $output.
    [[ "$output" == *"verificación de contenido incompleta"* ]] \
        || [[ "$output" == *"sin vendor.tree_sha"* ]]
}

# ============================================================
# Invariantes de la librería (Paso 3 del prompt)
# ============================================================

@test "lib/core/vendor.sh: no usa git describe fuera de comentarios" {
    # Líneas con git describe que NO empiezan con # tras espacios/tabs.
    run grep -nE "git describe" "$REPO_ROOT/lib/core/vendor.sh"
    if [ "$status" -eq 0 ]; then
        # Hay matches: aceptables solo si todas son comentarios.
        local non_comment_hits
        non_comment_hits="$(printf '%s\n' "$output" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
        [ -z "$non_comment_hits" ]
    fi
    # Si grep retornó 1 (no matches), también pasamos.
}

@test "lib/core/vendor.sh: sin hardcoding de dominios" {
    run grep -inE "pmbok|el_rincon|iHexHubs|erd-ecosystem" "$REPO_ROOT/lib/core/vendor.sh"
    # Esperamos exit != 0 (sin matches).
    [ "$status" -ne 0 ]
}

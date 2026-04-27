#!/usr/bin/env bats
# tests/contracts/promote-workflows.bats
# Suite contractual de regresión para lib/promote/workflows/**.
#
# Cierra T-IHH-20 (B-3): congela el comportamiento actual de las funciones
# casi puras de los workflows de promoción para que SEC-2B-Phase2 (refactor
# de las ~40 menciones literales 'pmbok' en estos archivos) pueda ejecutarse
# con red de seguridad.
#
# Funciones cubiertas:
#  - lib/promote/workflows/common.sh:
#      resolve_promote_component, promote_is_protected_branch
#  - lib/promote/workflows/to-local/10-utils.sh:
#      promote_local_is_valid_tag_name, promote_local_read_overlay_tag_from_text,
#      promote_local_next_tag_from_previous
#  - lib/promote/workflows/to-local/50-k8s.sh:
#      promote_local_pull_policy
#
# Funciones NO cubiertas a propósito (techo del alcance, ver §3 del prompt B-3):
#  - orquestadores end-to-end (promote_to_*, create_hotfix, ...)
#  - funciones que requieren docker/kubectl/argocd/red/gh
#  - mensajes de log exactos (formato/emoji)

setup() {
    REPO_ROOT="$(git -C "${BATS_TEST_DIRNAME}" rev-parse --show-toplevel)"
    COMMON_SH="${REPO_ROOT}/lib/promote/workflows/common.sh"
    UTILS_SH="${REPO_ROOT}/lib/promote/workflows/to-local/10-utils.sh"
    K8S_SH="${REPO_ROOT}/lib/promote/workflows/to-local/50-k8s.sh"

    # Repo efímero por test
    TMPDIR_FIXTURE="$(mktemp -d)"
    REPO="${TMPDIR_FIXTURE}/repo"
    git init -q -b main "$REPO"
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" config user.name "Test"
    git -C "$REPO" config commit.gpgsign false
    git -C "$REPO" config tag.gpgsign false

    # Stubs mínimos de helpers que los archivos esperan disponibles. Se
    # definen en el shell del test antes de cualquier source para evitar
    # 'command not found'.
    log_info()    { echo "INFO: $*"; }
    log_warn()    { echo "WARN: $*" >&2; }
    log_error()   { echo "ERROR: $*" >&2; }
    log_success() { echo "OK: $*"; }
    die()         { echo "DIE: $*" >&2; return "${2:-1}"; }

    cd "$REPO"
}

teardown() {
    if [[ -n "${TMPDIR_FIXTURE:-}" && -d "$TMPDIR_FIXTURE" ]]; then
        rm -rf "$TMPDIR_FIXTURE"
    fi
}

# Helper: dos commits, el segundo añade los paths recibidos.
_make_commits_with_paths() {
    git -C "$REPO" commit --allow-empty -qm "init"
    local p
    for p in "$@"; do
        local d
        d="$(dirname "$p")"
        mkdir -p "$REPO/$d"
        printf 'content\n' > "$REPO/$p"
    done
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "add files"
}

# ============================================================
# resolve_promote_component (common.sh)
# ============================================================

@test "resolve_promote_component: PROMOTE_COMPONENT override gana sin mirar git" {
    source "$COMMON_SH"
    PROMOTE_COMPONENT=ihh
    run resolve_promote_component "any-range"
    [ "$status" -eq 0 ]
    [ "$output" = "ihh" ]
}

@test "resolve_promote_component: diff con apps/ihh/* => ihh" {
    _make_commits_with_paths "apps/ihh/src/file.txt" "apps/ihh/lib/foo.txt"
    source "$COMMON_SH"
    unset PROMOTE_COMPONENT
    run resolve_promote_component "HEAD~1..HEAD"
    [ "$status" -eq 0 ]
    [ "$output" = "ihh" ]
}

@test "resolve_promote_component: diff con apps/pmbok/* => pmbok" {
    _make_commits_with_paths "apps/pmbok/src/file.txt"
    source "$COMMON_SH"
    unset PROMOTE_COMPONENT
    run resolve_promote_component "HEAD~1..HEAD"
    [ "$status" -eq 0 ]
    [ "$output" = "pmbok" ]
}

@test "resolve_promote_component: diff con apps/iHexHubs/* => iHexHubs" {
    _make_commits_with_paths "apps/iHexHubs/foo.txt"
    source "$COMMON_SH"
    unset PROMOTE_COMPONENT
    run resolve_promote_component "HEAD~1..HEAD"
    [ "$status" -eq 0 ]
    [ "$output" = "iHexHubs" ]
}

@test "resolve_promote_component: diff con .devtools/* => devbox" {
    _make_commits_with_paths ".devtools/foo.txt"
    source "$COMMON_SH"
    unset PROMOTE_COMPONENT
    run resolve_promote_component "HEAD~1..HEAD"
    [ "$status" -eq 0 ]
    [ "$output" = "devbox" ]
}

@test "resolve_promote_component: diff mixto (ihh + pmbok) => ihh-ecosystem" {
    _make_commits_with_paths "apps/ihh/a.txt" "apps/pmbok/b.txt"
    source "$COMMON_SH"
    unset PROMOTE_COMPONENT
    run resolve_promote_component "HEAD~1..HEAD"
    [ "$status" -eq 0 ]
    [ "$output" = "ihh-ecosystem" ]
}

# ============================================================
# promote_is_protected_branch (common.sh)
# ============================================================

@test "promote_is_protected_branch: defaults dev/main/master/local/release => protected" {
    git -C "$REPO" commit --allow-empty -qm "init"
    source "$COMMON_SH"
    unset DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS

    run promote_is_protected_branch "dev"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "main"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "master"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "local"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "release/v1"
    [ "$status" -eq 0 ]
}

@test "promote_is_protected_branch: feature/* no es protected" {
    git -C "$REPO" commit --allow-empty -qm "init"
    source "$COMMON_SH"
    unset DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS

    run promote_is_protected_branch "feature/foo"
    [ "$status" -ne 0 ]
}

@test "promote_is_protected_branch: env override patterns => prod protegido, main no" {
    git -C "$REPO" commit --allow-empty -qm "init"
    source "$COMMON_SH"
    DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS="prod|integration"

    run promote_is_protected_branch "prod"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "integration"
    [ "$status" -eq 0 ]

    run promote_is_protected_branch "main"
    [ "$status" -ne 0 ]
}

@test "promote_is_protected_branch: branch vacío => no-cero" {
    git -C "$REPO" commit --allow-empty -qm "init"
    source "$COMMON_SH"
    unset DEVTOOLS_PROMOTE_PROTECTED_BRANCH_PATTERNS

    run promote_is_protected_branch ""
    [ "$status" -ne 0 ]
}

# ============================================================
# promote_local_is_valid_tag_name (10-utils.sh)
# ============================================================

@test "promote_local_is_valid_tag_name: tags SemVer válidos => 0" {
    source "$UTILS_SH"
    run promote_local_is_valid_tag_name "v1.2.3"
    [ "$status" -eq 0 ]

    run promote_local_is_valid_tag_name "v0.1.0-rc.7+build.40"
    [ "$status" -eq 0 ]

    run promote_local_is_valid_tag_name "ihh-v1.0.0-build.5-rev.3"
    [ "$status" -eq 0 ]
}

@test "promote_local_is_valid_tag_name: tag vacío => no-cero" {
    source "$UTILS_SH"
    run promote_local_is_valid_tag_name ""
    [ "$status" -ne 0 ]
}

@test "promote_local_is_valid_tag_name: tag con espacio o '*' => no-cero" {
    source "$UTILS_SH"

    run promote_local_is_valid_tag_name "v 1"
    [ "$status" -ne 0 ]

    run promote_local_is_valid_tag_name "v*1"
    [ "$status" -ne 0 ]

    run promote_local_is_valid_tag_name "v1@x"
    [ "$status" -ne 0 ]
}

# ============================================================
# promote_local_read_overlay_tag_from_text (10-utils.sh)
# ============================================================

@test "promote_local_read_overlay_tag_from_text: extrae el primer newTag" {
    source "$UTILS_SH"
    local result
    result="$(printf 'images:\n  - name: backend\n    newTag: v0.1.0\n  - name: frontend\n    newTag: v0.2.0\n' | promote_local_read_overlay_tag_from_text)"
    [ "$result" = "v0.1.0" ]
}

@test "promote_local_read_overlay_tag_from_text: texto sin newTag => salida vacía" {
    source "$UTILS_SH"
    local result
    result="$(printf 'images:\n  - name: backend\n    name: bar\n' | promote_local_read_overlay_tag_from_text)"
    [ -z "$result" ]
}

# ============================================================
# promote_local_next_tag_from_previous (10-utils.sh)
# ============================================================

@test "promote_local_next_tag_from_previous: prev coincide con base => rev incrementa" {
    source "$UTILS_SH"

    # Mocks de helpers que la función llama desde lib/promote/version-strategy.sh
    promote_base_tag_for_local() { echo "ihh-v1.0.0+build.5"; }
    promote_strip_rev_from_tag() {
        local t="$1"
        if [[ "$t" =~ -rev\.([0-9]+)$ ]]; then
            echo "${t%-rev.${BASH_REMATCH[1]}}"
        else
            echo "$t"
        fi
    }
    # No definimos semver_to_image_tag => la función usa fallback string sub.

    run promote_local_next_tag_from_previous "ihh-v1.0.0-build.5-rev.3"
    [ "$status" -eq 0 ]
    [ "$output" = "ihh-v1.0.0+build.5-rev.4" ]
}

@test "promote_local_next_tag_from_previous: prev no coincide con base => rev.1" {
    source "$UTILS_SH"

    promote_base_tag_for_local() { echo "ihh-v2.0.0+build.10"; }
    promote_strip_rev_from_tag() {
        local t="$1"
        if [[ "$t" =~ -rev\.([0-9]+)$ ]]; then
            echo "${t%-rev.${BASH_REMATCH[1]}}"
        else
            echo "$t"
        fi
    }

    # Previous con base distinta => prev_rev=0, next_rev=1.
    run promote_local_next_tag_from_previous "ihh-v1.0.0-build.5-rev.3"
    [ "$status" -eq 0 ]
    [ "$output" = "ihh-v2.0.0+build.10-rev.1" ]
}

# ============================================================
# promote_local_pull_policy (50-k8s.sh)
# ============================================================

@test "promote_local_pull_policy: default sin env => IfNotPresent" {
    source "$K8S_SH"
    unset DEVTOOLS_LOCAL_PULL_POLICY
    run promote_local_pull_policy
    [ "$status" -eq 0 ]
    [ "$output" = "IfNotPresent" ]
}

@test "promote_local_pull_policy: env=Never => Never (con warning a stderr)" {
    source "$K8S_SH"
    DEVTOOLS_LOCAL_PULL_POLICY=Never
    run promote_local_pull_policy
    [ "$status" -eq 0 ]
    # bats run combina stderr+stdout en $output. Verificamos el match estructural
    # con el regex de policy y que la última línea es el valor devuelto.
    [[ "$output" =~ (Always|IfNotPresent|Never) ]]
    local last
    last="$(printf '%s\n' "$output" | tail -n 1)"
    [ "$last" = "Never" ]
}

@test "promote_local_pull_policy: env=foo (inválido) => IfNotPresent con warning" {
    source "$K8S_SH"
    DEVTOOLS_LOCAL_PULL_POLICY=foo
    run promote_local_pull_policy
    [ "$status" -eq 0 ]
    [[ "$output" == *"foo"* ]]
    local last
    last="$(printf '%s\n' "$output" | tail -n 1)"
    [ "$last" = "IfNotPresent" ]
}

# ============================================================
# Invariantes estructurales
# ============================================================

@test "common.sh + 10-utils.sh + 50-k8s.sh: definen las funciones públicas esperadas" {
    source "$COMMON_SH"
    source "$UTILS_SH"
    source "$K8S_SH"

    declare -F resolve_promote_component
    declare -F promote_is_protected_branch
    declare -F promote_local_is_valid_tag_name
    declare -F promote_local_read_overlay_tag_from_text
    declare -F promote_local_next_tag_from_previous
    declare -F promote_local_pull_policy
}

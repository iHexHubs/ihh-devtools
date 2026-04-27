#!/usr/bin/env bats
# tests/contracts/services.bats
# Suite contractual del helper canónico lib/core/services.sh.
# Implementa la jerarquía oficial registrada en ADR 0002 (B-4) y
# consumida por SEC-2B-Phase2 / B-5.
#
# Funciones cubiertas:
#   services_resolve_path
#   services_load
#   services_resolve_by_id
#   services_resolve_by_path
#   services_image_for
#   services_argocd_app_for
#   services_changelog_for
#   services_local_image_name
#
# Smoke con services.yaml real de erd-ecosystem (lectura, no modificación).

setup() {
    REPO_ROOT="$(git -C "${BATS_TEST_DIRNAME}" rev-parse --show-toplevel)"
    SERVICES_SH="${REPO_ROOT}/lib/core/services.sh"

    TMPDIR_FIXTURE="$(mktemp -d)"
    cd "$TMPDIR_FIXTURE"

    # Stubs mínimos de logging.
    log_info()    { echo "INFO: $*"; }
    log_warn()    { echo "WARN: $*" >&2; }
    log_error()   { echo "ERROR: $*" >&2; }
    log_success() { echo "OK: $*"; }
    die()         { echo "DIE: $*" >&2; return "${2:-1}"; }

    # Limpia variables del helper para asegurar test aislado.
    unset DEVTOOLS_REGISTRIES_DEPLOY DEVTOOLS_ARGOCD_APP_TEMPLATE
    unset __DEVTOOLS_SERVICES_LOADED __DEVTOOLS_SERVICES_PATH __DEVTOOLS_SERVICES_CONTENT
}

teardown() {
    if [[ -n "${TMPDIR_FIXTURE:-}" && -d "$TMPDIR_FIXTURE" ]]; then
        rm -rf "$TMPDIR_FIXTURE"
    fi
}

# Helper: crea services.yaml básico en TMPDIR_FIXTURE.
_make_services_yaml() {
    local target="${1:-services.yaml}"
    cat > "${TMPDIR_FIXTURE}/${target}" <<'EOF'
services:
  - id: web-backend
    kind: service
    path: apps/web/backend
    image: ghcr.io/myorg/web/backend
  - id: web-frontend
    kind: webapp
    path: apps/web/frontend
    image: ghcr.io/myorg/web/frontend
  - id: standalone-cli
    kind: library
    path: tools/cli
EOF
}

# ============================================================
# services_resolve_path
# ============================================================

@test "services_resolve_path: ENV var explícita gana sobre defaults" {
    _make_services_yaml "custom.yaml"
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/custom.yaml"
    run services_resolve_path
    [ "$status" -eq 0 ]
    [ "$output" = "${TMPDIR_FIXTURE}/custom.yaml" ]
}

@test "services_resolve_path: lee devtools.repo.yaml si ENV no está" {
    _make_services_yaml "from-contract.yaml"
    cat > "${TMPDIR_FIXTURE}/devtools.repo.yaml" <<EOF
schema_version: 1
registries:
  deploy: from-contract.yaml
EOF
    git init -q -b main "$TMPDIR_FIXTURE"
    source "$SERVICES_SH"
    cd "$TMPDIR_FIXTURE"
    unset DEVTOOLS_REGISTRIES_DEPLOY
    REPO_ROOT="$TMPDIR_FIXTURE"
    run services_resolve_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"from-contract.yaml" ]]
}

@test "services_resolve_path: archivo declarado pero no existe => exit 5" {
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/no-existe.yaml"
    run services_resolve_path
    [ "$status" -eq 5 ]
    [[ "$output" == *"No se puede resolver"* ]]
    [[ "$output" == *"DEVTOOLS_REGISTRIES_DEPLOY"* ]]
}

@test "services_resolve_path: default ecosystem/services.yaml cuando no hay ENV ni cableado" {
    git init -q -b main "$TMPDIR_FIXTURE"
    mkdir -p "${TMPDIR_FIXTURE}/ecosystem"
    _make_services_yaml "ecosystem/services.yaml"
    source "$SERVICES_SH"
    cd "$TMPDIR_FIXTURE"
    unset DEVTOOLS_REGISTRIES_DEPLOY
    REPO_ROOT="$TMPDIR_FIXTURE"
    run services_resolve_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"ecosystem/services.yaml" ]]
}

# ============================================================
# services_load
# ============================================================

@test "services_load: YAML válido carga y cachea" {
    _make_services_yaml "services.yaml"
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_load
    [ "$status" -eq 0 ]
}

@test "services_load: YAML inválido => exit 6" {
    printf '{[invalid yaml: !!!\n' > "${TMPDIR_FIXTURE}/bad.yaml"
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/bad.yaml"
    run services_load
    [ "$status" -eq 6 ]
    [[ "$output" == *"no parsea"* ]] || [[ "$output" == *"YAML"* ]]
}

# ============================================================
# services_resolve_by_id
# ============================================================

@test "services_resolve_by_id: id existente => record con campos" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_resolve_by_id "web-backend"
    [ "$status" -eq 0 ]
    [[ "$output" == *"id: web-backend"* ]]
    [[ "$output" == *"kind: service"* ]]
    [[ "$output" == *"path: apps/web/backend"* ]]
}

@test "services_resolve_by_id: id inexistente => exit 5" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_resolve_by_id "no-existe"
    [ "$status" -eq 5 ]
    [[ "$output" == *"id=no-existe"* ]]
}

# ============================================================
# services_resolve_by_path
# ============================================================

@test "services_resolve_by_path: path matchea prefix => emite id correcto" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_resolve_by_path "apps/web/backend/src/main.py"
    [ "$status" -eq 0 ]
    [ "$output" = "web-backend" ]
}

@test "services_resolve_by_path: path no matchea => exit 5" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_resolve_by_path "unrelated/dir/file.txt"
    [ "$status" -eq 5 ]
}

# ============================================================
# services_image_for
# ============================================================

@test "services_image_for: ENV var explícita gana" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    DEVTOOLS_IMAGE_FOR_WEB_BACKEND="custom-registry/override:latest"
    run services_image_for "web-backend"
    [ "$status" -eq 0 ]
    [ "$output" = "custom-registry/override:latest" ]
}

@test "services_image_for: services[].image se usa cuando ENV no está" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    unset DEVTOOLS_IMAGE_FOR_WEB_BACKEND
    run services_image_for "web-backend"
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/myorg/web/backend" ]
}

@test "services_image_for: sin ENV ni declarativo => exit 5" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    # standalone-cli no tiene .image declarado.
    run services_image_for "standalone-cli"
    [ "$status" -eq 5 ]
    [[ "$output" == *"No se puede resolver"* ]]
    [[ "$output" == *"imagen"* ]]
}

# ============================================================
# services_argocd_app_for
# ============================================================

@test "services_argocd_app_for: ENV var por entorno gana" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    DEVTOOLS_ARGOCD_APP_DEV_WEB_BACKEND="custom-dev-app"
    run services_argocd_app_for "web-backend" "dev"
    [ "$status" -eq 0 ]
    [ "$output" = "custom-dev-app" ]
}

@test "services_argocd_app_for: sin ENV => template default <env>-<id>-app" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    unset DEVTOOLS_ARGOCD_APP_DEV_WEB_BACKEND DEVTOOLS_ARGOCD_APP_TEMPLATE
    run services_argocd_app_for "web-backend" "dev"
    [ "$status" -eq 0 ]
    [ "$output" = "dev-web-backend-app" ]
}

# ============================================================
# services_changelog_for
# ============================================================

@test "services_changelog_for: convención apps/<id>/CHANGELOG.md" {
    _make_services_yaml
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="${TMPDIR_FIXTURE}/services.yaml"
    run services_changelog_for "web-backend"
    [ "$status" -eq 0 ]
    [ "$output" = "apps/web-backend/CHANGELOG.md" ]
}

# ============================================================
# services_local_image_name
# ============================================================

@test "services_local_image_name: ENV var explícita gana" {
    source "$SERVICES_SH"
    DEVTOOLS_LOCAL_IMAGE_BACKEND_WEB_BACKEND="custom-local-image"
    run services_local_image_name "web-backend" "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "custom-local-image" ]
}

@test "services_local_image_name: convención <id>-<component>" {
    source "$SERVICES_SH"
    unset DEVTOOLS_LOCAL_IMAGE_BACKEND_WEB_BACKEND
    run services_local_image_name "web-backend" "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "web-backend-backend" ]
}

# ============================================================
# Smoke tests con services.yaml real de erd-ecosystem (read-only)
# ============================================================

@test "smoke: services.yaml de erd-ecosystem carga correctamente" {
    local real_yaml="/webapps/erd-ecosystem/ecosystem/services.yaml"
    if [[ ! -f "$real_yaml" ]]; then
        skip "services.yaml de erd-ecosystem no disponible"
    fi
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="$real_yaml"
    run services_load
    [ "$status" -eq 0 ]
}

@test "smoke: services_resolve_by_id 'pmbok-backend' resuelve con services.yaml real" {
    local real_yaml="/webapps/erd-ecosystem/ecosystem/services.yaml"
    if [[ ! -f "$real_yaml" ]]; then
        skip "services.yaml de erd-ecosystem no disponible"
    fi
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="$real_yaml"
    run services_resolve_by_id "pmbok-backend"
    [ "$status" -eq 0 ]
    [[ "$output" == *"id: pmbok-backend"* ]]
    [[ "$output" == *"kind: service"* ]]
}

@test "smoke: services_resolve_by_path 'apps/pmbok/backend/foo.py' emite 'pmbok-backend'" {
    local real_yaml="/webapps/erd-ecosystem/ecosystem/services.yaml"
    if [[ ! -f "$real_yaml" ]]; then
        skip "services.yaml de erd-ecosystem no disponible"
    fi
    source "$SERVICES_SH"
    DEVTOOLS_REGISTRIES_DEPLOY="$real_yaml"
    run services_resolve_by_path "apps/pmbok/backend/foo.py"
    [ "$status" -eq 0 ]
    [ "$output" = "pmbok-backend" ]
}

# ============================================================
# Invariante estructural
# ============================================================

@test "lib/core/services.sh: define las funciones públicas esperadas" {
    source "$SERVICES_SH"
    declare -F services_resolve_path
    declare -F services_load
    declare -F services_resolve_by_id
    declare -F services_resolve_by_path
    declare -F services_image_for
    declare -F services_argocd_app_for
    declare -F services_changelog_for
    declare -F services_local_image_name
}

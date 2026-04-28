#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/promote.bats
# Iteración: T-AMBOS-5 (2026-04-28)
#
# Adaptación: paths "\.devtools/lib/..." sustituidos por "lib/..." porque
# bats se invoca desde repo root del canónico.

# Título: push_branch_force usa --force-with-lease por defecto
function test_case_001 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/core/git-ops.sh"
    git() {
      if [[ "${1:-}" == "push" ]]; then
        shift
        printf "git push %s\n" "$*"
        return 0
      fi
      command git "$@"
    }
    unset DEVTOOLS_FORCE_PUSH_MODE
    push_branch_force "local" "origin"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"git push origin local --force-with-lease"* ]]
}

# Título: push_branch_force usa --force y muestra warning en modo force
function test_case_002 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/core/git-ops.sh"
    git() {
      if [[ "${1:-}" == "push" ]]; then
        shift
        printf "git push %s\n" "$*"
        return 0
      fi
      command git "$@"
    }
    export DEVTOOLS_FORCE_PUSH_MODE=force
    push_branch_force "local" "origin" 2>&1
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"⚠️  Modo peligro: DEVTOOLS_FORCE_PUSH_MODE=force (sin lease)"* ]]
  [[ "$output" == *"git push origin local --force"* ]]
}

# Título: promote local resuelve tag_target_sha desde source_sha y falla si está vacío
function test_case_003 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "local" ]]; then
        return 1
      fi
      command git "$@"
    }
    out="$(promote_local_resolve_tag_target_sha "abc123def")"
    [ "$out" = "abc123def" ]
  '
  [ "$status" -eq 0 ]

  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "local" ]]; then
        echo "deadbeef"
        return 0
      fi
      command git "$@"
    }
    out="$(promote_local_resolve_tag_target_sha "abc123def")"
    [ "$out" = "deadbeef" ]
  '
  [ "$status" -eq 0 ]

  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "local" ]]; then
        return 1
      fi
      command git "$@"
    }
    promote_local_resolve_tag_target_sha ""
  '
  [ "$status" -ne 0 ]
}

# Título: Owner GitHub omite tagging local
function test_case_004 { #@test
  run bash -c '
    set -euo pipefail
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/.github/workflows"
    : > "$tmp/.github/workflows/tag-final-on-main.yml"
    export REPO_ROOT="$tmp"
    source "lib/promote/workflows/to-local.sh"
    promote_local_resolve_tag_owner
    echo "Owner tags = ${PROMOTE_TAG_OWNER} | Razón = ${PROMOTE_TAG_OWNER_REASON}"
    if [[ "${PROMOTE_TAG_OWNER}" == "GitHub" ]]; then
      echo "Checkpoint: tag skipped"
    fi
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Owner tags = GitHub | Razón = workflow"* ]]
  [[ "$output" == *"Checkpoint: tag skipped"* ]]
}

# Título: promote local carga gate_required_workflows_on_sha_or_die
function test_case_005 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    declare -F gate_required_workflows_on_sha_or_die >/dev/null
  '
  [ "$status" -eq 0 ]
}

# Título: runtime local se detecta por contexto kind/minikube/docker-desktop
function test_case_006 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    [ "$(promote_local_runtime_from_context "kind")" = "kind" ]
    [ "$(promote_local_runtime_from_context "kind-dev")" = "kind" ]
    [ "$(promote_local_runtime_from_context "minikube")" = "minikube" ]
    [ "$(promote_local_runtime_from_context "docker-desktop")" = "docker-desktop" ]
  '

  [ "$status" -eq 0 ]
}

# Título: cluster kind se extrae desde el contexto
function test_case_007 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    [ "$(promote_local_kind_cluster_from_context "kind-lab")" = "lab" ]
  '

  [ "$status" -eq 0 ]
}

# Título: pull policy local por defecto retorna IfNotPresent
function test_case_008 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    unset DEVTOOLS_LOCAL_PULL_POLICY
    out="$(promote_local_pull_policy)"
    [ "$out" = "IfNotPresent" ]
  '

  [ "$status" -eq 0 ]
}

# Título: pull policy local con Never retorna Never (opt-in)
function test_case_009 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    export DEVTOOLS_LOCAL_PULL_POLICY=Never
    out="$(promote_local_pull_policy)"
    [ "$out" = "Never" ]
  '

  [ "$status" -eq 0 ]
}

# Título: pull policy local invalida se ignora y avisa IfNotPresent
function test_case_010 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    export DEVTOOLS_LOCAL_PULL_POLICY=Always
    raw="$(promote_local_pull_policy 2>&1)"
    last="$(printf "%s\n" "$raw" | tail -n1)"
    [ "$last" = "IfNotPresent" ]
    [[ "$raw" == *"inválido"* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: contexto kind con multiples clusters falla y exige seleccion explicita
function test_case_011 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    die() { echo "$1" >&2; return 1; }
    kubectl() {
      if [[ "${1:-}" == "config" && "${2:-}" == "current-context" ]]; then
        echo "kind"
        return 0
      fi
      return 0
    }
    kind() {
      if [[ "${1:-}" == "get" && "${2:-}" == "clusters" ]]; then
        printf "alpha\nbeta\n"
        return 0
      fi
      return 0
    }
    promote_local_kind_cluster_name
  '

  [ "$status" -ne 0 ]
  [[ "$output" == *"DEVTOOLS_KIND_CLUSTER_NAME"* ]]
  [[ "$output" == *"kind-<cluster>"* ]]
}

# Título: load a kind usa kind load docker-image con nombre de cluster
function test_case_012 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    log_info(){ :; }
    kind() {
      if [[ "${1:-}" == "get" && "${2:-}" == "clusters" ]]; then
        echo "dev"
        return 0
      fi
      if [[ "${1:-}" == "load" && "${2:-}" == "docker-image" ]]; then
        shift 2
        printf "kind load docker-image %s\n" "$*"
        return 0
      fi
      return 0
    }
    kubectl() {
      if [[ "${1:-}" == "config" && "${2:-}" == "current-context" ]]; then
        echo "kind-dev"
        return 0
      fi
      return 0
    }
    out="$(promote_local_load_image_to_runtime "kind" "pmbok-backend:tag-1")"
    [[ "$out" == *"--name dev"* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: load a minikube usa minikube image load
function test_case_013 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    log_info(){ :; }
    minikube() {
      if [[ "${1:-}" == "image" && "${2:-}" == "load" ]]; then
        shift 2
        printf "minikube image load %s\n" "$*"
        return 0
      fi
      return 0
    }
    out="$(promote_local_load_image_to_runtime "minikube" "pmbok-frontend:tag-2")"
    [[ "$out" == *"pmbok-frontend:tag-2"* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: preflight minikube valida backend y frontend con mismo tag
function test_case_014 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    log_info(){ :; }
    minikube() {
      if [[ "${1:-}" == "image" && "${2:-}" == "ls" ]]; then
        printf "pmbok-backend:tag-ok\npmbok-frontend:tag-ok\n"
        return 0
      fi
      return 0
    }
    promote_local_preflight_images_or_die "minikube" "tag-ok"
  '

  [ "$status" -eq 0 ]
}

# Título: preflight minikube falla con mensaje claro cuando falta imagen
function test_case_015 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ :; }
    die() { echo "$1" >&2; return 1; }
    minikube() {
      if [[ "${1:-}" == "image" && "${2:-}" == "ls" ]]; then
        printf "pmbok-backend:tag-miss\n"
        return 0
      fi
      return 0
    }
    promote_local_preflight_images_or_die "minikube" "tag-miss"
  '

  [ "$status" -ne 0 ]
  [[ "$output" == *"Imagen faltante en Docker local: pmbok-frontend:tag-miss. Recompila/retag antes de promote local."* ]]
}

# Título: preflight kind usa salida equivalente a crictl images
function test_case_016 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    log_info(){ :; }
    promote_local_kind_cluster_name() { echo "dev"; }
    promote_local_kind_nodes() { printf "dev-control-plane\ndev-worker\n"; }
    promote_local_kind_node_images() {
      local node="${1:-}"
      if [[ "$node" == "dev-control-plane" ]]; then
        printf "IMAGE TAG\npmbok-backend kindtag\npmbok-frontend kindtag\n"
        return 0
      fi
      printf "IMAGE TAG\npmbok-backend kindtag\npmbok-frontend kindtag\n"
      return 0
    }
    promote_local_preflight_images_or_die "kind" "kindtag"
  '

  [ "$status" -eq 0 ]
}

# Título: promote local carga gate_required_workflows_on_sha_or_die desde checks.sh
function test_case_017 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    unset -f gate_required_workflows_on_sha_or_die >/dev/null 2>&1 || true
    promote_local_ensure_checks_loaded
    declare -F gate_required_workflows_on_sha_or_die >/dev/null
  '

  [ "$status" -eq 0 ]
}

# Título: gate local omite validacion cuando REQUIRED_WORKFLOWS_LOCAL esta vacio
function test_case_018 { #@test
  run bash -c '
    set -euo pipefail
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/config"
    cat > "$tmp/config/workflows.conf" <<'"'"'EOF'"'"'
REQUIRED_WORKFLOWS_DEV=("release-please.yaml")
REQUIRED_WORKFLOWS_LOCAL=()
EOF
    export REPO_ROOT="$tmp"
    source "lib/promote/workflows/checks.sh"
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    gate_required_workflows_on_sha_or_die "abc123def456" "feature/x" "local"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"REQUIRED_WORKFLOWS_LOCAL vacío"* ]]
}

# Título: promote dev sin upstream hace auto-push antes del gate
function test_case_019 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "remote" && "${2:-}" == "get-url" && "${3:-}" == "origin" ]]; then
        echo "git@github.com:org/repo.git"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--abbrev-ref" && "${3:-}" == "--symbolic-full-name" && "${4:-}" == "@{u}" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "ls-remote" && "${2:-}" == "--heads" && "${3:-}" == "origin" ]]; then
        echo "abc refs/heads/dev"
        return 0
      fi
      if [[ "${1:-}" == "push" && "${2:-}" == "-u" && "${3:-}" == "origin" && "${4:-}" == "HEAD:refs/heads/feature/t37" ]]; then
        echo "PUSH_OK feature/t37"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--short" ]]; then
        echo "abc1234"
        return 0
      fi
      command git "$@"
    }

    promote_dev_ensure_ci_ref_or_die "feature/t37" "abc123def456"
    [ "${DEVTOOLS_PROMOTE_GATE_REF:-}" = "feature/t37" ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"PUSH_OK feature/t37"* ]]
  [[ "$output" != *"PENDING"* ]]
}

# Título: promote dev sin upstream y push fallido devuelve RC=2 con mensaje accionable
function test_case_020 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "remote" && "${2:-}" == "get-url" && "${3:-}" == "origin" ]]; then
        echo "git@github.com:org/repo.git"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--abbrev-ref" && "${3:-}" == "--symbolic-full-name" && "${4:-}" == "@{u}" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "ls-remote" && "${2:-}" == "--heads" && "${3:-}" == "origin" ]]; then
        echo "abc refs/heads/dev"
        return 0
      fi
      if [[ "${1:-}" == "push" && "${2:-}" == "-u" && "${3:-}" == "origin" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--short" ]]; then
        echo "abc1234"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "HEAD" ]]; then
        echo "abc123def456"
        return 0
      fi
      command git "$@"
    }

    set +e
    promote_dev_ensure_ci_ref_or_die "feature/t37" "abc123def456"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Reintenta: git push -u origin HEAD:refs/heads/feature/t37"* ]]
  [[ "$output" == *"Verifica acceso: ssh -T git@github.com"* ]]
  [[ "$output" == *"Verifica llave cargada: ssh-add -l"* ]]
}

# Título: promote dev sin origin accesible devuelve RC=2 con instruccion de remote
function test_case_021 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "remote" && "${2:-}" == "get-url" && "${3:-}" == "origin" ]]; then
        return 1
      fi
      command git "$@"
    }

    set +e
    promote_dev_ensure_ci_ref_or_die "feature/t37" "abc123def456"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"No hay remote 'origin' o no es accesible"* ]]
  [[ "$output" == *"Verifica: git remote -v"* ]]
  [[ "$output" == *"git push -u <remote> HEAD:<branch>"* ]]
}

# Título: promote dev detecta ramas protegidas por default
function test_case_022 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    promote_dev_is_protected_branch "dev"
    promote_dev_is_protected_branch "main"
    promote_dev_is_protected_branch "local"
    promote_dev_is_protected_branch "release/2026.02"
    ! promote_dev_is_protected_branch "feature/t38"
  '

  [ "$status" -eq 0 ]
}

# Título: preflight docker devuelve RC=2 con mensaje accionable cuando docker no esta listo
function test_case_023 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }
    export DEVTOOLS_PROMOTE_REQUIRE_DOCKER=1
    docker() { return 1; }

    set +e
    promote_dev_runtime_preflight_or_die "dev"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker no está listo. Enciende Docker daemon/Docker Desktop o sudo systemctl start docker"* ]]
}

# Título: preflight argocd devuelve RC=2 cuando no hay login
function test_case_024 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }
    export DEVTOOLS_PROMOTE_REQUIRE_DOCKER=0
    export DEVTOOLS_PROMOTE_ARGOCD_REQUIRED=1

    argocd() {
      if [[ "${1:-}" == "account" && "${2:-}" == "get-user-info" ]]; then
        return 1
      fi
      return 0
    }

    set +e
    promote_dev_runtime_preflight_or_die "feature/t38"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"ArgoCD CLI no disponible o sin login. Ejecuta: argocd login <server> ..."* ]]
}

# Título: preflight en rama protegida omite ArgoCD
function test_case_025 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    export DEVTOOLS_PROMOTE_REQUIRE_DOCKER=0

    argocd() {
      echo "NO_DEBERIA_LLAMARSE"
      return 1
    }

    promote_dev_runtime_preflight_or_die "release/2026.02"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Rama fuente protegida 'release/2026.02': se omite preflight ArgoCD."* ]]
  [[ "$output" != *"NO_DEBERIA_LLAMARSE"* ]]
}

# Título: push de tag fallido devuelve RC=2 con comando exacto
function test_case_026 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "tag" && "${2:-}" == "-a" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "refs/tags/v1.2.3-rc.1+build.1" ]]; then
        return 1
      fi
      command git "$@"
    }

    set +e
    promote_dev_ensure_tag_remote_or_die "v1.2.3-rc.1+build.1" "abc123def456"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"No pude pushear el tag. Ejecuta: git push origin refs/tags/v1.2.3-rc.1+build.1"* ]]
}

# Título: argocd sync usa tag del promote y termina en OK
function test_case_027 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }

    argocd() {
      if [[ "${1:-}" == "app" && "${2:-}" == "set" ]]; then
        echo "SET_OK $*"
        return 0
      fi
      if [[ "${1:-}" == "app" && "${2:-}" == "sync" ]]; then
        echo "SYNC_OK $*"
        return 0
      fi
      if [[ "${1:-}" == "app" && "${2:-}" == "wait" ]]; then
        echo "WAIT_OK $*"
        return 0
      fi
      return 0
    }

    promote_dev_sync_argocd_with_tag_or_die "v1.2.3-rc.1+build.1"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"ArgoCD: set revision pmbok -> v1.2.3-rc.1+build.1"* ]]
  [[ "$output" == *"SYNC_OK app sync pmbok"* ]]
  [[ "$output" == *"ArgoCD: sync pmbok OK"* ]]
}

# Título: cleanup de rama usa auto-delete cuando se habilita en modo yes
function test_case_028 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/common.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }

    export DEVTOOLS_ASSUME_YES=1
    export DEVTOOLS_PROMOTE_DELETE_SOURCE_BRANCH=1

    git() {
      if [[ "${1:-}" == "for-each-ref" ]]; then
        echo "origin/feature/t38"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        echo "dev"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "-D" && "${3:-}" == "feature/t38" ]]; then
        echo "Deleted branch feature/t38"
        return 0
      fi
      if [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "--delete" && "${4:-}" == "feature/t38" ]]; then
        echo "Deleted remote branch feature/t38"
        return 0
      fi
      command git "$@"
    }

    maybe_delete_source_branch "feature/t38"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Rama borrada: feature/t38"* ]]
  [[ "$output" == *"Rama remota borrada."* ]]
}

# Título: gate por SHA reevalua despues de watch y queda verde cuando pasa a success
function test_case_029 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/checks.sh"

    log_info() { echo "$*"; }
    log_warn() { echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }
    print_run_link(){ :; }
    is_tty() { return 0; }

    load_required_workflows_dev_or_die() {
      REQUIRED_WORKFLOWS_DEV=("ci.yaml")
      return 0
    }
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/.github/workflows"
    : > "${tmp}/.github/workflows/ci.yaml"
    export REPO_ROOT="${tmp}"

    __meta_state_file="$(mktemp)"
    echo "0" > "$__meta_state_file"
    __wf_meta_for_sha_once() {
      local calls
      calls="$(cat "$__meta_state_file")"
      calls=$((calls + 1))
      echo "$calls" > "$__meta_state_file"
      if [[ "$calls" -eq 1 ]]; then
        echo "123|in_progress|"
      else
        echo "123|completed|success"
      fi
    }

    __watch_state_file="$(mktemp)"
    echo "0" > "$__watch_state_file"
    watch_workflow_run_if_any() {
      local calls
      calls="$(cat "$__watch_state_file")"
      calls=$((calls + 1))
      echo "$calls" > "$__watch_state_file"
      return 0
    }

    export DEVTOOLS_GATE_PENDING_TRIES=1
    export DEVTOOLS_GATE_PENDING_POLL_SECONDS=0
    export DEVTOOLS_GATE_WAIT_TIMEOUT_SECONDS=3
    export DEVTOOLS_GATE_WAIT_POLL_SECONDS=1
    gate_required_workflows_on_sha_or_die "abc123def456" "feature/x" "dev"
    __meta_calls="$(cat "$__meta_state_file")"
    __watch_calls="$(cat "$__watch_state_file")"
    rm -f "$__meta_state_file" "$__watch_state_file"
    rm -rf "$tmp"
    [[ "$__watch_calls" -ge 1 ]]
    [[ "$__meta_calls" -ge 2 ]]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate OK"* ]]
}

# Título: gate por SHA reporta workflows faltantes con mensaje explicito
function test_case_030 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/checks.sh"

    log_info() { :; }
    log_warn() { echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ :; }
    print_run_link(){ :; }
    is_tty() { return 1; }

    load_required_workflows_dev_or_die() {
      REQUIRED_WORKFLOWS_DEV=("ci.yaml" "lint.yaml")
      return 0
    }
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/.github/workflows"
    : > "${tmp}/.github/workflows/ci.yaml"
    : > "${tmp}/.github/workflows/lint.yaml"
    export REPO_ROOT="${tmp}"

    __wf_meta_for_sha_once() { return 1; }
    watch_workflow_run_if_any() { return 0; }

    export DEVTOOLS_GATE_PENDING_TRIES=1
    export DEVTOOLS_GATE_PENDING_POLL_SECONDS=0
    export DEVTOOLS_GATE_WAIT_TIMEOUT_SECONDS=1
    export DEVTOOLS_GATE_WAIT_POLL_SECONDS=1
    gate_required_workflows_on_sha_or_die "abc123def456" "feature/x" "dev"
    rm -rf "$tmp"
  '

  [ "$status" -ne 0 ]
  [[ "$output" == *"Faltan 2/2 workflows"* ]]
  [[ "$output" == *"ci.yaml"* ]]
  [[ "$output" == *"lint.yaml"* ]]
}

# Título: promote local aplica estrategia seleccionada para actualizar rama local
function test_case_031 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }
    die(){ echo "DIE:$*" >&2; return 1; }
    branch_exists_remote(){ return 0; }
    ensure_local_branch_tracks_remote(){ echo "TRACK:$*"; return 0; }

    git() {
      if [[ "${1:-}" == "checkout" ]]; then
        echo "CHECKOUT:$*"
        return 0
      fi
      if [[ "${1:-}" == "fetch" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "reset" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "merge" || ("${1:-}" == "-c" && "${3:-}" == "merge") ]]; then
        echo "MERGE:$*"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "HEAD" ]]; then
        echo "abc123def456"
        return 0
      fi
      command git "$@"
    }

    export DEVTOOLS_PROMOTE_STRATEGY=merge-theirs
    promote_local_apply_strategy_to_local_or_die "abc123def456" "local"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"TRACK:local origin"* ]]
  [[ "$output" == *"Estrategia aplicada: local <- abc123d (strategy=merge-theirs, sha=abc123d)"* ]]
}

# Título: promote local ofrece borrar rama fuente cuando estás en local y no protegida
function test_case_032 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    log_info(){ echo "$*"; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }
    log_success(){ :; }
    export DEVTOOLS_PROMOTE_POST_BRANCH=""
    export DEVTOOLS_PROMOTE_PRUNE_SOURCE_BRANCH=1

    git() {
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        echo "local"
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/heads/feature/t40" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "for-each-ref" ]]; then
        echo "origin/feature/t40"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "-D" && "${3:-}" == "feature/t40" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "--delete" && "${4:-}" == "feature/t40" ]]; then
        return 0
      fi
      return 0
    }

    promote_local_is_protected_branch() { return 1; }

    promote_local_offer_delete_source_branch_if_needed "feature/t40"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Rama local eliminada: feature/t40"* ]]
  [[ "$output" == *"Rama remota eliminada: origin/feature/t40"* ]]
}

# Título: promote local configura ArgoCD por kubectl aunque no haya CLI argocd
function test_case_033 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    marker="$(mktemp)"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }

    argocd() { return 127; }
    devbox() { return 127; }
    promote_local_ensure_remote_tag_or_die() { return 0; }

    kubectl() {
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "get" && "${4:-}" == "application" ]]; then
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.sync\\.status\\}"; then
          echo "Synced"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.health\\.status\\}"; then
          echo "Healthy"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.operationState\\.phase\\}"; then
          echo "Succeeded"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.operationState\\.message\\}"; then
          echo ""
          return 0
        fi
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "patch" && "${4:-}" == "application" ]]; then
        if printf "%s" "$*" | rg -q "targetRevision"; then
          echo "PATCH_REV" >> "$marker"
        elif printf "%s" "$*" | rg -q "syncPolicy"; then
          echo "PATCH_POLICY" >> "$marker"
        elif printf "%s" "$*" | rg -q "\"operation\""; then
          echo "PATCH_OPERATION" >> "$marker"
        fi
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "annotate" && "${4:-}" == "application" ]]; then
        echo "ANNOTATE_REFRESH" >> "$marker"
        return 0
      fi
      return 0
    }

    promote_local_argocd_sync_by_tag_or_die "v1.2.3-rc.1+build.1-rev.1" "pmbok-backend-app" "30"
    echo "SYNC_SKIPPED=${PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED:-}"
    cat "$marker"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"PATCH_REV"* ]]
  [[ "$output" == *"PATCH_POLICY"* ]]
  [[ "$output" == *"PATCH_OPERATION"* ]]
  [[ "$output" == *"ANNOTATE_REFRESH"* ]]
  [[ "$output" == *"SYNC_SKIPPED=0"* ]]
}

# Título: resolve GitOps revision prioriza override > env tag > final_tag > local
function test_case_034 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    DEVTOOLS_GITOPS_REVISION="v9.9.9-rc.1+build.1-rev.1"
    DEVTOOLS_PROMOTE_TAG="v1.0.0-rc.1+build.1-rev.1"
    out1="$(promote_local_resolve_gitops_revision "v0.0.1-rc.1+build.1-rev.1")"

    unset DEVTOOLS_GITOPS_REVISION
    out2="$(promote_local_resolve_gitops_revision "v0.0.2-rc.1+build.1-rev.1")"

    unset DEVTOOLS_PROMOTE_TAG
    out3="$(promote_local_resolve_gitops_revision "v0.0.3-rc.1+build.1-rev.1")"

    out4="$(promote_local_resolve_gitops_revision "")"

    echo "OUT1=$out1"
    echo "OUT2=$out2"
    echo "OUT3=$out3"
    echo "OUT4=$out4"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"OUT1=v9.9.9-rc.1+build.1-rev.1"* ]]
  [[ "$output" == *"OUT2=v1.0.0-rc.1+build.1-rev.1"* ]]
  [[ "$output" == *"OUT3=v0.0.3-rc.1+build.1-rev.1"* ]]
  [[ "$output" == *"OUT4=local"* ]]
}

# Título: promote local NO delega sync a common (evita modo server)
function test_case_035 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    marker="$(mktemp)"
    export DEVTOOLS_ARGOCD_POLL_SECS=1

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }

    promote_argocd_sync_by_tag_or_die() {
      echo "COMMON_SHOULD_NOT_BE_CALLED"
      return 2
    }

    argocd() { return 127; }
    devbox() { return 127; }
    promote_local_ensure_remote_tag_or_die() { return 0; }

    kubectl() {
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "get" && "${4:-}" == "application" ]]; then
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.sync\\.status\\}"; then
          echo "Synced"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.health\\.status\\}"; then
          echo "Healthy"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.operationState\\.phase\\}"; then
          echo "Succeeded"
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.operationState\\.message\\}"; then
          echo ""
          return 0
        fi
        if printf "%s" "$*" | rg -q "jsonpath=\\{\\.status\\.operationState\\.operation\\.sync\\.revision\\}"; then
          echo "v1.2.3-rc.1+build.1-rev.1"
          return 0
        fi
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "patch" && "${4:-}" == "application" ]]; then
        echo "PATCH_OK" >> "$marker"
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "annotate" && "${4:-}" == "application" ]]; then
        echo "ANNOTATE_OK" >> "$marker"
        return 0
      fi
      return 0
    }

    promote_local_argocd_sync_by_tag_or_die "v1.2.3-rc.1+build.1-rev.1" "pmbok-backend-app" "5"
    cat "$marker"
  '

  [ "$status" -eq 0 ]
  [[ "$output" != *"COMMON_SHOULD_NOT_BE_CALLED"* ]]
  [[ "$output" == *"PATCH_OK"* ]]
}

# Título: bump de rev cuando el tag existente no apunta al commit promovido
function test_case_036 { #@test
  run bash -c '
    set -euo pipefail
    repo_root="$(pwd)"
    source "$repo_root/lib/promote/workflows/to-local.sh"

    tmp="$(mktemp -d)"
    cd "$tmp"
    git init -q
    git config user.email "a@a"
    git config user.name "a"
    git config commit.gpgsign false
    git config tag.gpgSign false

    echo a > f
    git add f
    git commit -qm c1
    git tag -a "v0.1.2-rc.6+build.84-rev.1" -m t1

    echo b >> f
    git commit -am c2 -q

    head_sha="$(git rev-parse HEAD)"
    out="$(promote_local_ensure_tag_matches_head_or_bump "v0.1.2-rc.6+build.84-rev.1" "$head_sha")"
    echo "$out"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.1.2-rc.6+build.84-rev.2"* ]]
}

# Título: argocd core no usa --namespace en promote local
function test_case_037 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"
    marker="$(mktemp)"

    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }
    log_success(){ :; }
    devbox(){ return 127; }
    promote_local_ensure_remote_tag_or_die() { return 0; }

    kubectl() {
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "get" && "${4:-}" == "application" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "patch" && "${4:-}" == "application" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "-n" && "${2:-}" == "argocd" && "${3:-}" == "annotate" && "${4:-}" == "application" ]]; then
        return 0
      fi
      return 0
    }

    argocd() {
      echo "$*" >> "$marker"
      return 0
    }

    promote_local_argocd_sync_by_tag_or_die "v1.2.3-rc.1+build.1-rev.1" "pmbok-backend-app" "30"
    cat "$marker"
    if rg -q -- "--namespace" "$marker"; then
      echo "FOUND_NAMESPACE_FLAG"
      exit 1
    fi
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"--core app sync pmbok-backend-app"* ]]
  [[ "$output" == *"--core app wait pmbok-backend-app --timeout 30 --health --sync"* ]]
  [[ "$output" != *"FOUND_NAMESPACE_FLAG"* ]]
}

# Título: wrapper legacy removido sin referencias activas
function test_case_038 { #@test
  run bash -c '
    set -euo pipefail
    base="lib/promote/workflows/"
    name="to-local"
    suffix=".legacy.sh"
    legacy_path="${base}${name}${suffix}"
    test ! -f "${legacy_path}"

    # No debe existir ninguna referencia activa al wrapper removido.
    # Excluimos metadata de .git para evitar falsos positivos históricos.
    pattern="${name}${suffix}"
    ! rg -n --hidden -F --glob "!.git" "${pattern}" .
  '

  [ "$status" -eq 0 ]
}

# Título: guardrail de tags acepta "+" y exige -rev.N para ArgoCD
function test_case_039 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    log_info(){ :; }
    log_warn(){ :; }
    log_error(){ echo "$*" >&2; }
    log_success(){ :; }

    promote_local_is_valid_tag_name "v0.1.2-rc.6+build.98-rev.1" || {
      echo "TAG_PLUS_INVALID"
      exit 1
    }

    kubectl() {
      echo "KUBECTL_SHOULD_NOT_RUN"
      return 0
    }
    promote_local_ensure_remote_tag_or_die() { return 0; }

    if promote_local_argocd_sync_by_tag_or_die "v0.1.2-rc.6+build.98" "pmbok-backend-app" "30"; then
      echo "GUARDRAIL_NOT_TRIGGERED"
      exit 1
    fi

    echo "TAG_PLUS_VALID"
    echo "GUARDRAIL_OK"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"TAG_PLUS_VALID"* ]]
  [[ "$output" == *"GUARDRAIL_OK"* ]]
  [[ "$output" == *"targetRevision debe terminar en '-rev.N'"* ]]
  [[ "$output" != *"KUBECTL_SHOULD_NOT_RUN"* ]]
}

# Título: dry-run omite patch/sync de ArgoCD sin ejecutar kubectl/argocd
function test_case_040 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    export DEVTOOLS_DRY_RUN=1
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }

    promote_local_remote_tag_exists() {
      echo "REMOTE_TAG_CHECK"
      return 0
    }
    kubectl() {
      echo "KUBECTL_CALLED"
      return 0
    }
    argocd() {
      echo "ARGOCD_CALLED"
      return 0
    }
    devbox() { return 127; }

    promote_local_argocd_sync_by_tag_or_die "v0.1.2-rc.6+build.98-rev.1" "pmbok-backend-app" "30"
    echo "SYNC_SKIPPED=${PROMOTE_LOCAL_ARGOCD_SYNC_SKIPPED:-}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"REMOTE_TAG_CHECK"* ]]
  [[ "$output" == *"SYNC_SKIPPED=1"* ]]
  [[ "$output" != *"KUBECTL_CALLED"* ]]
  [[ "$output" != *"ARGOCD_CALLED"* ]]
}

# Título: dry-run omite push de rama local
function test_case_041 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    export DEVTOOLS_DRY_RUN=1
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    push_branch_force() {
      echo "PUSH_CALLED"
      return 0
    }

    promote_local_push_branch_force_or_die "local" "origin"
    echo "DONE"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"DONE"* ]]
  [[ "$output" == *"DRY-RUN: omito push de origin/local"* ]]
  [[ "$output" != *"PUSH_CALLED"* ]]
}

# Título: dry-run no exige EVENT_FILE y omite creación de tag local
function test_case_042 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    export DEVTOOLS_DRY_RUN=1
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    die(){ echo "$*" >&2; return 1; }

    git() {
      echo "GIT_CALLED:$*"
      return 1
    }

    promote_local_maybe_create_local_tag_or_die "v0.1.2-rc.6+build.98-rev.1" "abc123def456"
    echo "DONE"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"DONE"* ]]
  [[ "$output" == *"DRY-RUN: omito creación de tag local"* ]]
  [[ "$output" != *"GIT_CALLED:"* ]]
}

# Título: gate auto-dispara workflow faltante y reevalúa sin loop
function test_case_043 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/checks.sh"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }
    print_run_link(){ :; }
    is_tty(){ return 1; }

    load_required_workflows_dev_or_die() {
      REQUIRED_WORKFLOWS_DEV=("ci.yaml")
      return 0
    }

    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/.github/workflows"
    : > "${tmp}/.github/workflows/ci.yaml"
    export REPO_ROOT="${tmp}"

    dispatch_file="$(mktemp)"
    echo "0" > "${dispatch_file}"
    gh() {
      if [[ "${1:-}" == "workflow" && "${2:-}" == "run" && "${3:-}" == "ci.yaml" ]]; then
        echo "1" > "${dispatch_file}"
        return 0
      fi
      return 1
    }

    __wf_meta_for_sha_once() {
      if [[ "$(cat "${dispatch_file}")" == "1" ]]; then
        echo "321|completed|success"
        return 0
      fi
      return 1
    }

    watch_workflow_run_if_any() { return 0; }

    export DEVTOOLS_GATE_PENDING_TRIES=1
    export DEVTOOLS_GATE_PENDING_POLL_SECONDS=0
    export DEVTOOLS_GATE_WAIT_TIMEOUT_SECONDS=4
    export DEVTOOLS_GATE_WAIT_POLL_SECONDS=1
    export DEVTOOLS_GATE_FAIL_FAST_ON_NO_RUN=1
    export DEVTOOLS_GATE_AUTO_DISPATCH_ON_NO_RUN=1

    gate_required_workflows_on_sha_or_die "abc123def456" "dev" "dev"
    echo "DISPATCHED=$(cat "${dispatch_file}")"
    rm -rf "${tmp}" "${dispatch_file}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-disparo: workflow faltante ci.yaml"* ]]
  [[ "$output" == *"Gate OK"* ]]
  [[ "$output" == *"DISPATCHED=1"* ]]
}


# Título: strategy local usa fallback por ref cuando checkout local falla
function test_case_044 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }
    log_success(){ echo "$*"; }
    die(){ echo "DIE:$*" >&2; return 1; }
    branch_exists_remote(){ return 0; }
    ensure_local_branch_tracks_remote(){ return 0; }

    git() {
      if [[ "${1:-}" == "checkout" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "fetch" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "refs/remotes/origin/local" ]]; then
        echo "1111111111111111111111111111111111111111"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "refs/heads/local" ]]; then
        echo "1111111111111111111111111111111111111111"
        return 0
      fi
      if [[ "${1:-}" == "merge-base" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "update-ref" ]]; then
        echo "UPDATE_REF:$*"
        return 0
      fi
      return 0
    }

    export DEVTOOLS_PROMOTE_STRATEGY=ff-only
    promote_local_apply_strategy_to_local_or_die "abc123def456" "local"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso fallback sin checkout"* ]]
  [[ "$output" == *"Estrategia aplicada: local <- abc123d (strategy=ff-only, sha=abc123d)"* ]]
}

# Título: si tag remoto existe con otro SHA, se calcula siguiente tag no conflictivo
function test_case_045 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    promote_local_remote_tag_exists() {
      [[ "${1:-}" == "v0.1.2-rc.6+build.104-rev.1" || "${1:-}" == "v0.1.2-rc.6+build.104-rev.2" ]]
    }
    promote_local_remote_tag_sha_or_empty() {
      echo "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    }
    promote_local_ensure_tag_matches_head_or_bump() {
      if [[ "${1:-}" == "v0.1.2-rc.6+build.104-rev.1" ]]; then
        echo "v0.1.2-rc.6+build.104-rev.2"
      else
        echo "v0.1.2-rc.6+build.104-rev.3"
      fi
    }

    out="$(promote_local_next_remote_safe_tag "v0.1.2-rc.6+build.104-rev.1" "abc123def456")"
    echo "$out"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.1.2-rc.6+build.104-rev.3"* ]]
}

# Título: cleanup elimina worktree temporal stale que bloquea rama local
function test_case_046 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-local.sh"

    log_warn(){ echo "$*"; }
    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
        echo "/repo"
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "list" && "${3:-}" == "--porcelain" ]]; then
        cat <<EOF
worktree /repo
HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
branch refs/heads/dev
worktree /tmp/eco-promote-validate-v2
HEAD bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
branch refs/heads/local
worktree /tmp/no-tocar
HEAD cccccccccccccccccccccccccccccccccccccccc
branch refs/heads/local
EOF
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "remove" && "${3:-}" == "--force" ]]; then
        echo "WT_REMOVE:${4:-}"
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "prune" ]]; then
        echo "WT_PRUNE"
        return 0
      fi
      return 0
    }
    rm(){ echo "RM_CALLED:$*"; }

    promote_local_cleanup_stale_worktrees_for_branch "local"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Cleanup stale worktree temporal: /tmp/eco-promote-validate-v2 (refs/heads/local)"* ]]
  [[ "$output" == *"Rama 'local' está ocupada por worktree externo (/tmp/no-tocar)"* ]]
}

# Título: promote dev no interactivo falla con fetch caído si OFFLINE-NOOP no es explícito
function test_case_047 { #@test
  run bash -c '
    set -euo pipefail
    repo_root="$(pwd -P)"
    real_git="$(command -v git)"
    tmp="$(mktemp -d)"
    clone="$tmp/repo"
    mkdir -p "$clone"
    cp -R "$repo_root/." "$clone/"
    rm -rf "$clone/.git"
    "$real_git" init -b dev "$clone" >/dev/null 2>&1
    "$real_git" -C "$clone" config user.name "Test Bot"
    "$real_git" -C "$clone" config user.email "test@example.com"
    "$real_git" -C "$clone" config commit.gpgsign false
    "$real_git" -C "$clone" add -A
    "$real_git" -C "$clone" commit -m "snapshot" >/dev/null 2>&1
    "$real_git" -C "$clone" branch local
    "$real_git" -C "$clone" remote add origin "git@github.com:org/repo.git"

    mkdir -p "$tmp/fakebin"
    cat > "$tmp/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "fetch" && "\${2:-}" == "origin" && "\${3:-}" == "--prune" ]]; then
  echo "simulated fetch failure" >&2
  exit 1
fi
exec "__REAL_GIT__" "\$@"
EOF
    sed -i "s|__REAL_GIT__|$real_git|g" "$tmp/fakebin/git"
    chmod +x "$tmp/fakebin/git"

    set +e
    out="$(
      cd "$clone" && \
      PATH="$tmp/fakebin:$PATH" \
      DEVTOOLS_NONINTERACTIVE=1 \
      "$clone/bin/git-promote.sh" -y dev 2>&1
    )"
    rc=$?
    set -e

    echo "$out"
    [[ "$rc" -ne 0 ]]
    [[ "$out" == *"Fetch falló para promote dev en modo no interactivo"* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: promote dev permite OFFLINE-NOOP solo con opt-in explícito
function test_case_048 { #@test
  run bash -c '
    set -euo pipefail
    repo_root="$(pwd -P)"
    real_git="$(command -v git)"
    tmp="$(mktemp -d)"
    clone="$tmp/repo"
    mkdir -p "$clone"
    cp -R "$repo_root/." "$clone/"
    rm -rf "$clone/.git"
    "$real_git" init -b dev "$clone" >/dev/null 2>&1
    "$real_git" -C "$clone" config user.name "Test Bot"
    "$real_git" -C "$clone" config user.email "test@example.com"
    "$real_git" -C "$clone" config commit.gpgsign false
    "$real_git" -C "$clone" add -A
    "$real_git" -C "$clone" commit -m "snapshot" >/dev/null 2>&1
    "$real_git" -C "$clone" branch local
    "$real_git" -C "$clone" remote add origin "git@github.com:org/repo.git"
    "$real_git" -C "$clone" checkout -q local

    mkdir -p "$tmp/fakebin"
    cat > "$tmp/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "fetch" && "\${2:-}" == "origin" && "\${3:-}" == "--prune" ]]; then
  echo "simulated fetch failure" >&2
  exit 1
fi
exec "__REAL_GIT__" "\$@"
EOF
    sed -i "s|__REAL_GIT__|$real_git|g" "$tmp/fakebin/git"
    chmod +x "$tmp/fakebin/git"

    out="$(
      cd "$clone" && \
      PATH="$tmp/fakebin:$PATH" \
      DEVTOOLS_NONINTERACTIVE=1 \
      DEVTOOLS_PROMOTE_STRATEGY=ff-only \
      DEVTOOLS_PROMOTE_DEV_OFFLINE_NOOP=1 \
      "$clone/bin/git-promote.sh" -y dev 2>&1
    )"

    echo "$out"
    [[ "$out" == *"OFFLINE-NOOP activo: omito gate/push/argocd para promote dev."* ]]
    [[ "$out" == *"Resultado final: SUCCESS (offline_noop=1"* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: guardrail detecta NO-OP cuando dev no avanza
function test_case_049 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "dev" ]]; then
        echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        return 0
      fi
      if [[ "${1:-}" == "merge-base" && "${2:-}" == "--is-ancestor" ]]; then
        return 0
      fi
      command git "$@"
    }

    set +e
    promote_dev_verify_target_advanced_or_die \
      "dev" \
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"NO-OP DETECTED: dev no avanzó"* ]]
}

# Título: guardrail detecta cuando dev no contiene source_sha
function test_case_050 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "dev" ]]; then
        echo "cccccccccccccccccccccccccccccccccccccccc"
        return 0
      fi
      if [[ "${1:-}" == "merge-base" && "${2:-}" == "--is-ancestor" ]]; then
        return 1
      fi
      command git "$@"
    }

    set +e
    promote_dev_verify_target_advanced_or_die \
      "dev" \
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"NO-OP DETECTED: dev no contiene source"* ]]
}

# Título: guardrail detecta mismatch entre tag y SHA final esperado
function test_case_051 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    log_error(){ echo "$*" >&2; }

    git() {
      if [[ "${1:-}" == "rev-list" && "${2:-}" == "-n" && "${3:-}" == "1" ]]; then
        echo "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
        return 0
      fi
      command git "$@"
    }

    set +e
    promote_dev_verify_tag_matches_target_or_die \
      "v1.2.3-rc.1+build.1" \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    rc=$?
    set -e
    [ "$rc" -eq 2 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"TAG MISMATCH:"* ]]
}

# Título: summary final imprime línea auditable con moved/tag/offline/noop
function test_case_052 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/to-dev.sh"
    log_info(){ echo "$*"; }
    promote_dev_emit_summary \
      "dev" \
      "local" \
      "abc123def456" \
      "1111111111111111111111111111111111111111" \
      "2222222222222222222222222222222222222222" \
      "yes" \
      "v1.2.3-rc.1+build.9" \
      "2222222222222222222222222222222222222222" \
      "0" \
      "0"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"PROMOTE SUMMARY: target=dev source=local"* ]]
  [[ "$output" == *"moved=yes"* ]]
  [[ "$output" == *"tag=v1.2.3-rc.1+build.9"* ]]
}

# Título: ensure_local_checkout alinea local con origin/local cuando existe remoto
function test_case_053 { #@test
  run bash -c '
    set -euo pipefail
    fn="$(sed -n "/^ensure_local_checkout()/,/^}/p" bin/git-promote.sh)"
    [[ -n "${fn:-}" ]] || { echo "missing ensure_local_checkout"; exit 1; }
    eval "$fn"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }

    TARGET_ENV="local"
    REST_ARGS=()
    REPO_ROOT="/repo"
    PROMOTE_ENTRY_DIR="/repo"
    DEVTOOLS_PROMOTE_FROM_SHA=""
    state="pre"
    calls_file="$(mktemp)"

    git_entry() {
      echo "CALL:$*" >> "${calls_file}"
      echo "CALL:$*"
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
        echo "/repo"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--git-dir" ]]; then
        echo ".git"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        if [[ "${state:-pre}" == "post" ]]; then
          echo "local"
        else
          echo "dev-fresh"
        fi
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "list" && "${3:-}" == "--porcelain" ]]; then
        cat <<EOF
worktree /repo
HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
branch refs/heads/dev
EOF
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "prune" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/heads/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/remotes/origin/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "checkout" && "${2:-}" == "local" ]]; then
        state="post"
        return 0
      fi
      if [[ "${1:-}" == "fetch" && "${2:-}" == "origin" && "${3:-}" == "local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "reset" && "${2:-}" == "--hard" && "${3:-}" == "origin/local" ]]; then
        return 0
      fi
      return 0
    }

    ensure_local_checkout
    cat "${calls_file}"
    rm -f "${calls_file}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"CALL:show-ref --verify --quiet refs/remotes/origin/local"* ]]
  [[ "$output" == *"CALL:fetch origin local"* ]]
  [[ "$output" == *"CALL:reset --hard origin/local"* ]]
  [[ "$output" == *"alineada a origin/local"* ]]
}

# Título: ensure_local_checkout reintegra source_sha con merge ff-only si local quedó atrás
function test_case_054 { #@test
  run bash -c '
    set -euo pipefail
    fn="$(sed -n "/^ensure_local_checkout()/,/^}/p" bin/git-promote.sh)"
    [[ -n "${fn:-}" ]] || { echo "missing ensure_local_checkout"; exit 1; }
    eval "$fn"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }

    TARGET_ENV="local"
    REST_ARGS=()
    REPO_ROOT="/repo"
    PROMOTE_ENTRY_DIR="/repo"
    DEVTOOLS_PROMOTE_FROM_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    state="pre"
    calls_file="$(mktemp)"

    git_entry() {
      echo "CALL:$*" >> "${calls_file}"
      echo "CALL:$*"
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
        echo "/repo"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--git-dir" ]]; then
        echo ".git"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        if [[ "${state:-pre}" == "post" ]]; then
          echo "local"
        else
          echo "feature-x"
        fi
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "list" && "${3:-}" == "--porcelain" ]]; then
        cat <<EOF
worktree /repo
HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
branch refs/heads/dev
EOF
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "prune" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/heads/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/remotes/origin/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "checkout" && "${2:-}" == "local" ]]; then
        state="post"
        return 0
      fi
      if [[ "${1:-}" == "fetch" && "${2:-}" == "origin" && "${3:-}" == "local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "reset" && "${2:-}" == "--hard" && "${3:-}" == "origin/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--verify" && "${3:-}" == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb^{commit}" ]]; then
        echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        return 0
      fi
      if [[ "${1:-}" == "merge-base" && "${2:-}" == "--is-ancestor" && "${3:-}" == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" && "${4:-}" == "HEAD" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "merge" && "${2:-}" == "--ff-only" && "${3:-}" == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "reset" && "${2:-}" == "--hard" && "${3:-}" == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ]]; then
        echo "UNEXPECTED_SOURCE_RESET"
        return 0
      fi
      return 0
    }

    ensure_local_checkout
    cat "${calls_file}"
    rm -f "${calls_file}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Integrando código fresco en"* ]]
  [[ "$output" == *"CALL:merge --ff-only bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"* ]]
  [[ "$output" != *"UNEXPECTED_SOURCE_RESET"* ]]
}

# Título: ensure_local_checkout hace fallback a reset source_sha si merge ff-only falla
function test_case_055 { #@test
  run bash -c '
    set -euo pipefail
    fn="$(sed -n "/^ensure_local_checkout()/,/^}/p" bin/git-promote.sh)"
    [[ -n "${fn:-}" ]] || { echo "missing ensure_local_checkout"; exit 1; }
    eval "$fn"

    log_info(){ echo "$*"; }
    log_warn(){ echo "$*"; }

    TARGET_ENV="local"
    REST_ARGS=()
    REPO_ROOT="/repo"
    PROMOTE_ENTRY_DIR="/repo"
    DEVTOOLS_PROMOTE_FROM_SHA="cccccccccccccccccccccccccccccccccccccccc"
    state="pre"
    calls_file="$(mktemp)"

    git_entry() {
      echo "CALL:$*" >> "${calls_file}"
      echo "CALL:$*"
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
        echo "/repo"
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--git-dir" ]]; then
        echo ".git"
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        if [[ "${state:-pre}" == "post" ]]; then
          echo "local"
        else
          echo "feature-y"
        fi
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "list" && "${3:-}" == "--porcelain" ]]; then
        cat <<EOF
worktree /repo
HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
branch refs/heads/dev
EOF
        return 0
      fi
      if [[ "${1:-}" == "worktree" && "${2:-}" == "prune" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/heads/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "show-ref" && "${2:-}" == "--verify" && "${3:-}" == "--quiet" && "${4:-}" == "refs/remotes/origin/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "checkout" && "${2:-}" == "local" ]]; then
        state="post"
        return 0
      fi
      if [[ "${1:-}" == "fetch" && "${2:-}" == "origin" && "${3:-}" == "local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "reset" && "${2:-}" == "--hard" && "${3:-}" == "origin/local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--verify" && "${3:-}" == "cccccccccccccccccccccccccccccccccccccccc^{commit}" ]]; then
        echo "cccccccccccccccccccccccccccccccccccccccc"
        return 0
      fi
      if [[ "${1:-}" == "merge-base" && "${2:-}" == "--is-ancestor" && "${3:-}" == "cccccccccccccccccccccccccccccccccccccccc" && "${4:-}" == "HEAD" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "merge" && "${2:-}" == "--ff-only" && "${3:-}" == "cccccccccccccccccccccccccccccccccccccccc" ]]; then
        return 1
      fi
      if [[ "${1:-}" == "reset" && "${2:-}" == "--hard" && "${3:-}" == "cccccccccccccccccccccccccccccccccccccccc" ]]; then
        return 0
      fi
      return 0
    }

    ensure_local_checkout
    cat "${calls_file}"
    rm -f "${calls_file}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"CALL:merge --ff-only cccccccccccccccccccccccccccccccccccccccc"* ]]
  [[ "$output" == *"CALL:reset --hard cccccccccccccccccccccccccccccccccccccccc"* ]]
  [[ "$output" == *"requirió reset a source_sha=ccccccc"* ]]
}

# Título: router local aterriza explícitamente en local tras éxito
function test_case_056 { #@test
  run bash -c '
    set -euo pipefail
    block="$(awk "/^[[:space:]]*local\\)/,/^[[:space:]]*;;/" bin/git-promote.sh)"
    [[ "$block" == *"export DEVTOOLS_LAND_ON_SUCCESS_BRANCH=\"local\""* ]]
  '

  [ "$status" -eq 0 ]
}

# Título: cleanup choose action usa default afirmativo (delete_both/delete_local)
function test_case_057 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/common.sh"
    ask_yes_no(){ return 0; }
    echo "WITH_UPSTREAM=$(promote_cleanup_choose_action "feature/t56" 1)"
    echo "NO_UPSTREAM=$(promote_cleanup_choose_action "feature/t56" 0)"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"WITH_UPSTREAM=delete_both"* ]]
  [[ "$output" == *"NO_UPSTREAM=delete_local"* ]]
}

# Título: cleanup choose action en --yes no borra sin opt-in explícito
function test_case_058 { #@test
  run bash -c '
    set -euo pipefail
    source "lib/promote/workflows/common.sh"
    export DEVTOOLS_ASSUME_YES=1
    export DEVTOOLS_PROMOTE_DELETE_SOURCE_BRANCH=0
    echo "ACTION=$(promote_cleanup_choose_action "feature/t57" 1)"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"ACTION=keep"* ]]
}

# Título: cleanup_on_exit en local exitoso dispara maybe_delete_source_branch
function test_case_059 { #@test
  run bash -c '
    set -euo pipefail
    fn="$(sed -n "/^cleanup_on_exit()/,/^}/p" bin/git-promote.sh)"
    [[ -n "${fn:-}" ]] || { echo "missing cleanup_on_exit"; exit 1; }
    eval "$fn"

    maybe_delete_source_branch(){ echo "DELETE:$1"; }
    ui_info(){ echo "$*"; }
    ui_warn(){ echo "$*"; }
    ui_error(){ echo "$*"; }
    log_warn(){ echo "$*"; }
    ensure_local_branch_tracks_remote(){ return 0; }

    TARGET_ENV="local"
    DEVTOOLS_DRY_RUN=0
    DEVTOOLS_LAND_ON_SUCCESS_BRANCH="local"
    DEVTOOLS_PROMOTE_FROM_BRANCH="feature/t58"

    git() {
      if [[ "${1:-}" == "checkout" && "${2:-}" == "local" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "branch" && "${2:-}" == "--show-current" ]]; then
        echo "local"
        return 0
      fi
      return 0
    }

    true
    cleanup_on_exit
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE:feature/t58"* ]]
}

# Título: to-local no borra rama fuente directamente (cleanup centralizado en trap global)
function test_case_060 { #@test
  run bash -c '
    set -euo pipefail
    count="$(grep -cE "promote_local_offer_delete_source_branch_if_needed[[:space:]]*\\(" lib/promote/workflows/to-local/90-main.sh || true)"
    echo "COUNT=$count"
    [ "$count" -eq 0 ]
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"COUNT=0"* ]]
}

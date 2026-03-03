#!/usr/bin/env bash
# Actualiza explícitamente el vendor dir de devtools (opt-in)
# o aplica snapshot vendorizado por tag desde un upstream local/remoto.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
SCRIPT_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

# Reusar helpers existentes
source "${LIB_DIR}/core/utils.sh"
source "${LIB_DIR}/core/git-ops.sh"
source "${LIB_DIR}/core/contract.sh"

ROOT="$(detect_workspace_root)"
devtools_load_contract "$ROOT" || true
TARGET_PATH="${DEVTOOLS_VENDOR_DIR:-.devtools}"
TARGET_PATH="${TARGET_PATH#./}"
if [[ "${TARGET_PATH}" == /* ]]; then
  if [[ "${TARGET_PATH}" == "${ROOT}/"* ]]; then
    TARGET_PATH="${TARGET_PATH#${ROOT}/}"
  else
    ui_error "paths.vendor_dir fuera del repo no es soportado: ${TARGET_PATH}"
    exit 1
  fi
fi
LOCK_FILE="${ROOT}/${TARGET_PATH}.lock"
LEGACY_LOCK_FILE="${ROOT}/.devtools.lock"
IS_UPSTREAM_REPO=0
if [[ "${ROOT}" == "${SCRIPT_REPO_ROOT}" ]]; then
  IS_UPSTREAM_REPO=1
fi

MODE="checkout"   # checkout|merge
INIT_ONLY=0
WRITE_LOCK=0
ASSUME_YES=0
COMMAND="update"   # update|list

DEVTOOLS_SOURCE=""
DEVTOOLS_VERSION=""
DEVTOOLS_SUBDIR="${TARGET_PATH}"
DEVTOOLS_REPO=""
LIST_REMOTE_URL_USED=""
LIST_REMOTE_TAGS=""

readonly LEGACY_DEVTOOLS_SOURCE="reydem/devtools"
readonly CANONICAL_DEVTOOLS_SOURCE="example/devtools"

OVERRIDE_SOURCE=""
OVERRIDE_VERSION=""
OVERRIDE_SUBDIR=""
UPSTREAM_REPO=""

usage() {
  cat <<USAGE
Uso:
  git devtools-update [list] [--repo /ruta/upstream] [--source owner/repo]
  git devtools-update TAG=vX.Y.Z [--yes] [--repo /ruta/upstream] [--subdir ${TARGET_PATH}]
  git devtools-update --version vX.Y.Z [--yes] [--repo /ruta/upstream] [--subdir ${TARGET_PATH}]

Compatibilidad legacy:
  git devtools-update [--init-only] [--merge] [--version vX.Y.Z] [--source owner/repo] [--subdir ${TARGET_PATH}] [--write-lock]

Opciones:
  list         Lista tags disponibles en el upstream.
  TAG=...      Tag objetivo explícito (equivalente a --version).
  --yes        Omite confirmación interactiva.
  --repo       Ruta local del repo upstream (default: repo de este script).
  --init-only  Solo asegura que exista (sin --remote).
  --merge      Usa --merge al actualizar remoto (si aplica).
  --version    Tag del vendor dir a aplicar/descargar.
  --source     Repo origen (owner/repo) para modo legacy tarball.
  --subdir     Subcarpeta dentro del repo upstream (default: ${TARGET_PATH}).
  --write-lock Actualiza ${TARGET_PATH}.lock con los valores finales.
USAGE
}

trim_ws() {
  local v="${1:-}"
  # shellcheck disable=SC2001
  v="$(echo "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "$v"
}

ensure_repo_dir_or_die() {
  local repo="$1"
  if [[ -z "${repo:-}" ]]; then
    ui_error "--repo inválido: <vacío>"
    exit 1
  fi

  # Validación robusta: permite repo root, submódulo (.git file) y subdirectorios.
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ui_error "--repo inválido (no es un repositorio Git): ${repo}"
    exit 1
  fi
}

normalize_devtools_source() {
  local src="${1:-}"
  src="$(trim_ws "$src")"
  if [[ "$src" == "$LEGACY_DEVTOOLS_SOURCE" ]]; then
    echo "⚠️  Origen legacy detectado (${LEGACY_DEVTOOLS_SOURCE}); usaré ${CANONICAL_DEVTOOLS_SOURCE}." >&2
    src="$CANONICAL_DEVTOOLS_SOURCE"
  fi
  echo "$src"
}

build_github_ssh_url() {
  local source_repo="$1"
  echo "git@github.com:${source_repo}.git"
}

build_github_https_url() {
  local source_repo="$1"
  echo "https://github.com/${source_repo}.git"
}

is_gitlink_submodule_path() {
  local repo_root="$1"
  local path="$2"
  local mode
  mode="$(git -C "$repo_root" ls-files -s -- "$path" 2>/dev/null | awk 'NR==1 {print $1}')"
  [[ "$mode" == "160000" ]]
}

is_work_tree_dir() {
  local repo="$1"
  [[ -n "${repo:-}" ]] && git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

list_remote_tags_or_die() {
  local source_repo="$1"
  local tags
  local remote_url

  LIST_REMOTE_URL_USED=""
  LIST_REMOTE_TAGS=""

  for remote_url in "$(build_github_ssh_url "$source_repo")" "$(build_github_https_url "$source_repo")"; do
    tags="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs "$remote_url" 'v*' 2>/dev/null | awk -F/ '{print $3}' | sort -V || true)"
    if [[ -n "${tags:-}" ]]; then
      LIST_REMOTE_URL_USED="$remote_url"
      LIST_REMOTE_TAGS="$tags"
      return 0
    fi
  done

  ui_error "No pude listar tags remotos en $(build_github_ssh_url "$source_repo") ni por HTTPS."
  exit 1
}

list_repo_tags() {
  local repo="$1"
  if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo" fetch --tags --quiet origin >/dev/null 2>&1 || true
  fi

  git -C "$repo" tag -l 'v*' | sed '/^$/d' | sort -V
}

resolve_tag_sha_or_die() {
  local repo="$1"
  local tag="$2"

  if ! git -C "$repo" rev-parse -q --verify "refs/tags/${tag}^{commit}" >/dev/null 2>&1; then
    ui_error "El tag '${tag}' no existe en ${repo}."
    exit 1
  fi

  git -C "$repo" rev-parse "refs/tags/${tag}^{commit}"
}

resolve_source_from_repo() {
  local repo="$1"
  local remote_url
  remote_url="$(git -C "$repo" config --get remote.origin.url 2>/dev/null || true)"

  # Soporta https, ssh://git@host/... y git@host:owner/repo(.git),
  # incluyendo aliases SSH tipo github.com-reydem.
  if [[ "$remote_url" =~ ^(https?://[^/]+/|ssh://git@[^/]+/|git@[^:]+:)([^/]+/[^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[2]}"
    return 0
  fi

  echo ""
}

resolve_source_for_list_or_die() {
  local src=""
  src="$(normalize_devtools_source "${DEVTOOLS_SOURCE:-}")"

  if [[ -z "${src:-}" || "${src}" == "local/"* ]]; then
    ui_error "Origen remoto no definido."
    ui_error "Ejecuta: git devtools-update list --source <owner>/<repo>"
    exit 1
  fi

  echo "$src"
}

is_current_root_devtools_repo() {
  [[ -x "${ROOT}/bin/git-devtools-update.sh" ]] \
    && [[ -f "${ROOT}/lib/core/git-ops.sh" ]] \
    && git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

read_current_state() {
  local cur_tag=""
  local cur_sha=""

  if [[ -f "${ROOT}/${TARGET_PATH}/VENDORED_TAG" ]]; then
    cur_tag="$(trim_ws "$(cat "${ROOT}/${TARGET_PATH}/VENDORED_TAG" 2>/dev/null || true)")"
  fi

  if [[ -f "${ROOT}/${TARGET_PATH}/VENDORED_SHA" ]]; then
    cur_sha="$(trim_ws "$(cat "${ROOT}/${TARGET_PATH}/VENDORED_SHA" 2>/dev/null || true)")"
  fi

  echo "${cur_tag}|${cur_sha}"
}

confirm_apply_or_abort() {
  local question="${1:-¿Aplicar cambio?}"
  local ans

  if [[ "$ASSUME_YES" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    ui_error "No TTY detectado. Usa --yes para ejecutar sin confirmación."
    return 1
  fi

  printf "%s [Y/n]: " "$question"
  read -r ans
  ans="${ans:-Y}"
  case "$ans" in
    Y|y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

write_lock_file() {
  cat > "$LOCK_FILE" <<LOCK
# Lock de vendor dir devtools
DEVTOOLS_SOURCE="${DEVTOOLS_SOURCE}"
DEVTOOLS_VERSION="${DEVTOOLS_VERSION}"
DEVTOOLS_SUBDIR="${DEVTOOLS_SUBDIR}"
DEVTOOLS_TAG="${DEVTOOLS_VERSION}"
DEVTOOLS_REPO="${DEVTOOLS_REPO}"
DEVTOOLS_VENDOR_DIR="${TARGET_PATH}"
LOCK
  ui_success "Lock actualizado: ${LOCK_FILE}"
}

materialize_resolvable_symlinks() {
  local src_dir="$1"
  local dst_dir="$2"

  # Materializa symlinks que sí tienen target dentro del snapshot.
  # Si un symlink apunta a un path ausente, se deja intacto.
  while IFS= read -r src_link; do
    local rel_path target_rel target_abs dst_path
    rel_path="${src_link#${src_dir}/}"
    target_rel="$(readlink "$src_link")"
    target_abs="$(cd "$(dirname "$src_link")" && realpath -m "$target_rel")"
    [[ -e "$target_abs" ]] || continue

    dst_path="${dst_dir}/${rel_path}"
    rm -rf "$dst_path"

    if [[ -d "$target_abs" ]]; then
      mkdir -p "$dst_path"
      cp -R "${target_abs}/." "${dst_path}/"
    else
      mkdir -p "$(dirname "$dst_path")"
      cp "$target_abs" "$dst_path"
    fi
  done < <(find "$src_dir" -type l | sort)
}

apply_vendored_snapshot_from_repo_tag() {
  local repo="$1"
  local tag="$2"
  local subdir="$3"

  local target_sha
  target_sha="$(resolve_tag_sha_or_die "$repo" "$tag")"

  local tmp_dir extract_dir src_dir
  tmp_dir="$(mktemp -d)"
  extract_dir="${tmp_dir}/extract"
  mkdir -p "$extract_dir"

  git -C "$repo" archive --format=tar "$tag" | tar -xf - -C "$extract_dir"

  subdir="${subdir#./}"
  src_dir="${extract_dir}/${subdir}"
  if [[ ! -d "$src_dir" ]]; then
    ui_error "No existe la subcarpeta '${subdir}' dentro del snapshot del tag ${tag}."
    rm -rf "$tmp_dir"
    exit 1
  fi

  local backup_path
  backup_path="${ROOT}/${TARGET_PATH}.bak.$(date +%s)"
  if [[ -d "${ROOT}/${TARGET_PATH}" ]]; then
    mv "${ROOT}/${TARGET_PATH}" "$backup_path"
    ui_warn "Backup creado: ${backup_path}"
  fi

  mkdir -p "${ROOT}/${TARGET_PATH}"
  # Copia base preservando estructura; luego materializamos symlinks resolubles.
  cp -R "${src_dir}/." "${ROOT}/${TARGET_PATH}/"

  materialize_resolvable_symlinks "$src_dir" "${ROOT}/${TARGET_PATH}"

  printf '%s\n' "$tag" > "${ROOT}/${TARGET_PATH}/VENDORED_TAG"
  printf '%s\n' "$target_sha" > "${ROOT}/${TARGET_PATH}/VENDORED_SHA"

  DEVTOOLS_VERSION="$tag"
  DEVTOOLS_SUBDIR="$subdir"
  DEVTOOLS_REPO="$repo"
  if [[ -z "${DEVTOOLS_SOURCE:-}" ]]; then
    DEVTOOLS_SOURCE="$(resolve_source_from_repo "$repo")"
  fi

  write_lock_file

  rm -rf "$tmp_dir"

  ui_success "Update vendorizado completado desde tag ${tag}."
  ui_info "RESULT: updated ${TARGET_PATH} to tag=${tag} sha=${target_sha} (mode=vendor)"
  ui_info "Escribí: ${TARGET_PATH}/VENDORED_TAG, ${TARGET_PATH}/VENDORED_SHA y ${LOCK_FILE}"
}

while [[ "${1:-}" != "" ]]; do
  case "$1" in
    list) COMMAND="list"; shift ;;
    TAG=*)
      OVERRIDE_VERSION="${1#TAG=}"
      if [[ -z "${OVERRIDE_VERSION:-}" ]]; then
        ui_error "TAG vacío. Usa TAG=vX.Y.Z."
        exit 2
      fi
      WRITE_LOCK=1
      shift
      ;;
    --init-only) INIT_ONLY=1; shift ;;
    --merge) MODE="merge"; shift ;;
    --version)
      OVERRIDE_VERSION="${2:-}"
      if [[ -z "${OVERRIDE_VERSION:-}" ]]; then
        ui_error "--version requiere un valor (ej: --version v1.2.3)."
        exit 2
      fi
      shift 2
      ;;
    --source) OVERRIDE_SOURCE="${2:-}"; shift 2 ;;
    --subdir) OVERRIDE_SUBDIR="${2:-}"; shift 2 ;;
    --repo) UPSTREAM_REPO="${2:-}"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    --write-lock) WRITE_LOCK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Argumento inesperado: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -f "$LOCK_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOCK_FILE"
elif [[ -f "$LEGACY_LOCK_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LEGACY_LOCK_FILE"
fi

# Compatibilidad con lock legacy.
if [[ -z "${DEVTOOLS_VERSION:-}" && -n "${DEVTOOLS_TAG:-}" ]]; then
  DEVTOOLS_VERSION="$DEVTOOLS_TAG"
fi
if [[ -z "${UPSTREAM_REPO:-}" && -n "${DEVTOOLS_REPO:-}" ]] && is_work_tree_dir "${DEVTOOLS_REPO}"; then
  UPSTREAM_REPO="$DEVTOOLS_REPO"
fi

if [[ -n "${OVERRIDE_SOURCE:-}" ]]; then DEVTOOLS_SOURCE="$OVERRIDE_SOURCE"; WRITE_LOCK=1; fi
if [[ -n "${OVERRIDE_VERSION:-}" ]]; then DEVTOOLS_VERSION="$OVERRIDE_VERSION"; WRITE_LOCK=1; fi
if [[ -n "${OVERRIDE_SUBDIR:-}" ]]; then DEVTOOLS_SUBDIR="$OVERRIDE_SUBDIR"; WRITE_LOCK=1; fi

DEVTOOLS_SUBDIR="${DEVTOOLS_SUBDIR#./}"

if [[ -z "${UPSTREAM_REPO:-}" ]]; then
  if [[ "$IS_UPSTREAM_REPO" == "1" ]]; then
    UPSTREAM_REPO="$SCRIPT_REPO_ROOT"
  elif is_current_root_devtools_repo; then
    # Permite que un wrapper/alias externo siga funcionando al ejecutar dentro del repo madre.
    UPSTREAM_REPO="$ROOT"
  fi
fi

if [[ "$COMMAND" == "list" ]]; then
  ui_header "📦 devtools tags (Remote)"
  DEVTOOLS_SOURCE="$(resolve_source_for_list_or_die)"
  list_remote_tags_or_die "$DEVTOOLS_SOURCE"
  remote_url="${LIST_REMOTE_URL_USED:-$(build_github_ssh_url "$DEVTOOLS_SOURCE")}"
  ui_info "Consultando upstream oficial: ${remote_url}"
  if [[ -z "${LIST_REMOTE_TAGS:-}" ]]; then
    ui_warn "No encontré tags v* en el upstream."
    exit 0
  fi
  echo "$LIST_REMOTE_TAGS"
  exit 0
fi

ui_header "🔧 devtools update (EXPLÍCITO)"
ui_info "Root: $ROOT"
ui_info "Ruta destino: $TARGET_PATH"

is_submodule=0
if is_gitlink_submodule_path "$ROOT" "$TARGET_PATH"; then
  is_submodule=1
fi

if [[ "$is_submodule" == "1" ]]; then
  ui_info "Modo: submódulo"
  ui_info "MODE DETECTED: submodule"

  # Siempre seguro: sync + init (no mueve commits)
  git -C "$ROOT" submodule sync --recursive >/dev/null 2>&1 || true
  git -C "$ROOT" submodule update --init --recursive "$TARGET_PATH" >/dev/null 2>&1 || true

  if [[ "$INIT_ONLY" == "1" ]]; then
    ui_success "Init-only OK (sin remoto)."
    exit 0
  fi

  if [[ -n "${OVERRIDE_VERSION:-}" ]]; then
    local_submodule_path="${ROOT}/${TARGET_PATH}"
    ui_info "UPSTREAM: repo=${UPSTREAM_REPO} tag=${OVERRIDE_VERSION}"
    if [[ -n "${UPSTREAM_REPO:-}" ]] && git -C "$UPSTREAM_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      target_sha="$(resolve_tag_sha_or_die "$UPSTREAM_REPO" "$OVERRIDE_VERSION")"
      git -C "$local_submodule_path" fetch --quiet "$UPSTREAM_REPO" \
        "refs/tags/${OVERRIDE_VERSION}:refs/tags/${OVERRIDE_VERSION}" >/dev/null 2>&1 || true
      git -C "$local_submodule_path" fetch --quiet "$UPSTREAM_REPO" "$target_sha" >/dev/null 2>&1 || true
    else
      git -C "$local_submodule_path" fetch --tags --quiet origin >/dev/null 2>&1 || true
    fi
    if ! git -C "$local_submodule_path" rev-parse -q --verify "refs/tags/${OVERRIDE_VERSION}^{commit}" >/dev/null 2>&1; then
      ui_error "El tag '${OVERRIDE_VERSION}' no existe en el submódulo ${TARGET_PATH}."
      exit 1
    fi

    current_tag="$(git -C "$local_submodule_path" describe --tags --abbrev=0 2>/dev/null || echo unknown)"
    current_sha="$(git -C "$local_submodule_path" rev-parse HEAD 2>/dev/null || echo unknown)"
    target_sha="$(git -C "$local_submodule_path" rev-parse "refs/tags/${OVERRIDE_VERSION}^{commit}")"

    ui_info "Actual: TAG=${current_tag:-unknown} SHA=${current_sha:-unknown}"
    ui_info "Objetivo: TAG=${OVERRIDE_VERSION} SHA=${target_sha}"

    if ! confirm_apply_or_abort "¿Aplicar cambio en submódulo?"; then
      ui_warn "Abortado por usuario."
      exit 1
    fi

    git -C "$local_submodule_path" checkout --quiet "$OVERRIDE_VERSION"
    result_sha="$(git -C "$local_submodule_path" rev-parse HEAD 2>/dev/null || echo unknown)"
    ui_success "Submódulo ${TARGET_PATH} actualizado a ${OVERRIDE_VERSION}."
    ui_info "RESULT: updated ${TARGET_PATH} to tag=${OVERRIDE_VERSION} sha=${result_sha} (mode=submodule)"
    ui_info "En el repo padre, revisa 'git status' y commitea el nuevo SHA del submódulo si corresponde."
    exit 0
  fi

  # Opt-in: mover a remoto SOLO aquí
  ui_warn "Actualizando a remoto (esto PUEDE cambiar el SHA pineado en el repo padre)."
  if [[ "$MODE" == "merge" ]]; then
    git -C "$ROOT" submodule update --remote --merge --recursive "$TARGET_PATH"
  else
    git -C "$ROOT" submodule update --remote --recursive "$TARGET_PATH"
  fi

  ui_success "Update remoto completado."
  ui_info "Siguiente paso (en el repo padre): revisa 'git status' y commitea el nuevo SHA del submódulo si corresponde."
  exit 0
fi

ui_info "Modo: vendorizado (${TARGET_PATH})"
ui_info "MODE DETECTED: vendor"

if [[ "$INIT_ONLY" == "1" ]]; then
  if [[ -d "${ROOT}/${TARGET_PATH}" ]]; then
    ui_success "Init-only OK (ya existe ${TARGET_PATH})."
    exit 0
  fi
  ui_error "Init-only: ${TARGET_PATH} no existe. Ejecuta sin --init-only para descargar."
  exit 1
fi

# Modo explícito por tag (TAG=... o --version):
# - local: usa git archive desde --repo o repo madre
# - vendorizado/hijo: usa descarga remota (legacy abajo)
if [[ -n "${OVERRIDE_VERSION:-}" ]]; then
  USE_LOCAL_ARCHIVE=0
  if [[ -n "${UPSTREAM_REPO:-}" ]]; then
    USE_LOCAL_ARCHIVE=1
  elif [[ "$IS_UPSTREAM_REPO" == "1" ]]; then
    UPSTREAM_REPO="$SCRIPT_REPO_ROOT"
    USE_LOCAL_ARCHIVE=1
  elif is_current_root_devtools_repo; then
    UPSTREAM_REPO="$ROOT"
    USE_LOCAL_ARCHIVE=1
  fi

  IFS='|' read -r current_tag current_sha <<< "$(read_current_state)"
  if [[ "$USE_LOCAL_ARCHIVE" == "1" ]]; then
    ensure_repo_dir_or_die "$UPSTREAM_REPO"
    ui_info "UPSTREAM: repo=${UPSTREAM_REPO} tag=${OVERRIDE_VERSION}"

    target_sha="$(resolve_tag_sha_or_die "$UPSTREAM_REPO" "$OVERRIDE_VERSION")"
    ui_info "Actual: TAG=${current_tag:-unknown} SHA=${current_sha:-unknown}"
    ui_info "Objetivo: TAG=${OVERRIDE_VERSION} SHA=${target_sha}"

    if ! confirm_apply_or_abort "¿Aplicar cambio desde local?"; then
      ui_warn "Abortado por usuario."
      exit 1
    fi

    apply_vendored_snapshot_from_repo_tag "$UPSTREAM_REPO" "$OVERRIDE_VERSION" "$DEVTOOLS_SUBDIR"
    exit 0
  fi

  DEVTOOLS_VERSION="$OVERRIDE_VERSION"
  DEVTOOLS_SOURCE="$(normalize_devtools_source "${DEVTOOLS_SOURCE:-}")"
  if [[ -z "${DEVTOOLS_SOURCE:-}" || "${DEVTOOLS_SOURCE:-}" == "local/"* ]]; then
    ui_error "Origen remoto desconocido."
    ui_error "Ejecuta el comando usando '--source owner/repo' para configurarlo."
    exit 1
  fi
  ui_info "UPSTREAM: remoto=${DEVTOOLS_SOURCE} tag=${OVERRIDE_VERSION}"
  ui_info "Actual: TAG=${current_tag:-unknown} SHA=${current_sha:-unknown}"
  ui_info "Objetivo: TAG=${OVERRIDE_VERSION} SHA=remote"
  if ! confirm_apply_or_abort "¿Aplicar cambio desde remoto?"; then
    ui_warn "Abortado por usuario."
    exit 1
  fi
fi

# ---------- Compatibilidad legacy (sin cambios de hábito) ----------
DEVTOOLS_SOURCE="$(normalize_devtools_source "${DEVTOOLS_SOURCE:-}")"
if [[ -z "${DEVTOOLS_SOURCE:-}" || "${DEVTOOLS_SOURCE:-}" == "local/"* ]]; then
  ui_error "Origen remoto desconocido."
  ui_error "Ejecuta el comando usando '--source owner/repo' para configurarlo."
  exit 1
fi
if [[ -z "${DEVTOOLS_VERSION:-}" ]]; then
  ui_error "Faltan datos en ${LOCK_FILE} (DEVTOOLS_SOURCE/DEVTOOLS_VERSION) o en los flags."
  exit 1
fi

ssh_remote_url="$(build_github_ssh_url "$DEVTOOLS_SOURCE")"
https_remote_url="$(build_github_https_url "$DEVTOOLS_SOURCE")"
clone_remote_url=""
tmp_dir="$(mktemp -d)"
clone_dir="${tmp_dir}/devtools"

ui_info "Clonando upstream oficial: ${ssh_remote_url} (tag=${DEVTOOLS_VERSION})"
if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$DEVTOOLS_VERSION" "$ssh_remote_url" "$clone_dir" >/dev/null 2>&1; then
  clone_remote_url="$ssh_remote_url"
else
  ui_warn "No pude clonar por SSH. Intentando HTTPS sin prompts interactivos."
  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$DEVTOOLS_VERSION" "$https_remote_url" "$clone_dir" >/dev/null 2>&1; then
    clone_remote_url="$https_remote_url"
  else
    ui_error "No pude clonar el upstream para ${DEVTOOLS_SOURCE} en el tag ${DEVTOOLS_VERSION}."
    exit 1
  fi
fi

src_dir="${clone_dir}/${DEVTOOLS_SUBDIR}"
if [[ ! -d "$src_dir" ]]; then
  ui_error "No existe la subcarpeta '${DEVTOOLS_SUBDIR}' dentro del repo clonado."
  exit 1
fi

backup_path="${ROOT}/${TARGET_PATH}.bak.$(date +%s)"
if [[ -d "${ROOT}/${TARGET_PATH}" ]]; then
  mv "${ROOT}/${TARGET_PATH}" "$backup_path"
  ui_warn "Backup creado: ${backup_path}"
fi

mkdir -p "${ROOT}/${TARGET_PATH}"
cp -R "${src_dir}/." "${ROOT}/${TARGET_PATH}/"
materialize_resolvable_symlinks "$src_dir" "${ROOT}/${TARGET_PATH}"
target_sha="$(git -C "$clone_dir" rev-parse HEAD)"
printf '%s\n' "$DEVTOOLS_VERSION" > "${ROOT}/${TARGET_PATH}/VENDORED_TAG"
printf '%s\n' "$target_sha" > "${ROOT}/${TARGET_PATH}/VENDORED_SHA"
DEVTOOLS_REPO="$clone_remote_url"

if [[ "$WRITE_LOCK" == "1" || ! -f "$LOCK_FILE" ]]; then
  write_lock_file
fi

rm -rf "$tmp_dir"

ui_success "Update vendorizado completado."
ui_info "RESULT: updated ${TARGET_PATH} to tag=${DEVTOOLS_VERSION} sha=${target_sha} (mode=vendor)"

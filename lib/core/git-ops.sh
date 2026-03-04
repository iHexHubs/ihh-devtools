#!/usr/bin/env bash
# Operaciones y guardas Git compartidas.

# ==============================================================================
# 0. HELPERS DE CONFIGURACIÓN
# ==============================================================================

# Obtiene un valor de configuración de git de forma segura (sin error si falta)
# Uso: git_get <local|global|system> <key>
git_get() {
    local scope="$1"
    local key="$2"
    git config --"$scope" --get "$key" 2>/dev/null || true
}

# Verifica si una clave tiene múltiples valores definidos en un scope
# Uso: has_multiple_values <local|global|system> <key>
# Retorna: 0 (true) si hay >1 valor, 1 (false) si hay 0 o 1.
has_multiple_values() {
    local scope="$1"
    local key="$2"
    local count
    count="$(git config --"$scope" --get-all "$key" 2>/dev/null | awk 'END{print NR}')"
    if [ "$count" -gt 1 ]; then return 0; else return 1; fi
}

# Verifica si al menos uno de los argumentos pasados no está vacío
# Uso: any_set "$var1" "$var2" ...
# Retorna: 0 (true) si encuentra algo, 1 (false) si todo está vacío.
any_set() {
    for var in "$@"; do
        if [ -n "$var" ]; then return 0; fi
    done
    return 1
}

# ==============================================================================
# 1. VALIDACIONES DE ESTADO (GUARDS)
# ==============================================================================

# Versión segura que solo retorna error (no mata el script)
ensure_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    return $?
}

# Versión estricta para scripts que deben abortar si no hay repo
ensure_repo_or_die() {
    ensure_repo || {
        echo "❌ No estás dentro de un repositorio Git." >&2
        exit 1
    }
}

ensure_clean_git() {
    # Ignora .promote_tag porque es metadata efímera escrita por los propios flujos
    # de promote y no debe bloquear validaciones de working tree limpio.
    local exclude_promote_tag=':(exclude).promote_tag'
    local has_tracked_changes=0
    local has_untracked_changes=0

    if ! git diff --quiet -- . "$exclude_promote_tag"; then
        has_tracked_changes=1
    fi
    if ! git diff --cached --quiet -- . "$exclude_promote_tag"; then
        has_tracked_changes=1
    fi
    if [[ -n "$(git ls-files --others --exclude-standard -- . "$exclude_promote_tag")" ]]; then
        has_untracked_changes=1
    fi

    # Si hay cambios (distintos de .promote_tag), fallamos.
    if [[ "$has_tracked_changes" -eq 1 || "$has_untracked_changes" -eq 1 ]]; then
        echo >&2
        echo "🛑 WORKING TREE DIRTY" >&2
        echo "❌ Tienes cambios sin guardar (dirty working tree)." >&2
        echo "💡 Solución rápida:" >&2
        echo "   - Ver:    git status" >&2
        echo "   - Guardar: git add -A && git commit -m \"...\"" >&2
        echo "   - O stash: git stash -u" >&2
        exit 1
    fi
}

ensure_clean_git_or_die() {
    ensure_clean_git "$@"
}

ensure_commit_ref_exists_local_or_die() {
    local ref="${1:-}"

    if [[ -z "${ref:-}" ]]; then
        echo "❌ Error: falta SHA/ref local para preflight." >&2
        echo "💡 Define DEVTOOLS_PROMOTE_FROM_SHA o ejecuta desde una rama con HEAD válido." >&2
        exit 1
    fi

    if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
        echo "❌ Error: SHA/ref no existe localmente: ${ref}" >&2
        echo "💡 Verifica que el commit/ref esté disponible en este repositorio." >&2
        exit 1
    fi
}

ensure_promote_preflight_or_die() {
    local source_ref="${1:-}"
    ensure_repo_or_die
    ensure_clean_git
    ensure_origin_exists_or_die
    ensure_commit_ref_exists_local_or_die "$source_ref"
}

# ==============================================================================
# 2. DETECCIÓN DE RAÍZ (MONOREPO VS SUBMODULE)
# ==============================================================================

# Detecta la raíz real de trabajo:
# - Si es un submódulo dentro de un superproyecto, devuelve el superproyecto.
# - Si es un repo normal, devuelve el toplevel.
# - Si no hay repo, devuelve el directorio actual (pwd).
detect_workspace_root() {
    local super
    super="$(git rev-parse --show-superproject-working-tree 2>/dev/null || echo "")"
    if [[ -n "$super" ]]; then
        echo "$super"
    else
        git rev-parse --show-toplevel 2>/dev/null || pwd
    fi
}

# ==============================================================================
# 2.1 HELPERS PARA TRACKING DE RAMAS
# ==============================================================================
# Objetivo:
# - Poder sincronizar ramas locales con su remoto aunque NO existan localmente.
# - Evitar estados "a medias" cuando la referencia canónica viene de origin/<branch>.
branch_exists_remote() {
    local branch="$1"
    local remote="${2:-origin}"
    git show-ref --verify --quiet "refs/remotes/${remote}/${branch}"
}

ensure_local_branch_tracks_remote() {
    local branch="$1"
    local remote="${2:-origin}"

    # Siempre traer refs frescas (silencioso)
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true

    # Si ya existe localmente, OK
    if git show-ref --verify --quiet "refs/heads/${branch}"; then
        return 0
    fi

    # Si existe en remoto, creamos local tracking
    if branch_exists_remote "$branch" "$remote"; then
        git checkout -b "$branch" "${remote}/${branch}" >/dev/null 2>&1 || return 1
        return 0
    fi

    return 1
}

# ------------------------------------------------------------------------------
# COMPAT: nombre antiguo usado por workflows legacy
# - Prepara una rama local con tracking al remoto SIN mover la rama actual.
# Uso: ensure_local_tracking_branch <branch> [remote]
ensure_local_tracking_branch() {
    local branch="$1"
    local remote="${2:-origin}"

    [[ -n "${branch:-}" ]] || return 2

    local cur
    cur="$(git branch --show-current 2>/dev/null || echo "")"

    ensure_local_branch_tracks_remote "$branch" "$remote" || return 1

    # Volver a la rama original (evita side-effects en callers)
    if [[ -n "${cur:-}" && "$cur" != "$branch" ]]; then
        git checkout "$cur" >/dev/null 2>&1 || true
    fi

    return 0
}

# Sincroniza la rama local para que coincida EXACTAMENTE con el remoto (verdad canónica)
sync_branch_hard_to_remote() {
    local branch="$1"
    local remote="${2:-origin}"

    ensure_clean_git

    ensure_local_branch_tracks_remote "$branch" "$remote" || {
        echo "❌ No pude preparar la rama '$branch' desde '$remote/$branch'." >&2
        return 1
    }

    git checkout "$branch" >/dev/null 2>&1 || return 1

    # Aseguramos refs frescas
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true

    # Hard reset a remoto (verdad canónica)
    git reset --hard "${remote}/${branch}" >/dev/null 2>&1 || true
    return 0
}

# ==============================================================================
# 3. OPERACIONES DE SUBMÓDULOS
# ==============================================================================

sync_submodules() {
    if [[ -f ".gitmodules" ]]; then
        # Silencioso para no molestar en cada comando
        git submodule update --init --recursive >/dev/null 2>&1 || true
    fi
}

# ==============================================================================
# 4. OPERACIONES DE RAMAS Y REMOTOS
# ==============================================================================

branch_exists_local() {
    git show-ref --verify --quiet "refs/heads/$1"
}

# Actualiza una rama local con su contraparte remota
update_branch_from_remote() {
    local branch="$1"
    local remote="${2:-origin}"
    local no_pull="${3:-false}"

    echo "🔄 Actualizando base '$branch'..."
    
    # Fetch siempre es seguro
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    
    # Checkout (fallará si la rama local no existe)
    git checkout "$branch" >/dev/null 2>&1 || {
        echo "❌ No pude hacer checkout a '$branch'. ¿Existe localmente?" >&2
        return 1
    }
    
    sync_submodules

    if [[ "$no_pull" != "true" ]]; then
        if ! git pull "$remote" "$branch"; then
            echo "❌ Falló pull de '$remote/$branch'." >&2
            return 1
        fi
    fi
}

# ==============================================================================
# 4.1 PUSH DESTRUCTIVO (force / force-with-lease)
# ==============================================================================

# DEVTOOLS_FORCE_PUSH_MODE:
# - with-lease (default): git push --force-with-lease
# - force             : git push --force
push_branch_force() {
    local branch="$1"
    local remote="${2:-origin}"
    local mode="${DEVTOOLS_FORCE_PUSH_MODE:-}"
    mode="$(echo "${mode:-}" | tr -d '[:space:]')"
    [[ -n "${mode:-}" ]] || mode="with-lease"

    case "$mode" in
        force)
            if declare -F log_warn >/dev/null 2>&1; then
                log_warn "⚠️  Modo peligro: DEVTOOLS_FORCE_PUSH_MODE=force (sin lease)" >&2 || true
            else
                echo "⚠️  Modo peligro: DEVTOOLS_FORCE_PUSH_MODE=force (sin lease)" >&2
            fi
            git push "$remote" "$branch" --force
            ;;
        with-lease)
            git push "$remote" "$branch" --force-with-lease
            ;;
        *)
            if declare -F log_warn >/dev/null 2>&1; then
                log_warn "Modo de push desconocido '${mode}'. Usando with-lease." >&2 || true
            else
                echo "⚠️  Modo de push desconocido '${mode}'. Usando with-lease." >&2
            fi
            git push "$remote" "$branch" --force-with-lease
            ;;
    esac
}

# Checkout <branch>, reset --hard <sha>, y force-push a <remote>/<branch>
force_update_branch_to_sha() {
    local branch="$1"
    local sha="$2"
    local remote="${3:-origin}"

    [[ -n "${branch:-}" && -n "${sha:-}" ]] || return 2
    ensure_clean_git

    ensure_local_branch_tracks_remote "$branch" "$remote" || {
        echo "❌ No pude preparar la rama '$branch' desde '$remote/$branch'." >&2
        return 1
    }

    git checkout "$branch" >/dev/null 2>&1 || return 1
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    git reset --hard "$sha" >/dev/null 2>&1 || return 1
    push_branch_force "$branch" "$remote" || return 1
    return 0
}

# ==============================================================================
# 4.2 PROMOCIÓN NO-DESTRUCTIVA POR ESTRATEGIA (FF / MERGE / THEIRS / FORCE)
# ==============================================================================

__git_is_ancestor() {
    local a="$1" b="$2"
    git merge-base --is-ancestor "$a" "$b" >/dev/null 2>&1
}

# Actualiza <branch> hacia <source_sha> aplicando estrategia.
# Echo: SHA final en remoto (origin/<branch>) si OK.
#
# Estrategias:
# - ff-only      : solo fast-forward (si no se puede, rc=3)
# - merge        : merge --no-ff (preserva historial, crea commit)
# - merge-theirs : merge --no-ff -X theirs (tu versión gana, preserva historial)
# - force        : reset --hard + push --force-with-lease (destructivo)
update_branch_to_sha_with_strategy() {
    local branch="$1"
    local source_sha="$2"
    local remote="${3:-origin}"
    local strategy="${4:-ff-only}"

    [[ -n "${branch:-}" && -n "${source_sha:-}" ]] || return 2
    ensure_clean_git

    # refs frescas
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    local old_remote_sha=""
    old_remote_sha="$(git rev-parse "${remote}/${branch}" 2>/dev/null || true)"

    case "$strategy" in
        force)
            force_update_branch_to_sha "$branch" "$source_sha" "$remote" || return 1
            git fetch "$remote" "$branch" >/dev/null 2>&1 || true
            echo "$(git rev-parse "${remote}/${branch}" 2>/dev/null || true)"
            return 0
            ;;
        ff-only|merge|merge-theirs)
            ;;
        *)
            echo "❌ Estrategia inválida: $strategy" >&2
            return 2
            ;;
    esac

    # Asegurar tracking local
    ensure_local_branch_tracks_remote "$branch" "$remote" || {
        echo "❌ No pude preparar la rama '$branch' desde '$remote/$branch'." >&2
        return 1
    }

    # Base canónica: local == remote antes de actuar
    git checkout "$branch" >/dev/null 2>&1 || return 1
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    git reset --hard "${remote}/${branch}" >/dev/null 2>&1 || true

    if [[ "$strategy" == "ff-only" ]]; then
        # Solo FF si destino es ancestro del source
        local base_sha
        base_sha="$(git rev-parse HEAD 2>/dev/null || true)"
        if [[ -n "${base_sha:-}" ]] && ! __git_is_ancestor "$base_sha" "$source_sha"; then
            echo "⚠️  Fast-Forward NO es posible: ${remote}/${branch} no es ancestro de source." >&2
            return 3
        fi
        git merge --ff-only "$source_sha" >/dev/null 2>&1 || return 1
    elif [[ "$strategy" == "merge" ]]; then
        git merge --no-ff --no-edit "$source_sha" || return 1
    elif [[ "$strategy" == "merge-theirs" ]]; then
        git merge --no-ff --no-edit -X theirs "$source_sha" || return 1
    fi

    # Push NO destructivo
    git push "$remote" "$branch" || return 1

    # Verificación post-push
    git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    local new_remote_sha=""
    new_remote_sha="$(git rev-parse "${remote}/${branch}" 2>/dev/null || true)"

    # Garantías mínimas:
    # - merge/ff deben contener source_sha
    # - merge debe preservar old_remote_sha (si existía)
    if [[ -n "${new_remote_sha:-}" ]]; then
        __git_is_ancestor "$source_sha" "$new_remote_sha" || {
            echo "❌ Post-check falló: source_sha no quedó contenido en ${remote}/${branch}." >&2
            return 1
        }
        if [[ "$strategy" != "ff-only" && -n "${old_remote_sha:-}" ]]; then
            __git_is_ancestor "$old_remote_sha" "$new_remote_sha" || {
                echo "❌ Post-check falló: historial previo no quedó preservado en merge." >&2
                return 1
            }
        fi
    fi

    echo "$new_remote_sha"
    return 0
}

# ==============================================================================
# 4.3 CHEQUEO REMOTO (GitHub/Origin Health)
# ==============================================================================
# Verifica conectividad + existencia de ref remota usando git (sin gh).
# Uso: remote_health_check <branch> [remote]
remote_health_check() {
    local branch="$1"
    local remote="${2:-origin}"

    [[ -n "${branch:-}" ]] || { echo "❌ remote_health_check: branch vacío" >&2; return 2; }

    local out rc
    if declare -F try_cmd >/dev/null 2>&1; then
        out="$(try_cmd env GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --heads "$remote" "$branch" 2>/dev/null)"
        rc=$?
    else
        out="$(GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --heads "$remote" "$branch" 2>/dev/null)"
        rc=$?
    fi

    if [[ "$rc" -ne 0 || -z "${out:-}" ]]; then
        # Por defecto NO bloqueamos por red/permisos al verificar remoto.
        # Modo estricto: DEVTOOLS_STRICT_REMOTE_HEALTH=1.
        if [[ "${DEVTOOLS_STRICT_REMOTE_HEALTH:-0}" == "1" ]]; then
            if declare -F log_error >/dev/null 2>&1; then
                log_error "No se pudo verificar remoto: ${remote}/${branch}"
            else
                echo "❌ No se pudo verificar remoto: ${remote}/${branch}" >&2
            fi
            return 1
        fi
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "No se pudo verificar remoto (skip): ${remote}/${branch}"
        else
            echo "⚠️  No se pudo verificar remoto (skip): ${remote}/${branch}" >&2
        fi
        return 0
    fi

    local sha
    sha="$(echo "$out" | awk '{print $1}' | head -n 1)"
    if declare -F log_success >/dev/null 2>&1; then
        log_success "Remoto accesible: ${remote}/${branch} @${sha:0:7}"
    else
        echo "✅ Remoto accesible: ${remote}/${branch} @${sha:0:7}"
    fi
    return 0
}


# ==============================================================================
# 5. DIAGNÓSTICO DE IDENTIDAD
# ==============================================================================

print_git_identity_state() {
    local scope="$1" # local o global
    local name email
    name="$(git config --"$scope" --get-all user.name 2>/dev/null || true)"
    email="$(git config --"$scope" --get-all user.email 2>/dev/null || true)"

    echo "--- Git Identity ($scope) ---"
    if [ -z "$name" ] && [ -z "$email" ]; then
        echo "   (vacío)"
    else
        echo "   user.name: $name"
        echo "   user.email: $email"
    fi
}

# ==============================================================================
# 6. SEGURIDAD DE RAMAS (BRANCH SAFETY / LANDING)
# ==============================================================================

# Restaura la rama original al finalizar el script.
# Si la rama fue borrada (ej. por squash merge), la recrea desde el punto actual (o dev/main según aplique)
# y notifica al usuario.
git_restore_branch_safely() {
    local target_branch="$1"
    
    # Si no hay target o es detached, no hacemos nada crítico
    if [[ -z "$target_branch" || "$target_branch" == "(detached)" ]]; then
        return 0
    fi

    local current
    current="$(git branch --show-current 2>/dev/null || echo "")"

    # Si ya estamos ahí, listo.
    if [[ "$current" == "$target_branch" ]]; then
        return 0
    fi

    echo
    echo "🛬 Finalizando flujo: Volviendo a '$target_branch'..."

    # 1. Intentar checkout normal
    if git checkout "$target_branch" >/dev/null 2>&1; then
        echo "✅ Regreso exitoso a $target_branch."
        return 0
    fi

    # 2. Si falla, asumimos que fue borrada. Intentamos recrearla.
    # NOTA: Al ser una restauración de emergencia, la creamos apuntando al HEAD actual 
    # o idealmente al origen si existe, pero el usuario pidió "recrearla".
    echo "⚠️  La rama '$target_branch' no existe (¿fue borrada durante el merge?)."
    echo "🔄 Recreando '$target_branch' para mantener contexto..."

    if git checkout -b "$target_branch" >/dev/null 2>&1; then
        echo "✅ Rama recreada exitosamente. Estás en '$target_branch'."
        echo "📝 NOTA: Esta es una copia nueva. Verifica tu estado con 'git status'."
    else
        echo "❌ FALLO CRÍTICO: No pude volver ni recrear '$target_branch'." >&2
        echo "📍 Te has quedado en: ${current:-detached HEAD}" >&2
    fi
}

git_remote_url() {
    local remote="${1:-origin}"
    git remote get-url "$remote" 2>/dev/null || git config --get "remote.${remote}.url" 2>/dev/null || true
}

__extract_host_from_git_url() {
    local url="$1"
    url="${url#ssh://}"
    url="${url#https://}"
    url="${url#http://}"
    [[ "$url" == *@* ]] && url="${url#*@}"
    echo "${url%%[:/]*}"
}

__resolve_ssh_hostname() {
    local host="$1"
    command -v ssh >/dev/null 2>&1 || return 1
    ssh -G "$host" 2>/dev/null | awk 'tolower($1)=="hostname" {print $2; exit}'
}

ensure_origin_is_github_com_or_die() {
    # Compatibilidad:
    # - Por defecto solo exigimos que exista origin.
    # - Modo estricto GitHub: DEVTOOLS_REQUIRE_GITHUB=1.
    ensure_origin_exists_or_die
    [[ "${DEVTOOLS_REQUIRE_GITHUB:-0}" == "1" ]] || return 0

    local url host resolved=""
    url="$(git_remote_url origin)"

    if [[ -z "${url:-}" ]]; then
        if declare -F die >/dev/null 2>&1; then
            die "❌ Error: no existe el remoto 'origin'. Configúralo antes de promover."
        fi
        echo "❌ Error: no existe el remoto 'origin'." >&2
        exit 1
    fi

    host="$(__extract_host_from_git_url "$url")"

    # Caso directo: host literal github.com (HTTPS o SSH normal)
    if [[ "$host" == "github.com" ]]; then
        return 0
    fi

    # Caso alias SSH: permitir SOLO si ssh -G resuelve HostName github.com
    resolved="$(__resolve_ssh_hostname "$host" || true)"
    if [[ "$resolved" == "github.com" ]]; then
        return 0
    fi

    echo >&2
    echo "❌ Error: tu remoto 'origin' no apunta a github.com." >&2
    echo "   URL actual: $url" >&2
    if [[ -n "${resolved:-}" ]]; then
        echo "   Host resuelto por SSH: $resolved" >&2
    fi
    echo "💡 Arreglo rápido (ejemplo):" >&2
    echo "   git remote set-url origin git@github.com:OWNER/REPO.git" >&2
    echo >&2
    exit 1
}

ensure_origin_exists_or_die() {
    local url=""
    url="$(git_remote_url origin)"
    if [[ -z "${url:-}" ]]; then
        if declare -F die >/dev/null 2>&1; then
            die "❌ Error: no existe el remoto 'origin'. Configúralo antes de continuar."
        fi
        echo "❌ Error: no existe el remoto 'origin'." >&2
        exit 1
    fi
}

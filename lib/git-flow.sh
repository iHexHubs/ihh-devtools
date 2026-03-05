#!/usr/bin/env bash
# Librería de soporte (devtools)

# ==============================================================================
# 1. VALIDACIONES DE RAMAS
# ==============================================================================

# Verifica si una rama está protegida (no se debe commitear directo)
is_protected_branch() {
  case "$1" in 
    main|dev|staging|local) return 0 ;;
    *) return 1 ;; 
  esac
}

# Limpia un string para que sea válido en una rama (quita espacios, slashes, etc.)
sanitize_feature_suffix() {
  local b="$1"
  b="${b//\//-}"           # Slash -> guion
  b="${b// /-}"            # Espacio -> guion
  b="${b//[^a-zA-Z0-9._-]/-}" # Caracteres raros -> guion
  b="$(echo "$b" | sed -E 's/-+/-/g')" # Guiones duplicados -> uno solo
  echo "$b"
}

# Sugiere el nombre feature/xxx
suggest_feature_branch() { 
    echo "feature/$(sanitize_feature_suffix "$1")" 
}

# Genera un nombre único si la rama ya existe (añade -1, -2, etc.)
unique_branch_name() {
  local name="$1"
  if ! git show-ref --verify --quiet "refs/heads/$name"; then 
      echo "$name"
      return 0
  fi
  
  local i=1
  while git show-ref --verify --quiet "refs/heads/${name}-${i}"; do 
      ((i++))
  done
  echo "${name}-${i}"
}

# ==============================================================================
# 2. POLÍTICAS DE ENFORCEMENT (Feature Branch Workflow)
# ==============================================================================

ensure_feature_branch_or_rename() {
  local branch="$1"
  # Política actual: solo protegemos main/staging/dev/local.
  # Se aceptan ramas feat/* y cualquier otro prefijo sin renombrar.
  return 0
}

ensure_feature_branch_before_commit() {
  local branch
  branch="$(git branch --show-current 2>/dev/null || echo "")"

  # Caso: Head desacoplado (Detached HEAD)
  if [[ -z "$branch" ]]; then
    echo "⚠️ HEAD desacoplado. Creando una rama feature/* para commitear..."
    local short_sha
    short_sha="$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
    git checkout -b "feature/detached-${short_sha}"
    return 0
  fi

  # Check rápido de política desactivada
  [[ "${ENFORCE_FEATURE_BRANCH:-true}" == "true" ]] || return 0
  
  # Si ya es feature/feat, todo OK
  [[ "$branch" == feature/* ]] && return 0
  [[ "$branch" == feat/* ]] && return 0
  # Permitimos rama de laboratorio (nuevo nombre canónico)
  [[ "$branch" == "dev-update" ]] && return 0
  # Compat (deprecado)
  [[ "$branch" == "feature/dev-update" ]] && return 0
  [[ "$branch" == hotfix/* ]] && return 0 # Permitimos hotfix también
  [[ "$branch" == fix/* ]] && return 0    # Permitimos fix también

  # Caso: Rama protegida (main, dev, staging, local...) -> Migrar trabajo a nueva rama
  if is_protected_branch "$branch"; then
    local short_sha new_branch
    
    # Capturar upstream ANTES de movernos de rama (para limpiar bien la protegida)
    local protected_upstream=""
    protected_upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"

    short_sha="$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
    # FIX: normalizar por seguridad (evita casos como "-c79fd03")
    short_sha="$(echo "$short_sha" | tr -cd '0-9a-f')"
    [[ -n "$short_sha" ]] || short_sha="$(date +%Y%m%d%H%M%S)"
    
    # Creamos nombre único basado en la rama original
    new_branch="$(unique_branch_name "$(sanitize_feature_suffix "${branch}-${short_sha}")")"

    ui_header "🧹 Seguridad: Rama protegida detectada"
    ui_warn "Estabas en '$branch' (protegida)."
    ui_info "✅ Para evitar commits en ramas protegidas, tu trabajo se moverá a:"
    ui_success "➡️  $new_branch"
    echo

    git checkout -b "$new_branch"
    
    # Limpieza local de la rama protegida: alinearla a su upstream (solo puntero local)
    if [[ -n "${protected_upstream:-}" ]]; then
        git branch -f "$branch" "$protected_upstream" >/dev/null 2>&1 || true
        ui_info "🧼 Rama protegida '$branch' alineada a '$protected_upstream' (solo local)."
    else
        ui_warn "No se detectó upstream para '$branch'. No se limpió el puntero local."
    fi
    ui_info "📌 Tu commit se hará en '$new_branch'. No perdiste cambios."
    return 0
  fi

  # Política actual: no forzamos renombres en ramas no protegidas.
  return 0
}

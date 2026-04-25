#!/usr/bin/env bash
# vendor.sh — librería de validación de vendorización (P-AMBOS-3 opción C).
# Implementa: tag + SHA + tree_sha + detección de drift.
#
# IMPORTANTE: este módulo es solo lectura. No modifica filesystem.
# No invocarse desde flujos productivos hasta Fase 2C.
# Diseñado para tests con fixtures aislados, no para repos reales.
#
# Referencias:
# - ADR 0003: docs/adr/0003-vendor-strategy.md
# - Schema:   schema/v1.1/lock.json
#
# Convenciones:
# - Funciones públicas: vendor_*
# - Funciones privadas: _vendor_*
# - Exit codes: 0 OK, 1 error genérico, 2 input inválido, 3 lock inválido,
#   4 tag no existe, 5 sha no coincide, 6 tree_sha mal formado o no coincide,
#   7 tag excluido (backup/archived).
# - Logging: a stderr; resultados a stdout.
# - Las funciones retornan (no hacen exit) para no matar al shell del caller
#   cuando se sourcea esta librería en un script o en BATS.

set -euo pipefail

# ===== Helpers privados =====

_vendor_warn() {
    printf '%s\n' "$*" >&2
}

_vendor_log() {
    if [[ "${VENDOR_DEBUG:-0}" == "1" ]]; then
        printf '[vendor] %s\n' "$*" >&2
    fi
}

# Resuelve el directorio raíz de schema/ relativo a la ubicación de este archivo.
# vendor.sh vive en lib/core/ → ../../schema desde aquí.
_vendor_schema_dir() {
    local self_dir
    self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    printf '%s\n' "${self_dir}/../../schema"
}

# Busca el primer python3 disponible que tenga jsonschema y pyyaml.
# Necesario porque algunos PATH (devbox) tienen un python3 sin estas libs;
# typicamente /usr/bin/python3 sí las tiene.
# Stdout: ruta absoluta o nombre del python3 utilizable.
# Exit 0: encontrado. Exit 1: ninguno cumple.
_vendor_find_python3() {
    local candidate
    for candidate in python3 /usr/bin/python3 /usr/local/bin/python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            if "$candidate" -c "import jsonschema, yaml" >/dev/null 2>&1; then
                printf '%s\n' "$candidate"
                return 0
            fi
        fi
    done
    return 1
}

# ===== Funciones públicas =====

# vendor_is_excluded_tag <tag>
# Devuelve si un tag está excluido por convención del ADR 0003.
# Exit 0: NO excluido.
# Exit 7: excluido (matchea backup/* o archived/*).
# Exit 2: input inválido.
vendor_is_excluded_tag() {
    local tag="${1:-}"
    if [[ -z "$tag" ]]; then
        _vendor_warn "vendor_is_excluded_tag: tag vacío"
        return 2
    fi
    case "$tag" in
        backup/*|archived/*)
            return 7
            ;;
        *)
            return 0
            ;;
    esac
}

# vendor_resolve_tag <repo_path> <tag>
# Resuelve un tag a su commit SHA. Falla si el tag no existe o está excluido.
# Stdout: SHA hex 40 chars.
# Exit 0: OK.
# Exit 4: tag no existe en repo_path.
# Exit 7: tag está en lista excluida (backup/*, archived/*).
# Exit 2: argumentos inválidos.
vendor_resolve_tag() {
    local repo_path="${1:-}"
    local tag="${2:-}"

    if [[ -z "$repo_path" || -z "$tag" ]]; then
        _vendor_warn "vendor_resolve_tag: uso: vendor_resolve_tag <repo_path> <tag>"
        return 2
    fi

    if [[ ! -d "$repo_path" ]]; then
        _vendor_warn "vendor_resolve_tag: repo no existe: $repo_path"
        return 2
    fi

    case "$tag" in
        backup/*|archived/*)
            _vendor_warn "vendor_resolve_tag: tag '$tag' excluido por convención (ADR 0003: backup/* y archived/* no son tags de release)"
            return 7
            ;;
    esac

    local sha
    if ! sha="$(git -C "$repo_path" rev-parse --verify "${tag}^{commit}" 2>/dev/null)"; then
        _vendor_warn "vendor_resolve_tag: tag '$tag' no existe en $repo_path"
        return 4
    fi

    printf '%s\n' "$sha"
    return 0
}

# vendor_compute_tree_sha <directory>
# Calcula el SHA del tree git del directorio. El directorio debe ser
# un repo git con HEAD válido. Para Fase 2B, no se soporta el caso
# "repo sin commits con index"; si surge en Fase 2C, se extiende.
# Stdout: SHA hex 40 chars.
# Exit 0: OK.
# Exit 1: directorio no existe o no es repo git.
# Exit 2: argumentos inválidos.
vendor_compute_tree_sha() {
    local directory="${1:-}"

    if [[ -z "$directory" ]]; then
        _vendor_warn "vendor_compute_tree_sha: uso: vendor_compute_tree_sha <directory>"
        return 2
    fi

    if [[ ! -d "$directory" ]]; then
        _vendor_warn "vendor_compute_tree_sha: directorio no existe: $directory"
        return 1
    fi

    if ! git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
        _vendor_warn "vendor_compute_tree_sha: '$directory' no es un repo git"
        return 1
    fi

    local tree
    if ! tree="$(git -C "$directory" rev-parse 'HEAD^{tree}' 2>/dev/null)"; then
        _vendor_warn "vendor_compute_tree_sha: no se pudo resolver HEAD^{tree} en $directory"
        return 1
    fi

    printf '%s\n' "$tree"
    return 0
}

# vendor_validate_lock <lock_path>
# Valida un YAML lock contra schema v1.1/lock.json.
# Stdout: nada en éxito; errores legibles si falla.
# Exit 0: lock válido.
# Exit 1: archivo no existe o YAML no parseable.
# Exit 2: argumentos inválidos.
# Exit 3: lock inválido (estructura no cumple schema v1.1).
vendor_validate_lock() {
    local lock_path="${1:-}"

    if [[ -z "$lock_path" ]]; then
        _vendor_warn "vendor_validate_lock: uso: vendor_validate_lock <lock_path>"
        return 2
    fi

    if [[ ! -f "$lock_path" ]]; then
        _vendor_warn "vendor_validate_lock: archivo no existe: $lock_path"
        return 1
    fi

    local schema_dir schema_file
    schema_dir="$(_vendor_schema_dir)"
    schema_file="${schema_dir}/v1.1/lock.json"

    if [[ ! -f "$schema_file" ]]; then
        _vendor_warn "vendor_validate_lock: schema no encontrado: $schema_file"
        return 1
    fi

    local py
    if ! py="$(_vendor_find_python3)"; then
        _vendor_warn "vendor_validate_lock: no se encontró un python3 con jsonschema y pyyaml instalados"
        return 1
    fi

    local rc=0
    "$py" - "$schema_file" "$lock_path" <<'PYEOF' || rc=$?
import json, sys, yaml
from jsonschema import Draft202012Validator

schema_path = sys.argv[1]
lock_path = sys.argv[2]

try:
    with open(schema_path) as f:
        schema = json.load(f)
except Exception as e:
    print(f"vendor_validate_lock: error leyendo schema: {e}", file=sys.stderr)
    sys.exit(1)

try:
    with open(lock_path) as f:
        data = yaml.safe_load(f)
except Exception as e:
    print(f"vendor_validate_lock: archivo no es YAML legible: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print("vendor_validate_lock: contenido no es un mapping YAML", file=sys.stderr)
    sys.exit(3)

errors = list(Draft202012Validator(schema).iter_errors(data))
if errors:
    for e in errors:
        path = ".".join(str(p) for p in e.absolute_path) or "(root)"
        print(f"{path}: {e.message}")
    sys.exit(3)
PYEOF
    return "$rc"
}

# vendor_check_drift <consumer_root> <source_repo>
# Verifica drift completo entre un consumer y su fuente declarada.
# Lee el lock del consumer en <consumer_root>/<vendor_dir>/lock formato v1.1
# (vendor_dir default: ".devtools", según schema v1.1).
# Stdout: reporte humano (OK / drift-de-referencia / drift-de-contenido).
# Exit 0: sin drift.
# Exit 1: error genérico.
# Exit 3: lock inválido.
# Exit 5: drift de referencia (sha no coincide con tag resuelto).
# Exit 6: drift de contenido (tree_sha no coincide).
vendor_check_drift() {
    local consumer_root="${1:-}"
    local source_repo="${2:-}"

    if [[ -z "$consumer_root" || -z "$source_repo" ]]; then
        _vendor_warn "vendor_check_drift: uso: vendor_check_drift <consumer_root> <source_repo>"
        return 2
    fi

    local subdir=".devtools"
    local lock_path="${consumer_root}/${subdir}/lock"
    if [[ ! -f "$lock_path" ]]; then
        _vendor_warn "vendor_check_drift: lock no existe en $lock_path"
        return 1
    fi

    if ! vendor_validate_lock "$lock_path" >/dev/null 2>&1; then
        _vendor_warn "vendor_check_drift: lock inválido: $lock_path"
        return 3
    fi

    local py
    if ! py="$(_vendor_find_python3)"; then
        _vendor_warn "vendor_check_drift: no se encontró un python3 con jsonschema y pyyaml instalados"
        return 1
    fi

    local fields rc=0
    fields="$("$py" - "$lock_path" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
v = data.get("vendor", {}) or {}
print(v.get("ref", ""))
print(v.get("sha", ""))
print(v.get("tree_sha", ""))
PYEOF
)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        _vendor_warn "vendor_check_drift: error extrayendo campos del lock"
        return 1
    fi

    local declared_ref declared_sha declared_tree_sha
    declared_ref="$(printf '%s\n' "$fields" | sed -n '1p')"
    declared_sha="$(printf '%s\n' "$fields" | sed -n '2p')"
    declared_tree_sha="$(printf '%s\n' "$fields" | sed -n '3p')"

    if [[ -z "$declared_ref" || -z "$declared_sha" ]]; then
        _vendor_warn "vendor_check_drift: lock sin vendor.ref o vendor.sha"
        return 3
    fi

    local actual_sha
    if ! actual_sha="$(vendor_resolve_tag "$source_repo" "$declared_ref" 2>/dev/null)"; then
        printf 'drift-de-referencia: tag=%s no resuelve en %s\n' \
            "$declared_ref" "$source_repo"
        return 5
    fi

    if [[ "$actual_sha" != "$declared_sha" ]]; then
        printf 'drift-de-referencia: tag=%s declarado-sha=%s actual-sha=%s\n' \
            "$declared_ref" "$declared_sha" "$actual_sha"
        return 5
    fi

    if [[ -n "$declared_tree_sha" ]]; then
        local devtools_dir="${consumer_root}/${subdir}"
        local actual_tree_sha=""
        if actual_tree_sha="$(vendor_compute_tree_sha "$devtools_dir" 2>/dev/null)"; then
            if [[ "$actual_tree_sha" != "$declared_tree_sha" ]]; then
                printf 'drift-de-contenido: declarado-tree=%s actual-tree=%s\n' \
                    "$declared_tree_sha" "$actual_tree_sha"
                return 6
            fi
            printf 'OK: sin drift (ref=%s sha=%s tree_sha=%s)\n' \
                "$declared_ref" "$declared_sha" "$declared_tree_sha"
            return 0
        else
            _vendor_warn "vendor_check_drift: no se pudo calcular tree_sha de $devtools_dir; verificación de contenido incompleta"
            printf 'OK: sin drift de referencia (ref=%s sha=%s); tree_sha-no-verificable\n' \
                "$declared_ref" "$declared_sha"
            return 0
        fi
    fi

    printf 'OK: sin drift de referencia (ref=%s sha=%s)\n' "$declared_ref" "$declared_sha"
    _vendor_warn "vendor_check_drift: lock sin vendor.tree_sha; verificación de contenido incompleta"
    return 0
}

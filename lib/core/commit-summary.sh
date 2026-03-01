#!/usr/bin/env bash
# /webapps/ihh-ecosystem/.devtools/lib/core/commit-summary.sh
# Utilidades para resumir commits por tipo y scope (Conventional Commits).

# ==============================================================================
# 1. NORMALIZACION Y PARSEO
# ==============================================================================

commit_summary_type_label() {
    local t="$1"
    case "$t" in
        feat) echo "feat (funciones)" ;;
        fix) echo "fix (correcciones)" ;;
        perf) echo "perf (rendimiento)" ;;
        refactor) echo "refactor (refactorizacion)" ;;
        docs) echo "docs (documentacion)" ;;
        test) echo "test (tests)" ;;
        build) echo "build (build)" ;;
        ci) echo "ci (ci)" ;;
        chore) echo "chore (mantenimiento)" ;;
        security) echo "security (seguridad)" ;;
        otros) echo "otros" ;;
        *) echo "$t" ;;
    esac
}

commit_summary_normalize_type() {
    local t="$1"
    t="$(echo "${t:-}" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$t" ]]; then
        echo "otros"
        return 0
    fi
    echo "$t"
}

commit_summary_has_commits() {
    local range="$1"
    local count
    count="$(git rev-list --count "$range" 2>/dev/null || echo 0)"
    [[ "$count" -gt 0 ]]
}

# ==============================================================================
# 2. COLECTA DE COMMITS
# ==============================================================================

# Devuelve lineas: tipo|scope|breaking|subject
commit_summary_collect() {
    local range="$1"
    local include_merges="${COMMIT_SUMMARY_INCLUDE_MERGES:-0}"

    local args=("$range" "--format=%s%x1f%b%x1e")
    if [[ "$include_merges" != "1" ]]; then
        args+=("--no-merges")
    fi

    git log "${args[@]}" 2>/dev/null \
    | awk -v RS='\x1e' -v FS='\x1f' '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s);
            sub(/[[:space:]]+$/, "", s);
            return s;
        }
        {
            subject=$1; body=$2;
            if (subject ~ /^chore\(release\):[[:space:]]*actualizar changelog/i) next;
            type="otros"; scope=""; breaking=0; clean=subject;
            if (match(subject, /^([A-Za-z0-9]+)(\(([^)]+)\))?(!)?:[[:space:]]*(.+)$/, m)) {
                type=tolower(m[1]);
                scope=m[3];
                clean=m[5];
                if (m[4] == "!") breaking=1;
            }
            if (body ~ /BREAKING CHANGE/) breaking=1;
            clean=trim(clean);
            if (clean == "") clean=subject;
            clean=trim(clean);
            if (clean == "") next;
            printf "%s|%s|%s|%s\n", type, scope, breaking, clean;
        }'
}

# ==============================================================================
# 3. RESUMEN AGRUPADO
# ==============================================================================

# Imprime bloques por tipo, con items por scope.
# Parametros:
# 1) range
# 2) limite_por_tipo (opcional, 0 = sin limite)
commit_summary_grouped() {
    local range="$1"
    local limit_per_type="${2:-${COMMIT_SUMMARY_LIMIT_PER_TYPE:-0}}"

    local lines
    lines="$(commit_summary_collect "$range")"
    if [[ -z "${lines:-}" ]]; then
        echo "Sin commits"
        return 0
    fi

    local -a order=(breaking feat fix perf refactor docs test build ci chore security otros)
    local -A group_lines
    local -A group_count

    while IFS='|' read -r type scope breaking subject; do
        type="$(commit_summary_normalize_type "$type")"

        local item="$subject"
        if [[ "$breaking" == "1" ]]; then
            item="INCOMPATIBLE: $item"
        fi
        if [[ -n "$scope" ]]; then
            item="[$scope] $item"
        else
            item="[sin-scope] $item"
        fi

        group_count["$type"]=$(( ${group_count[$type]:-0} + 1 ))
        if [[ "$limit_per_type" -gt 0 && "${group_count[$type]}" -gt "$limit_per_type" ]]; then
            continue
        fi
        group_lines["$type"]+="- ${item}"$'\n'
    done <<< "$lines"

    local out=""
    local type label
    for type in "${order[@]}"; do
        if [[ -n "${group_lines[$type]:-}" ]]; then
            label="$(commit_summary_type_label "$type")"
            out+="$label"$'\n'
            out+="${group_lines[$type]}"
            out+=$'\n'
        fi
    done

    # Tipos fuera del orden conocido
    for type in "${!group_lines[@]}"; do
        case " ${order[*]} " in
            *" $type "*) continue ;;
        esac
        label="$(commit_summary_type_label "$type")"
        out+="$label"$'\n'
        out+="${group_lines[$type]}"
        out+=$'\n'
    done

    echo "$out" | sed '/^$/d'
}

# Resumen corto por tipo con conteo
commit_summary_counts() {
    local range="$1"

    local lines
    lines="$(commit_summary_collect "$range")"
    if [[ -z "${lines:-}" ]]; then
        echo "Sin commits"
        return 0
    fi

    local -A counts
    while IFS='|' read -r type scope breaking subject; do
        type="$(commit_summary_normalize_type "$type")"
        counts["$type"]=$(( ${counts[$type]:-0} + 1 ))
    done <<< "$lines"

    local -a order=(breaking feat fix perf refactor docs test build ci chore security otros)
    local out=""
    local type label
    for type in "${order[@]}"; do
        if [[ -n "${counts[$type]:-}" ]]; then
            label="$(commit_summary_type_label "$type")"
            out+="${label}: ${counts[$type]}"$'\n'
        fi
    done

    for type in "${!counts[@]}"; do
        case " ${order[*]} " in
            *" $type "*) continue ;;
        esac
        label="$(commit_summary_type_label "$type")"
        out+="${label}: ${counts[$type]}"$'\n'
    done

    echo "$out" | sed '/^$/d'
}

# Lista plana (para "ver todo")
commit_summary_list() {
    local range="$1"
    local limit="${2:-${COMMIT_SUMMARY_LIMIT:-0}}"

    local lines
    lines="$(commit_summary_collect "$range")"
    if [[ -z "${lines:-}" ]]; then
        echo "Sin commits"
        return 0
    fi

    local n=0
    while IFS='|' read -r type scope breaking subject; do
        type="$(commit_summary_normalize_type "$type")"
        local item="$subject"
        if [[ "$breaking" == "1" ]]; then
            item="INCOMPATIBLE: $item"
        fi
        if [[ -n "$scope" ]]; then
            item="[$scope] $item"
        else
            item="[sin-scope] $item"
        fi

        echo "- ${type}: ${item}"

        n=$((n + 1))
        if [[ "$limit" -gt 0 && "$n" -ge "$limit" ]]; then
            break
        fi
    done <<< "$lines"
}

#!/usr/bin/env bash
# Promote strategy: dev-pr-monitor
# Estrategia: PR Monitor & Interactive Dashboard.
# FASES:
# 1. Discovery (Búsqueda de PRs)
# 2. Visualization (Dashboard de estado)
# 3. Interaction (Aprobación, Merge o FORCE PUSH)
# 4. Post-Processing (Release Please)
#
# Dependencias: utils.sh, helpers/gh-interactions.sh, git-ops.sh

# Intentar cargar prompts UI si existen
if [[ -n "${_PROMOTE_LIB_ROOT:-}" && -f "${_PROMOTE_LIB_ROOT}/../ui/prompts.sh" ]]; then
    source "${_PROMOTE_LIB_ROOT}/../ui/prompts.sh"
elif [[ -f "lib/ui/prompts.sh" ]]; then
    source "lib/ui/prompts.sh"
fi

# ==============================================================================
# HELPER LOCAL: STREAMING DE LOGS (La "TV" de GitHub)
# ==============================================================================
stream_branch_activity() {
    local branch="$1"
    local context="$2"
    
    echo
    log_info "📺 [LIVE] Buscando actividad en rama '$branch' ($context)..."
    echo "   (Esperando 5s para que GitHub despierte...)"
    sleep 5

    # Buscamos el run más reciente en esta rama que esté en progreso o queued
    local run_id
    run_id="$(GH_PAGER=cat gh run list --branch "$branch" --limit 1 --json databaseId,status --jq '.[0] | select(.status != "completed") | .databaseId' 2>/dev/null)"

    if [[ -n "$run_id" ]]; then
        log_info "🎥 Conectando a logs en vivo (Run ID: $run_id)..."
        # --exit-status hace que el comando falle si el CI falla, lo cual es lo que queremos saber
        if GH_PAGER=cat gh run watch "$run_id" --exit-status; then
            log_success "✅ CI completado exitosamente."
        else
            log_error "❌ El CI falló. Revisa los logs arriba."
            # No matamos el script aquí, dejamos que el usuario decida o que el chequeo final falle
        fi
    else
        log_warn "ℹ️  No se detectaron workflows activos inmediatos en '$branch'."
    fi
    echo
}


promote_dev_monitor() {
    local input_pr="${1:-}"      # PR sugerido por to-dev.sh (si existe)
    local input_branch="${2:-}"  # Rama origen

    banner "🕵️  MONITOR DE INTEGRACIÓN (Interactivo)"

    local -a pr_candidates=()

    # --------------------------------------------------------------------------
    # 0. VISIBILIDAD TOTAL (Repositorio): mostrar PRs abiertos (sin gate)
    # --------------------------------------------------------------------------
    if declare -F gh_list_open_prs_rich >/dev/null; then
        if ! command -v jq >/dev/null 2>&1; then
            log_warn "ℹ️  'jq' no está disponible. Omitiendo bloque de visibilidad total y continuando con discovery normal."
        else
            local all_json
            all_json="$(gh_list_open_prs_rich 50 2>/dev/null || echo "[]")"

            log_info "📋 PRs abiertos en el repo (visibilidad total):"
            echo "$all_json" | jq -c '.[]' | while read -r pr; do
                ui_render_pr_card "$pr"
            done
            echo

            # Si quieres, puedes usar esto para poblar pr_candidates SOLO hacia dev:
            # (así el monitor te muestra todo, pero “policía” actúa solo sobre base=dev)
            local discovered
            discovered="$(echo "$all_json" | jq -r '.[] | select(.baseRefName=="dev") | .number')"
            # Reiniciamos candidatos y cargamos solo los PRs hacia dev
            for p in $discovered; do
                [[ -n "$p" ]] && pr_candidates+=("$p")
            done
        fi
    fi

    # --------------------------------------------------------------------------
    # 1. Fase de Descubrimiento (Discovery)
    # --------------------------------------------------------------------------

    # Si el bloque 0 ya pobló pr_candidates (PRs hacia dev), no repitas discovery
    if [[ ${#pr_candidates[@]} -eq 0 ]]; then
        if [[ -n "${DEVTOOLS_TARGET_PRS:-}" ]]; then
            for p in $DEVTOOLS_TARGET_PRS; do pr_candidates+=("$p"); done
        elif [[ -n "$input_pr" ]]; then
            pr_candidates+=("$input_pr")
        else
            log_info "🔍 Buscando PRs abiertos hacia 'dev'..."
            local discovered
            discovered="$(gh_discover_prs_to_base "dev")"
            for p in $discovered; do pr_candidates+=("$p"); done
        fi
    fi
    # Siempre: mostrar actividad en dev (builds en curso) si hay TTY
    stream_branch_activity "dev" "Dev Health"

    if [[ ${#pr_candidates[@]} -eq 0 ]]; then
        log_info "✅ Sin PRs abiertos hacia dev."
        return 0
    fi
    # --------------------------------------------------------------------------
    # 2. Fase de Visualización (Data Gathering & Rendering).
    # --------------------------------------------------------------------------
    echo
    log_info "📋 PRs Encontrados (${#pr_candidates[@]}):"
    
    for pr_id in "${pr_candidates[@]}"; do
        # A) Data Gathering profundo
        local json_details
        json_details="$(gh_get_pr_rich_details "$pr_id")"
        
        # B) Renderizado visual
        ui_render_pr_card "$json_details"
        
        # C) Detalle de checks resumido
        echo "   🔎 Detalles de CI/Checks:"
        gh_get_pr_checks_summary "$pr_id" | sed 's/^/      /' | head -n 10
        echo ""
    done

    # --------------------------------------------------------------------------
    # 3. BUCLE INTERACTIVO (ACTION LOOP)
    # --------------------------------------------------------------------------
    local something_merged=0
    export DEVTOOLS_TOUCHED_DEV=0
    
    # Definimos fallback de lectura si prompts.sh no cargó
    if ! declare -F ui_read_option >/dev/null; then
        ui_read_option() { read -r -p "$1" val </dev/tty; echo "$val"; }
    fi

    echo "────────────────────────────────────────────────────────────────────────────────"
    log_info "🕹️  INICIO DE MODO INTERACTIVO"
    
    for pr_id in "${pr_candidates[@]}"; do
        while true; do
            echo
            echo "👉 ACCIÓN REQUERIDA para PR #$pr_id:"
            echo "   [a] ✅ Aprobar y Mergear (Auto-Squash)"
            echo "   [f] ☢️  FORCE PUSH (Ignorar PR y Sobreescribir 'dev')"
            echo "   [s] ⏭️  Saltar (Ignorar por ahora)"
            echo "   [v] 📄 Ver detalles completos (gh view)"
            echo "   [q] 🚪 Cancelar y Salir"
            
            local choice
            choice="$(ui_read_option "   Opción [a/f/s/v/q] > ")"

            case "$choice" in
                a|A)
                    log_info "🚀 Procesando PR #$pr_id..."
                    
                    # 1. Aprobar (Review)
                    log_info "👍 Enviando aprobación (APPROVE)..."
                    if ! gh pr review "$pr_id" --approve; then
                        log_warn "⚠️  No se pudo aprobar (¿Quizás ya aprobaste o eres el autor?). Intentando continuar..."
                    fi

                    # 2. Habilitar Auto-Merge
                    log_info "🤖 Configurando Auto-Merge (Squash + Delete Branch)..."
                    if GH_PAGER=cat gh pr merge "$pr_id" --auto --squash --delete-branch; then
                        log_info "⏳ Esperando que GitHub complete el merge..."
                        
                        # STREAMING: Ver logs mientras se mergea
                        stream_branch_activity "dev" "Merge Check"
                        
                        # 3. Monitorear hasta que el merge ocurra (doble check)
                        local m_sha
                        m_sha="$(wait_for_pr_merge_and_get_sha "$pr_id")"
                        export DEVTOOLS_TOUCHED_DEV=1
                        log_success "✅ Merge completado exitosamente: ${m_sha:0:7}"
                        
                        something_merged=1
                        break 
                    else
                        log_error "❌ Falló auto-merge. Revisa permisos/conflictos o usa [f] Force Push."
                    fi
                    ;;

                f|F)
                    # OPCIÓN NUCLEAR: Ignora el PR y fuerza el estado actual a dev
                    echo
                    log_warn "☢️  ALERTA NUCLEAR: FORCE PUSH"
                    echo "   Esto tomará tu rama actual (HEAD) y SOBREESCRIBIRÁ 'origin/dev'."
                    echo "   - Se ignorarán conflictos (tu código gana)."
                    echo "   - El PR se cerrará automáticamente."
                    echo

                    local confirm
                    confirm="$(ui_read_option "   ¿ESTÁS SEGURO? Escribe 'force' para proceder > ")"

                    if [[ "$confirm" == "force" ]]; then
                        export DEVTOOLS_TOUCHED_DEV=1
                        log_info "🔥 Ejecutando FORCE UPDATE (core): update_branch_to_sha_with_strategy dev <- HEAD (force-with-lease)..."

                        local head_sha new_sha rc
                        head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
                        if [[ -z "${head_sha:-}" ]]; then
                            log_error "No pude resolver HEAD SHA."
                            break
                        fi

                        new_sha="$(update_branch_to_sha_with_strategy "dev" "$head_sha" "origin" "force")"
                        rc=$?

                        if [[ "$rc" -eq 0 && -n "${new_sha:-}" ]]; then
                            log_success "✅ 'dev' ha sido actualizado (force-with-lease). SHA: ${new_sha:0:7}"
                            something_merged=1

                            # Limpieza: Cerramos el PR ya que hicimos bypass
                            log_info "🧹 Limpiando PR #$pr_id..."
                            gh pr close "$pr_id" --delete-branch >/dev/null 2>&1 || true

                            # STREAMING: Ver logs inmediatamente después del force update
                            stream_branch_activity "dev" "Post-Force-Update Build"
                            break
                        else
                            log_error "❌ Falló el force update (rc=$rc). Verifica permisos/red."
                        fi
                    else
                        log_info "🧯 Operación cancelada."
                    fi
                    ;;

                    
                s|S)
                    log_info "⏭️  PR #$pr_id Saltado."
                    break 
                    ;;
                    
                v|V)
                    GH_PAGER=less gh pr view "$pr_id"
                    ;;
                    
                q|Q)
                    log_warn "👋 Operación cancelada por el usuario. Saliendo."
                    return 0
                    ;;
                    
                *)
                    echo "❌ Opción no válida."
                    ;;
            esac
        done
    done

    # Gate estricto final (si quedan PRs no OK → exit!=0), salvo bypass
    if declare -F __strict_gate_check_or_fail >/dev/null 2>&1; then
        if ! __strict_gate_check_or_fail "${pr_candidates[@]}"; then
            log_error "🚨 DEV NO OK: Hay PR(s) abiertos hacia dev sin APPROVAL/CI SUCCESS/MERGEABLE."
            log_warn "Usa export DEVTOOLS_BYPASS_STRICT=1 para bypass de emergencia."
            return 1
        fi
    else
        log_warn "ℹ️  Gate estricto no disponible (__strict_gate_check_or_fail). Continúo en modo degradado."
    fi

    # --------------------------------------------------------------------------
    # 4. POST-PROCESAMIENTO (MINIMAL)
    # --------------------------------------------------------------------------
    if [[ "$something_merged" == "0" ]]; then
        log_info "ℹ️  No se realizaron cambios en dev. Finalizando."
        return 0
    fi

    banner "✨ PROMOCIÓN A DEV FINALIZADA CON ÉXITO"
    echo "👉 Siguiente paso recomendado: git promote staging"
    return 0
}

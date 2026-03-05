#!/usr/bin/env bash
# Promote helpers: gh-interactions
# Helpers de bajo nivel para interactuar con GitHub (gh) y referencias Git.
# Extraído de to-dev.sh para modularidad.
#
# Dependencias esperadas (cargadas por el orquestador): 
# - utils.sh (para log_info, log_error, is_tty)
# - checks.sh (para wait_for_workflow_success_on_ref_or_sha_or_die en modo no-tty)

gh_has_working_jq() {
    command -v jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1
}

gh_warn_missing_jq_once() {
    if [[ "${DEVTOOLS_WARNED_MISSING_JQ:-0}" == "1" ]]; then
        return 0
    fi

    if declare -F log_warn >/dev/null 2>&1; then
        log_warn "jq no está disponible. Se degradan vistas enriquecidas de PR."
    else
        echo "WARN: jq no está disponible. Se degradan vistas enriquecidas de PR." >&2
    fi
    export DEVTOOLS_WARNED_MISSING_JQ=1
}

# ------------------------------------------------------------------------------
# Helpers: Git Remoto (Read-only)
# ------------------------------------------------------------------------------
__remote_head_sha() {
    local branch="$1"
    local remote="${2:-origin}"
    GIT_TERMINAL_PROMPT=0 git fetch "$remote" "$branch" >/dev/null 2>&1 || true
    git rev-parse "${remote}/${branch}" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Helpers: Releases (Pre-release)
# ------------------------------------------------------------------------------
gh_create_prerelease_draft_from_tag() {
    local tag="$1"
    local notes_file="$2"
    local target_sha="$3"
    local remote="${4:-origin}"

    if [[ -z "${tag:-}" || -z "${target_sha:-}" ]]; then
        log_warn "Pre-release draft: faltan datos (tag o SHA)."
        return 0
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null | grep -q "${tag}"; then
        log_warn "Pre-release draft omitido: el tag '${tag}' ya existe en ${remote}."
        return 0
    fi

    if git show-ref --verify --quiet "refs/tags/${tag}"; then
        local current_tag_sha
        current_tag_sha="$(git rev-list -n 1 "$tag" 2>/dev/null || echo "")"
        if [[ -n "${current_tag_sha:-}" && "$current_tag_sha" != "$target_sha" ]]; then
            log_warn "El tag local '${tag}' apunta a ${current_tag_sha:0:7}, no al staging ${target_sha:0:7}. Omitiendo pre-release draft."
            return 0
        fi
    else
        if ! git tag -a "$tag" "$target_sha" -m "Pre-release ${tag}"; then
            log_warn "No pude crear el tag local '${tag}'."
            return 0
        fi
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push "$remote" "$tag" >/dev/null 2>&1; then
        log_warn "No pude hacer push del tag '${tag}' a ${remote}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "No se encontró 'gh'. Pre-release draft omitido."
        log_info "Instala GitHub CLI y ejecuta: gh auth login"
        return 0
    fi

    if ! GH_PAGER=cat gh auth status -t >/dev/null 2>&1; then
        log_warn "GitHub CLI sin sesión. Pre-release draft omitido."
        log_info "Inicia sesión con: gh auth login"
        log_info "Verifica con: gh auth status"
        return 0
    fi

    if [[ ! -f "${notes_file}" ]]; then
        log_warn "Notas no encontradas en '${notes_file}'. Se creará el pre-release draft sin notas."
        notes_file=""
    fi

    local args=(gh release create "$tag" --title "$tag" --prerelease --draft --target "$target_sha")
    if [[ -n "${notes_file}" ]]; then
        args+=(--notes-file "$notes_file")
    else
        args+=(--notes " ")
    fi

    if GH_PAGER=cat "${args[@]}" >/dev/null 2>&1; then
        log_success "Pre-release draft creado: ${tag}"
    else
        log_warn "No pude crear el pre-release draft en GitHub."
    fi
}

gh_create_prerelease_from_tag() {
    local tag="$1"
    local notes_file="$2"
    local target_sha="$3"
    local remote="${4:-origin}"

    if [[ -z "${tag:-}" || -z "${target_sha:-}" ]]; then
        log_warn "Pre-release: faltan datos (tag o SHA)."
        return 0
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null | grep -q "${tag}"; then
        log_warn "Pre-release omitido: el tag '${tag}' ya existe en ${remote}."
        return 0
    fi

    if git show-ref --verify --quiet "refs/tags/${tag}"; then
        local current_tag_sha
        current_tag_sha="$(git rev-list -n 1 "$tag" 2>/dev/null || echo "")"
        if [[ -n "${current_tag_sha:-}" && "$current_tag_sha" != "$target_sha" ]]; then
            log_warn "El tag local '${tag}' apunta a ${current_tag_sha:0:7}, no al staging ${target_sha:0:7}. Omitiendo pre-release."
            return 0
        fi
    else
        if ! git tag -a "$tag" "$target_sha" -m "Pre-release ${tag}"; then
            log_warn "No pude crear el tag local '${tag}'."
            return 0
        fi
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push "$remote" "$tag" >/dev/null 2>&1; then
        log_warn "No pude hacer push del tag '${tag}' a ${remote}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "No se encontró 'gh'. Pre-release omitido."
        log_info "Instala GitHub CLI y ejecuta: gh auth login"
        return 0
    fi

    if ! GH_PAGER=cat gh auth status -t >/dev/null 2>&1; then
        log_warn "GitHub CLI sin sesión. Pre-release omitido."
        log_info "Inicia sesión con: gh auth login"
        log_info "Verifica con: gh auth status"
        return 0
    fi

    if [[ ! -f "${notes_file}" ]]; then
        log_warn "Notas no encontradas en '${notes_file}'. Se creará el pre-release sin notas."
        notes_file=""
    fi

    local args=(gh release create "$tag" --title "$tag" --prerelease --target "$target_sha")
    if [[ -n "${notes_file}" ]]; then
        args+=(--notes-file "$notes_file")
    else
        args+=(--notes " ")
    fi

    if GH_PAGER=cat "${args[@]}" >/dev/null 2>&1; then
        log_success "Pre-release creado: ${tag}"
    else
        log_warn "No pude crear el pre-release en GitHub."
    fi
}

# ------------------------------------------------------------------------------
# Helpers: Releases (Final)
# ------------------------------------------------------------------------------
gh_create_release_draft_from_tag() {
    local tag="$1"
    local notes_file="$2"
    local target_sha="$3"
    local remote="${4:-origin}"

    if [[ -z "${tag:-}" || -z "${target_sha:-}" ]]; then
        log_warn "Release draft: faltan datos (tag o SHA)."
        return 0
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null | grep -q "${tag}"; then
        log_warn "Release draft omitido: el tag '${tag}' ya existe en ${remote}."
        return 0
    fi

    if git show-ref --verify --quiet "refs/tags/${tag}"; then
        local current_tag_sha
        current_tag_sha="$(git rev-list -n 1 "$tag" 2>/dev/null || echo "")"
        if [[ -n "${current_tag_sha:-}" && "$current_tag_sha" != "$target_sha" ]]; then
            log_warn "El tag local '${tag}' apunta a ${current_tag_sha:0:7}, no al main ${target_sha:0:7}. Omitiendo release draft."
            return 0
        fi
    else
        if ! git tag -a "$tag" "$target_sha" -m "Release ${tag}"; then
            log_warn "No pude crear el tag local '${tag}'."
            return 0
        fi
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push "$remote" "$tag" >/dev/null 2>&1; then
        log_warn "No pude hacer push del tag '${tag}' a ${remote}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "No se encontró 'gh'. Release draft omitido."
        log_info "Instala GitHub CLI y ejecuta: gh auth login"
        return 0
    fi

    if ! GH_PAGER=cat gh auth status -t >/dev/null 2>&1; then
        log_warn "GitHub CLI sin sesión. Release draft omitido."
        log_info "Inicia sesión con: gh auth login"
        log_info "Verifica con: gh auth status"
        return 0
    fi

    if [[ ! -f "${notes_file}" ]]; then
        log_warn "Notas no encontradas en '${notes_file}'. Se creará el release draft sin notas."
        notes_file=""
    fi

    local args=(gh release create "$tag" --title "$tag" --draft --target "$target_sha")
    if [[ -n "${notes_file}" ]]; then
        args+=(--notes-file "$notes_file")
    else
        args+=(--notes " ")
    fi

    if GH_PAGER=cat "${args[@]}" >/dev/null 2>&1; then
        log_success "Release draft creado: ${tag}"
    else
        log_warn "No pude crear el release draft en GitHub."
    fi
}

gh_create_release_from_tag() {
    local tag="$1"
    local notes_file="$2"
    local target_sha="$3"
    local remote="${4:-origin}"

    if [[ -z "${tag:-}" || -z "${target_sha:-}" ]]; then
        log_warn "Release: faltan datos (tag o SHA)."
        return 0
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null | grep -q "${tag}"; then
        log_warn "Release omitido: el tag '${tag}' ya existe en ${remote}."
        return 0
    fi

    if git show-ref --verify --quiet "refs/tags/${tag}"; then
        local current_tag_sha
        current_tag_sha="$(git rev-list -n 1 "$tag" 2>/dev/null || echo "")"
        if [[ -n "${current_tag_sha:-}" && "$current_tag_sha" != "$target_sha" ]]; then
            log_warn "El tag local '${tag}' apunta a ${current_tag_sha:0:7}, no al main ${target_sha:0:7}. Omitiendo release."
            return 0
        fi
    else
        if ! git tag -a "$tag" "$target_sha" -m "Release ${tag}"; then
            log_warn "No pude crear el tag local '${tag}'."
            return 0
        fi
    fi

    if ! GIT_TERMINAL_PROMPT=0 git push "$remote" "$tag" >/dev/null 2>&1; then
        log_warn "No pude hacer push del tag '${tag}' a ${remote}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "No se encontró 'gh'. Release final omitido."
        log_info "Instala GitHub CLI y ejecuta: gh auth login"
        return 0
    fi

    if ! GH_PAGER=cat gh auth status -t >/dev/null 2>&1; then
        log_warn "GitHub CLI sin sesión. Release final omitido."
        log_info "Inicia sesión con: gh auth login"
        log_info "Verifica con: gh auth status"
        return 0
    fi

    if [[ ! -f "${notes_file}" ]]; then
        log_warn "Notas no encontradas en '${notes_file}'. Se creará el release sin notas."
        notes_file=""
    fi

    local args=(gh release create "$tag" --title "$tag" --target "$target_sha")
    if [[ -n "${notes_file}" ]]; then
        args+=(--notes-file "$notes_file")
    else
        args+=(--notes " ")
    fi

    if GH_PAGER=cat "${args[@]}" >/dev/null 2>&1; then
        log_success "Release creado: ${tag}"
    else
        log_warn "No pude crear el release en GitHub."
    fi
}

# ------------------------------------------------------------------------------
# Helpers: Encontrar workflows en vivo (sin navegador)
# ------------------------------------------------------------------------------
__wait_for_workflow_run_id_for_sha() {
    # Args: workflow_file, sha_full, optional ref (branch/tag)
    local wf_file="$1"
    local sha_full="$2"
    local ref="${3:-}"

    local timeout="${DEVTOOLS_BUILD_WAIT_TIMEOUT_SECONDS:-1800}"
    local interval="${DEVTOOLS_BUILD_WAIT_POLL_SECONDS:-10}"
    local elapsed=0

    [[ -n "${wf_file:-}" && -n "${sha_full:-}" ]] || return 1

    while true; do
        local run_id=""

        if [[ -n "${ref:-}" ]]; then
            run_id="$(
                GH_PAGER=cat gh run list --workflow "$wf_file" --branch "$ref" -L 50 \
                --json databaseId,headSha,status,conclusion \
                --jq ".[] | select(.headSha==\"$sha_full\") | .databaseId" 2>/dev/null | head -n 1
            )"
        fi

        if [[ -z "${run_id:-}" ]]; then
            run_id="$(
                GH_PAGER=cat gh run list --workflow "$wf_file" -L 50 \
                --json databaseId,headSha,status,conclusion \
                --jq ".[] | select(.headSha==\"$sha_full\") | .databaseId" 2>/dev/null | head -n 1
            )"
        fi

        if [[ -n "${run_id:-}" ]]; then
            echo "$run_id"
            return 0
        fi

        if (( elapsed >= timeout )); then
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

__watch_workflow_success_on_sha_or_die() {
    # Args: workflow_file, sha_full, optional ref (branch/tag), label
    local wf_file="$1"
    local sha_full="$2"
    local ref="${3:-}"
    local label="${4:-workflow}"

    # Si el caller pide skip, respetamos (compat con checks.sh)
    if [[ "${DEVTOOLS_SKIP_WAIT_BUILD:-0}" == "1" ]]; then
        log_warn "DEVTOOLS_SKIP_WAIT_BUILD=1 -> Omitiendo espera de ${label}."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_error "No se encontró 'gh'. No puedo verificar ${label} en GitHub Actions."
        return 1
    fi

    # Modo TTY: progreso real en vivo
    if is_tty; then
        log_info "🏗️  Buscando run de ${label} (${wf_file}) para SHA ${sha_full:0:7}..."
        local run_id=""
        run_id="$(__wait_for_workflow_run_id_for_sha "$wf_file" "$sha_full" "$ref" || true)"
        if [[ -z "${run_id:-}" ]]; then
            log_error "Timeout esperando run de ${wf_file} para SHA ${sha_full:0:7}"
            return 1
        fi

        log_info "📺 Mostrando progreso en vivo: ${label} (run_id=$run_id)"
        if GH_PAGER=cat gh run watch "$run_id" --exit-status; then
            log_success "🏗️  ${label} OK (run_id=$run_id)"
            return 0
        fi

        log_error "${label} falló (run_id=$run_id)"
        return 1
    fi

    # No-TTY: fallback a polling centralizado (función externa, debe estar cargada en entorno)
    wait_for_workflow_success_on_ref_or_sha_or_die "$wf_file" "$sha_full" "$ref" "$label"
}

# ------------------------------------------------------------------------------
# Helpers: Descubrimiento y Visualización (TAREA 2)
# ------------------------------------------------------------------------------

# Retorna una lista de números de PR abiertos hacia una base, separados por espacio
gh_discover_prs_to_base() {
    local base_branch="$1"
    GH_PAGER=cat gh pr list --base "$base_branch" --state open \
        --json number --jq '.[].number' | tr '\n' ' '
}

# Obtiene metadatos ricos de un PR en formato JSON plano (para parsing fácil con jq)
gh_get_pr_rich_details() {
    local pr_number="$1"
    GH_PAGER=cat gh pr view "$pr_number" \
        --json number,title,url,headRefName,baseRefName,reviewDecision,mergeable,statusCheckRollup \
        2>/dev/null || echo "{}"
}

# Obtiene el detalle de los Checks (Jobs) individuales para mostrar al usuario
gh_get_pr_checks_summary() {
    local pr_number="$1"
    GH_PAGER=cat gh pr checks "$pr_number" || echo "No checks found."
}

gh_list_open_prs_rich() {
  local limit="${1:-30}"
  GH_PAGER=cat gh pr list --state open -L "$limit" \
    --json number,title,url,headRefName,baseRefName,reviewDecision,mergeable,statusCheckRollup
}

# Renderiza una "Tarjeta" visual del PR en la terminal
ui_render_pr_card() {
    local pr_json="$1"

    if ! gh_has_working_jq; then
        gh_warn_missing_jq_once
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "📄 PR (vista básica sin jq):"
        echo "${pr_json}"
        echo "────────────────────────────────────────────────────────────────────────────────"
        return 0
    fi

    # Parseo seguro con jq
    local num title url head base decision mergeable ci_state
    num="$(echo "$pr_json" | jq -r '.number // "0"')"
    title="$(echo "$pr_json" | jq -r '.title // "Sin título"')"
    url="$(echo "$pr_json" | jq -r '.url // ""')"
    head="$(echo "$pr_json" | jq -r '.headRefName // "?"')"
    base="$(echo "$pr_json" | jq -r '.baseRefName // "?"')"
    decision="$(echo "$pr_json" | jq -r '.reviewDecision // "NONE"')"
    mergeable="$(echo "$pr_json" | jq -r '.mergeable // "UNKNOWN"')"

    ci_state="$(echo "$pr_json" | jq -r 'if (.statusCheckRollup | type) == "object" then (.statusCheckRollup.state // "NO_CI") else "NO_CI" end')"

    # Iconografía
    local icon_ci="⚪"
    [[ "$ci_state" == "SUCCESS" ]] && icon_ci="✅"
    [[ "$ci_state" == "FAILURE" ]] && icon_ci="❌"
    [[ "$ci_state" == "PENDING" ]] && icon_ci="⏳"

    local icon_review="🛡️"
    [[ "$decision" == "APPROVED" ]] && icon_review="👍"
    [[ "$decision" == "CHANGES_REQUESTED" ]] && icon_review="🚫"

    local icon_merge="🧩"
    [[ "$mergeable" == "MERGEABLE" ]] && icon_merge="⚡"
    [[ "$mergeable" == "CONFLICTING" ]] && icon_merge="💥"

    echo "────────────────────────────────────────────────────────────────────────────────"
    echo "📄 PR #$num: $title"
    echo "   $icon_review Review: $decision  |  $icon_merge Merge: $mergeable  |  $icon_ci CI: $ci_state"
    echo "   🌿 Rama: $head -> $base"
    echo "   🔗 $url"
    echo "────────────────────────────────────────────────────────────────────────────────"
}

# ------------------------------------------------------------------------------
# Helpers: Pull Request (Aprobación y Release Please)
# ------------------------------------------------------------------------------

wait_for_pr_approval_or_die() {
    local pr_number="$1"
    local timeout="${DEVTOOLS_PR_APPROVAL_TIMEOUT_SECONDS:-0}"
    local interval="${DEVTOOLS_PR_APPROVAL_POLL_SECONDS:-10}"
    local elapsed=0

    if [[ "${DEVTOOLS_SKIP_PR_APPROVAL_WAIT:-0}" == "1" ]]; then
        log_warn "DEVTOOLS_SKIP_PR_APPROVAL_WAIT=1 -> Omitiendo espera de aprobación del PR."
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_error "Se requiere 'gh' para verificar aprobación del PR."
        return 1
    fi

    log_info "⏳ Esperando aprobación del PR #$pr_number (reviewDecision=APPROVED)..."

    while true; do
        local state decision merged_at
        state="$(GH_PAGER=cat gh pr view "$pr_number" --json state --jq '.state // ""' 2>/dev/null || echo "")"
        decision="$(GH_PAGER=cat gh pr view "$pr_number" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null || echo "")"
        merged_at="$(GH_PAGER=cat gh pr view "$pr_number" --json mergedAt --jq '.mergedAt // ""' 2>/dev/null || echo "")"

        # ✅ Si ya está mergeado, no tiene sentido esperar aprobación.
        if [[ -n "${merged_at:-}" && "${merged_at:-null}" != "null" ]]; then
            log_success "✅ PR #$pr_number ya está MERGED (mergedAt=$merged_at)."
            return 0
        fi

        if [[ "$decision" == "APPROVED" ]]; then
            log_success "✅ PR #$pr_number aprobado."
            return 0
        fi

        if [[ "$state" == "CLOSED" ]]; then
            log_error "El PR #$pr_number está CLOSED y no fue aprobado/mergeado. Abortando."
            return 1
        fi

        if (( timeout > 0 && elapsed >= timeout )); then
            log_error "Timeout esperando aprobación del PR #$pr_number."
            return 1
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

wait_for_release_please_pr_number_optional() {
    local timeout="${DEVTOOLS_RP_PR_WAIT_TIMEOUT_SECONDS:-60}"
    local interval="${DEVTOOLS_RP_PR_WAIT_POLL_SECONDS:-2}"
    local elapsed=0

    # 0 = no esperar, retorno vacío
    if [[ "${timeout}" == "0" ]]; then
        echo ""
        return 0
    fi

    while true; do
        local pr_number
        pr_number="$(
            GH_PAGER=cat gh pr list --base dev --state open --json number,headRefName --jq \
            '.[] | select(.headRefName | startswith("release-please--")) | .number' 2>/dev/null | head -n 1
        )"

        if [[ "${pr_number:-}" =~ ^[0-9]+$ ]]; then
            echo "$pr_number"
            return 0
        fi

        if (( elapsed >= timeout )); then
            echo ""
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

# Aprueba el PR y valida que GitHub haya registrado el cambio de estado
gh_approve_pr_and_validate() {
    local pr="$1"
    log_info "👍 Aprobando PR #$pr ..."
    local out
    out="$(GH_PAGER=cat gh pr review "$pr" --approve 2>&1)" || {
        echo "$out" >&2
        if echo "$out" | grep -qi "approve your own pull request"; then
            log_warn "🚫 GitHub no permite aprobar tu propio PR. Usa [m] merge (admin) o [f] force push."
        fi
        log_error "❌ Falló la aprobación del PR #$pr."
        return 1
    }
    local decision
    decision="$(GH_PAGER=cat gh pr view "$pr" --json reviewDecision --jq '.reviewDecision' 2>/dev/null || true)"
    if [[ "$decision" == "APPROVED" ]]; then
        log_success "✅ PR #$pr quedó APROBADO."
        return 0
    fi
    log_warn "⚠️ PR #$pr no aparece como APPROVED (reviewDecision=$decision)."
    return 1
}

# Monitorea el CI de un PR, esperando primero a que aparezca un Run
gh_watch_pr_ci() {
    local pr="$1"; local label="${2:-PR CI}"
    local run_id=""
    local tries=60
    while [[ $tries -gt 0 ]]; do
        run_id="$(gh_find_run_id_for_pr "$pr" || true)"
        [[ -n "${run_id:-}" ]] && break
        log_info "⏳ Esperando run para PR #$pr ... ($tries)"
        sleep 5
        tries=$((tries-1))
    done
    [[ -n "${run_id:-}" ]] || {
        log_warn "ℹ️ No encontré runs para PR #$pr (puede que tu CI corra solo al merge/push a dev)."
        return 0
    }
    
    declare -F ui_render_run_dashboard >/dev/null && ui_render_run_dashboard "$run_id" "$label"
    GH_PAGER=cat gh run watch "$run_id" --exit-status 2>&1 || return 1
    declare -F ui_render_run_dashboard >/dev/null && ui_render_run_dashboard "$run_id" "${label} (final)"
    return 0
}

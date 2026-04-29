# HANDOFF — ihh-devtools

> Punto de entrada rápido para sesiones nuevas. Resumen ejecutivo.
> Para detalle granular, ver `docs/project-state.md`.
>
> Última actualización: 2026-04-26
> Última fase cerrada: Fase 2B (commit `ddf04486`).
> Bloques posteriores aplicados (sesión 2026-04-26):
>   - erd-ecosystem: `SEC-2A` (commit `7ad85d4`).
>   - ihh-devtools: `SEC-2B-Phase1` (commit `d190e9e6`) y `SEC-2B-Cleanup-Light` (commit `d55f2f26`).
> Próxima fase recomendada: ver §9 (menú de 3 opciones reales).

## 1. Rol del repo

`ihh-devtools` es el **toolset canónico universal** del ecosistema.
Se vendoriza en repos consumidores como subdirectorio `.devtools/`.
Implementa flujos estandarizados de commits, promoción entre ramas,
SemVer, changelog y sync GitOps. El consumo se declara via schema
universal (`contract.yaml`); el toolset opera sin asumir nombre de
proyecto, lenguaje ni dominio.

NO es específico de PMBOK ni de iHexHubs. La identidad organizacional
en el contract (`identity.family`, `identity.domain`) es metadata,
no operativa.

## 2. Cómo continuar en nueva sesión

1. Leer este `HANDOFF.md` completo.
2. Leer `docs/project-state.md` para detalle granular.
3. Revisar ADRs relevantes:
   - `docs/adr/0001-devtools-consolidation.md`
   - `docs/adr/0003-vendor-strategy.md`
4. Leer `docs/schema-v1.md` (cara humana del schema v1 + v1.1).
5. NO saltar a Fase 2C sin análisis previo.
6. NO tocar erd-ecosystem desde este repo. Tiene su propio HANDOFF.

## 3. Alcance

### Dentro de alcance

- Schema universal (`schema/v1/`, `schema/v1.1/`).
- Validador de vendorización (`lib/core/vendor.sh`).
- Suite contractual (`tests/contracts/`).
- Documentación canónica (ADRs, schema docs, este HANDOFF,
  `docs/project-state.md`).

### Fuera de alcance

- Migración real de consumidores (vive en cada consumer).
- Resolución aislada del tag fantasma `v0.1.1-rc.1+build.40`.
- Movimiento del tag `v0.1.1`.
- Eliminación de hardcodings PMBOK (corresponde a Fase 3).
- Cambios cosméticos sin justificación.

## 4. Fases completadas

### Fase 1 — Schema universal v1 (commit `a1f66277`)

- **Objetivo:** publicar contrato técnico formal del consumidor.
- **Archivos principales:** `schema/v1/contract.json`,
  `schema/v1/lock.json`, `schema/v1/examples/*.yaml` (5 ejemplos),
  `docs/schema-v1.md`.
- **Validaciones:** JSON válido, JSON Schema válido contra Draft
  2020-12, ejemplos válidos pasan, ejemplo inválido falla con
  error legible.
- **Resultado:** schema universal publicado con
  `additionalProperties: false`, sin defaults retrocompatibles.
- **Fuera de alcance de la fase:** loader runtime, integración
  con consumer.

### Fase 2A — Schema v1.1 + ADR 0003 (commit `c8362767`)

- **Objetivo:** bumpar schema a v1.1 (no breaking) con
  `vendor.tree_sha` opcional + ADR formal de vendorización.
- **Archivos principales:** `schema/v1.1/contract.json`,
  `schema/v1.1/lock.json`, `schema/v1.1/examples/*.yaml`
  (2 ejemplos), `docs/adr/0003-vendor-strategy.md`,
  `docs/schema-v1.md` (sección 9).
- **Validaciones:** retrocompatibilidad confirmada (lock v1.0
  valida contra v1.1), ejemplos pasan, schema v1 preservado intacto.
- **Resultado:** base contractual de P-AMBOS-3 publicada. ADR
  documenta decisiones 1 (bump v1.1), 2 (tag de referencia
  `v0.1.0-rc.7`), 3 (P-AMBOS-4 diferida).
- **Fuera de alcance de la fase:** código que consuma el schema.

### Fase 2B — Validador dry-run (commit `ddf04486`)

- **Objetivo:** implementar librería bash testeada que valide tag,
  SHA y tree_sha contra fixtures controlados, sin invocación
  productiva.
- **Archivos principales:** `lib/core/vendor.sh` (5 funciones
  públicas), `tests/contracts/vendor.bats` (18 tests),
  `tests/contracts/fixtures/*.yaml` (5 fixtures).
- **Validaciones:** 18/18 tests BATS pasan, sintaxis bash OK,
  sin `git describe` sin filtros, sin hardcoding de dominios,
  sin operaciones destructivas, `task ci` exit 0.
- **Resultado:** librería operativa pero **sin invocación
  productiva**. Solo se invoca desde la suite BATS contra fixtures.
- **Fuera de alcance de la fase:** CLI, task expuesto, integración
  con `git-devtools-update.sh`, lectura de consumer real.

### Bloque SEC-2A — refactor seguridad terraform en erd-ecosystem (commit `7ad85d4`)

- **Repo:** erd-ecosystem (no ihh-devtools, pero relevante para trazabilidad del ecosistema).
- **Objetivo:** retirar literales triviales (`secretpassword`, `django-insecure-change-me-via-terraform`, `pmbok_user`, `pmbok_db`) del módulo Terraform `main-stack` y eliminar `devops/prod/compose.yml` heredado.
- **Archivos principales:** `devops/aws/modules/main-stack/{secrets.tf,rds.tf,variables.tf}`, `devops/prod/compose.yml` (eliminado).
- **Validaciones:** sintaxis bash OK en scripts colaterales; baseline `changelog-check.sh` no afectado; `terraform plan` queda como tarea humana posterior.
- **Resultado:** `secrets.tf` usa `random_password` para `db_password` y `django_secret_key`; `rds.tf` y `secrets.tf` consumen `var.db_username` / `var.db_name` con validation block (sin defaults).
- **Hallazgos cerrados:** `SEC-09`, `SEC-10`, `SEC-13`, `SEC-18`.
- **Fuera de alcance:** k8s manifests (`SEC-2C`), compose locales (`SEC-2E`), workflows (Fase 3).

### Bloque SEC-2B-Phase1 — toolset genérico (commit `d190e9e6`)

- **Objetivo:** retirar acoplamiento explícito a PMBOK del `devbox.json` raíz; cerrar parcialmente `P-AMBOS-5`.
- **Archivos principales:** `devbox.json`, `README.md`, `versioning-research.md`.
- **Validaciones:** `jq . devbox.json` válido; sin matches a `pmbok|django-insecure|secretpassword`; escape Unicode de `DEVBOX_ENV_NAME` preservado byte a byte.
- **Resultado:** bloque `env` reducido a `DEVBOX_ENV_NAME`; `scripts.backend`/`scripts.frontend` PMBOK eliminados; `init_hook` con mensaje genérico y label `DEV` en case "Dev"; migration note añadida en README §5.1.
- **Hallazgos cerrados:** `SEC-19` (parcial: bloque `env` del `devbox.json`); `H-AMBOS-9` parcial (Phase2 pendiente); `P-AMBOS-5` parcial (decisión "toolset genérico" registrada); `T-AMBOS-3` Phase1; `B-AMBOS-3` retirado de bloqueos activos.
- **Fuera de alcance:** `lib/promote/workflows/**` (Phase2; ~40 menciones literales), tests, schema, ADRs.

### Bloque SEC-2B-Cleanup-Light — limpieza residual (commit `d55f2f26`)

- **Objetivo:** endurecer guardas en wrappers y desacoplar paths absolutos del repo del operador.
- **Archivos principales:** `bin/git-feature.sh`, `bin/git-pipeline.sh`, `README.md`, `docs/migration-2026-04/README.md`, `docs/project-state.md`, `docs/adr/0001-devtools-consolidation.md`, `docs/schema-v1.md`.
- **Validaciones:** `bash -n` OK en ambos scripts; 0 hits para path absoluto del clon en `*.md`/`*.sh`/etc.; 0 hits para `44 menciones`/`44 hardcodings`; 0 hits para `eval "` en `git-pipeline.sh`.
- **Resultado:** `git-feature.sh` valida `BASE_BRANCH` y `REMOTE` antes de `update_branch_from_remote` (`N-SCR-1`); `git-pipeline.sh` cambia `eval` por `bash -c` (`N-SCR-2`); paths absolutos de docs reemplazados por placeholders portables; conteo "44" actualizado a "~40 (Phase2)" en `project-state.md` §3, §5, §8.
- **Hallazgos cerrados:** `N-SCR-1`, `N-SCR-2`, deuda documental de paths absolutos, coherencia README L262 con `P-AMBOS-5` cerrado.
- **Fuera de alcance:** `H-IHH-14` (refactor `git-acp.sh`), `T-IHH-20` (suite de regresión específica de workflows), Phase2.

### Bloque B-4 — ADR 0002 + cableado SSoT de servicios

- **Objetivo:** registrar la decisión arquitectónica de fuente de verdad de servicios y jerarquía oficial de resolución antes de SEC-2B-Phase2 (B-5). Bloque structural sin código nuevo.
- **Archivos principales:** `docs/adr/0002-services-source-of-truth.md` (nuevo), `docs/adr/README.md` (índice), `devtools.repo.yaml` (`registries.deploy: ecosystem/services.yaml`).
- **Validaciones:** YAML válido (`yq`); `task ci` exit 0; suites contractuales sin regresión.
- **Resultado:** ADR 0002 acepta compatibilidad híbrida `services.yaml` (Forma A, SSoT presente) + `contract.yaml/components[]` (Forma B, futura v2). Jerarquía oficial: ENV var → archivo declarativo → error claro. Cero fallback silencioso a literales (`pmbok`, `iHexHubs`, `elrincondeldetective`). Schema v1.1 no requiere modificación.
- **Hallazgos cerrados:** decisión arquitectónica registrada (precondición de B-5).
- **Fuera de alcance:** `lib/core/services.sh` (B-5), refactor `lib/promote/workflows/**` (B-5), migración Forma A → Forma B (deuda v2 futura).

### Bloque B-5 — SEC-2B-Phase2 (helper de servicios + refactor workflows)

- **Objetivo:** implementar la jerarquía oficial registrada en ADR 0002 y refactorizar mecánicamente los 8 archivos de `lib/promote/workflows/**` con ~40 menciones literales `pmbok` para que consuman el helper.
- **Archivos principales:** `lib/core/services.sh` (nuevo, helper canónico), `lib/promote/workflows/{common.sh,to-dev.sh,to-local/{10-utils,20-ci-gate,40-build,50-k8s,60-argocd,90-main}.sh}` (refactor), `tests/contracts/services.bats` (suite nueva, 22 tests).
- **Validaciones:** `bash -n` OK en los 9 archivos shell; `task lint:shell` exit 0; `task lint:contamination` exit 0; `task ci` exit 0; las 4 suites contractuales verde (vendor 18/18, git-acp 19/19, promote-workflows 21/21 sin regresión, services 22/22 nueva).
- **Resultado:** `lib/core/services.sh` con 8 funciones públicas (`services_resolve_path`, `services_load`, `services_resolve_by_id`, `services_resolve_by_path`, `services_image_for`, `services_argocd_app_for`, `services_changelog_for`, `services_local_image_name`) que implementan la jerarquía oficial ENV var → archivo declarativo → error claro. Cero defaults literales `pmbok` en lógica de control de flujo. Las 5 categorías virtuales de `resolve_promote_component` (`ihh`, `pmbok`, `iHexHubs`, `devbox`, `ihh-ecosystem`) se preservan como etiquetas de cambio.
- **Hallazgos cerrados:** `H-AMBOS-9` Phase2, `T-AMBOS-3` Phase2, SEC-2B-Phase2.
- **Fuera de alcance:** templates de workflows GitHub Actions (futuro), `.ci/contract-checks.yaml` (sub-deuda P2), migración Forma A → Forma B (deuda v2 futura).

## 5. Decisiones cerradas

- **5.1** ihh-devtools será toolset universal, no específico-multi.
- **5.2** Schema declarativo obligatorio (`contract.yaml`).
- **5.3** Defaults explícitos con rampa asistida (3-4 sem
  preparación + 1 sem dry-run + cutover único + 1 sem soporte).
  Sin fallbacks legacy permanentes.
- **5.4** P-AMBOS-3 opción C: tag + SHA + `tree_sha` opcional.
- **5.5** Schema v1.1 con `tree_sha` opcional, no breaking.
- **5.6** NO crear el tag fantasma `v0.1.1-rc.1+build.40`.
- **5.7** NO mover el tag `v0.1.1`.
- **5.8** Tag de referencia futuro recomendado: `v0.1.0-rc.7`,
  sujeto a validación de contenido en Fase 2C.
- **5.9** P-AMBOS-4 diferida hasta Fase 2D. NO bloquea Fases 2A-2C.
- **5.10** P-AMBOS-5 cerrada parcialmente en SEC-2B-Phase1 (commit `d190e9e6`, 2026-04-26): toolset genérico sin asunciones de stack (Django/Vite/PMBOK) en `devbox.json` raíz. Phase2 (refactor de `lib/promote/workflows/**`, ~40 menciones literales `pmbok`) desbloqueada conceptualmente tras cierre de `T-IHH-20` en B-3; pendiente de ejecución como bloque separado.
- **5.11** ADR 0002 (B-4): fuente de verdad de servicios (Forma A `services.yaml` operativa + Forma B `contract.yaml/components[]` futura) y jerarquía oficial de resolución (ENV var → archivo declarativo → error claro, sin fallback silencioso a literales). `devtools.repo.yaml.registries.deploy` cableado con default `ecosystem/services.yaml`. Precondición arquitectónica de SEC-2B-Phase2 (B-5).
- **5.12** SEC-2B-Phase2 cerrada en B-5 (2026-04-27): `lib/core/services.sh` implementa la jerarquía de ADR 0002; `lib/promote/workflows/**` consume el helper sin defaults literales `pmbok`. Las 5 categorías virtuales de `resolve_promote_component` (`ihh`, `pmbok`, `iHexHubs`, `devbox`, `ihh-ecosystem`) se preservan como etiquetas de cambio (no son IDs de servicios; ADR 0002 §1).

## 6. Archivos clave actuales

| Path | Contenido | Estado |
|---|---|---|
| `schema/v1/contract.json` | Schema v1 del contract | publicado |
| `schema/v1/lock.json` | Schema v1 del lock | publicado |
| `schema/v1.1/contract.json` | Schema v1.1 (paridad funcional) | publicado |
| `schema/v1.1/lock.json` | Schema v1.1 con `tree_sha` opcional | publicado |
| `docs/schema-v1.md` | Cara humana del schema | publicado |
| `docs/adr/0001-devtools-consolidation.md` | ADR consolidación | aceptado |
| `docs/adr/0003-vendor-strategy.md` | ADR P-AMBOS-3 opción C | aceptado |
| `docs/adr/README.md` | Índice de ADRs | actualizado |
| `docs/project-state.md` | Estado detallado del proyecto | publicado |
| `lib/core/vendor.sh` | Validador dry-run (5 funciones) | publicado |
| `tests/contracts/vendor.bats` | Suite BATS (18 tests) | 18/18 pasa |
| `tests/contracts/fixtures/*.yaml` | Fixtures contractuales | publicados |

## 7. Qué valida Fase 2B

Funciones públicas en `lib/core/vendor.sh`:

- `vendor_resolve_tag <repo> <tag>`: confirma tag existe, devuelve
  commit SHA. Exit 4 si no existe, exit 7 si está excluido
  (`backup/*`, `archived/*`).
- `vendor_compute_tree_sha <directory>`: calcula tree SHA del
  directorio (debe ser repo git con HEAD).
- `vendor_validate_lock <lock_path>`: valida YAML contra
  `schema/v1.1/lock.json`. Exit 3 si schema falla.
- `vendor_check_drift <consumer_root> <source_repo>`: verifica
  consistencia tag/SHA/tree_sha. Exit 5 drift de referencia,
  exit 6 drift de contenido.
- `vendor_is_excluded_tag <tag>`: utility para excluir
  `backup/*` y `archived/*`.

Garantías comprobadas por la suite BATS:

- Tag existente resuelve, tag inexistente falla con error claro.
- Tags `backup/*` y `archived/*` excluidos.
- Tag fantasma falla.
- `tree_sha` opcional: locks sin él validan; locks con él
  exigen formato hex de 40 chars.
- Sin `git describe` sin filtros en código.
- Sin hardcoding de dominios.
- Sin operaciones destructivas.
- Modo dry-run: sin tocar consumidores reales.

## 8. Qué NO está integrado todavía

- Sin CLI final. No hay `bin/vendor-check.sh` ni binario expuesto.
- Sin task expuesto. `Taskfile.yaml` NO tiene `task vendor:check`.
- Sin integración con `git-devtools-update.sh`.
- Sin migración de erd-ecosystem.
- Sin modificación de `.devtools.lock` legacy.
- Sin resolución de P-AMBOS-4.
- Eliminación de hardcodings PMBOK Phase1 cerrada (SEC-2B-Phase1, commit `d190e9e6`): `devbox.json` raíz purgado de literales superficiales. Phase2 pendiente: ~40 menciones literales `pmbok` en `lib/promote/workflows/**`. Desbloqueada conceptualmente tras cierre de `T-IHH-20` (B-3); pendiente de ejecución.

## 9. Próximo paso recomendado

Tres opciones reales según prioridad operativa. **Elegir una; no avanzar en paralelo sin ADR.**

### 9.1 Opción A — `T-IHH-20` (suite de regresión para `lib/promote/workflows/**`) — APLICADA EN B-3

- **Estado:** resuelto en bloque B-3.
- **Resultado:** suite contractual `tests/contracts/promote-workflows.bats` con 21 tests cubriendo funciones casi puras de `lib/promote/workflows/{common.sh,to-local/10-utils.sh,to-local/50-k8s.sh}`: `resolve_promote_component` (6), `promote_is_protected_branch` (4), `promote_local_is_valid_tag_name` (3), `promote_local_read_overlay_tag_from_text` (2), `promote_local_next_tag_from_previous` (2 con mocks puntuales), `promote_local_pull_policy` (3) e invariante estructural (1). Estrategia: invocación dry-run con stubs de logging. Funciones que requieren docker/kubectl/argocd/red excluidas a propósito (techo del alcance de B-3).
- **Cierra:** `T-IHH-20`. Desbloquea conceptualmente SEC-2B-Phase2 (refactor `pmbok` en `lib/promote/workflows/**`), pendiente de ejecución como bloque separado.

### 9.2 Opción B — `H-IHH-14` (refactor `git-acp.sh` con `git add` controlado) — APLICADA EN B-2

- **Estado:** resuelto en bloque B-2.
- **Resultado:** default de staging cambia a `confirm` (muestra `git status --short` y pide `[Y/n]` antes de `git add .`). Flags nuevos: `--staged-only` / `--no-add` (no toca el index), `--interactive` / `-p` (`git add -p`), `--yes` / `--no-confirm` (legacy explícito). Variable `DEVTOOLS_ACP_DEFAULT_MODE` (`confirm \| staged \| interactive \| yes`) controla el default; flag CLI siempre gana. Helper en `lib/core/acp-mode.sh`. Suite contractual en `tests/contracts/git-acp.bats` (19 tests, todos verde).
- **Cierra:** `H-IHH-14` y `T-IHH-15`.

### 9.3 Opción C — pausar trabajo en ihh-devtools y avanzar en erd-ecosystem (SEC-2C)

- **Por qué:** SEC-2A cerró Terraform; SEC-2C atacaría k8s manifests (`devops/k8s/components/postgres-db/secret.yaml`, overlays con `django-insecure-*`). Es trabajo contiguo en el consumer principal con mayor visibilidad de impacto.
- **Esfuerzo estimado:** mediano-grande (decisión arquitectónica ExternalSecret/SealedSecret + rotación coordinada + manifests + ADR).
- **Cierra:** `SEC-01`, `SEC-02`, `SEC-03..08`, `SEC-11`.

### 9.4 Fase 2C (validador integrado) sigue diferida

La integración del validador `vendor.sh` en CLI productivo (`bin/vendor-check.sh` + `task vendor:check`) sigue siendo trabajo válido pero **no urgente**. Requiere decisiones humanas previas (strictness, lectura de lock legacy en paralelo, caso `git write-tree` sin HEAD). Documentado en `docs/project-state.md` §4.4.4 y §9.3.

NO migrar erd-ecosystem todavía. NO tocar tag fantasma aislado. NO tocar `.devtools.lock` cosméticamente.

## 10. T-AMBOS-5 — Migración de suites BATS (2026-04-28, sin commit)

- Migradas desde `erd-ecosystem/.devtools/tests/` a
  `ihh-devtools/tests/contracts/`:
    - `devbox-guardrails.bats`     (5 tests, 5/5 ok)
    - `devbox-init-hook.bats`      (4 tests, 4/4 ok — greps adaptados de literales `$root/.devtools` a forma con variables `$DT_ROOT/$DT_BIN`)
    - `devbox-packages.bats`       (5 tests, 5/5 ok)
    - `devtools-update.bats`       (15 tests, 6/15 ok — fixture adaptado con `devtools.repo.yaml`; 9 fallos F-DRIFT)
    - `git-core.bats`              (1 test, 1/1 ok)
    - `promote.bats`               (60 tests, 55/60 ok — 5 fallos F-DRIFT)
    - `semver.bats`                (20 tests, 20/20 ok)
    - `version-strategy.bats`      (11 tests, 11/11 ok)
    - `test_refactor.sh`           (script bash, no bats; verificación manual: 5/5 funciones detectadas, refactorización ok)
- No migradas en esta iteración:
    - `utils.bats` — F-LEGACY: archivo placeholder vacío (51 bytes, una sola línea de comentario, sin `@test`).
    - `apps-sync.sh` — F-LEGACY: depende de `lib/apps/{apps_config_parser,sync}.sh` ausentes en canónico (`B-IHH-1` lo confirmó). Desbloqueo: decisión humana sobre paridad de `lib/apps/`.
- Estado de ejecución global tras 2 rondas de adaptación: **187 pasados / 14 fallados / 0 skipped** sobre `tests/contracts/` completo (201 tests = 80 baseline canónico + 121 migrados). Ronda 1: copia + ajuste de paths/loads. Ronda 2: adaptación de fixture en `devtools-update.bats:setup` para incluir `devtools.repo.yaml` (cerró 5 F-MIG).
- Cierra `H-AMBOS-2` parcialmente: 9 de las 11 suites del consumer ahora viven en el canónico bajo `tests/contracts/` (8 .bats + 1 .sh). Las 2 restantes (utils, apps-sync) quedan declaradas no-migrables por causa documentada. La cobertura ANTES sólo existía en el vendor legado; AHORA existe en el canónico, por lo que un re-vendoring limpio en Op-C no la borra.
- Sigue bloqueando Op-C:
    - Los 14 fallos F-DRIFT (mensajes de `git-devtools-update.sh` y dependencias de `lib/promote/workflows/to-local/40-build.sh`). No bloquean la migración pero indican deuda real.
    - `H-AMBOS-1` — tag fantasma `v0.1.1-rc.1+build.40` sin existir en canónico. Pendiente de `T-AMBOS-4` fase 2 (Op-C).
    - `H-AMBOS-3` — contrato no validado en `git devtools-update`. Pendiente.
    - `H-AMBOS-8` — `vendorize.sh` placeholder + `git archive` sin manifest. Pendiente.
    - Drift de `lib/apps/*`, `lib/core/{services,vendor,contract,dispatch}.sh` entre legado y canónico.
    - Descalce `releases/prod.md` (`## v0.1.2`) vs `VERSION` (`0.1.0`) y `.promote_tag` (`v0.1.0`).
- **Sin commit, sin push.** Los archivos viven en el working tree para revisión humana mediante zip. Iteración futura decide versionar tal cual o ajustar.
- Evidencia completa en `.audit-evidence/t-ambos-5/`:
  `bats-contracts-pre.txt` (baseline 80/80), `bats-contracts-final.txt`
  (post-migración 187/201), `failures.txt` (clasificación F-DRIFT),
  `migration-plan.txt`, `suites-inventory.txt`,
  `helpers-fixtures-inventory.txt`, `git-state-final.txt`,
  `diff-summary.txt`, `files-changed.txt`, `claude-code-report.txt`.

## 11. Bloque β-acotada — cierre parcial de F-DRIFT (commit pendiente)

- **T-IHH-N2** (mocks/env vars en `tests/contracts/promote.bats`): 5 F-DRIFT-2 cerrados.
  Tests 014/015/016: añadidos `export DEVTOOLS_LOCAL_BACKEND_IMAGE` y `..._FRONTEND_IMAGE` (escape hatch documentado en `40-build.sh:32`).
  Tests 024/027: añadido `export DEVTOOLS_PROMOTE_ARGOCD_APP="pmbok"` (requerido por ADR 0002).
  Diff: 8 líneas insertadas, 0 eliminadas. Sin tocar productivo.
- **T-IHH-N1** (alineación contrato URL upstream): 8 de 9 F-DRIFT-1 cerrados.
  Cambios en `bin/git-devtools-update.sh` (23 líneas netas, ≤30 tope):
  - Helper `__display_remote_url()` para convertir SSH→HTTPS sólo en display.
  - Detección de IS_UPSTREAM_REPO=1 cuando cwd ES un toolrepo aunque el script viva en otra ruta.
  - `UPSTREAM_REPO=$ROOT` en lugar de `$SCRIPT_REPO_ROOT` cuando IS_UPSTREAM_REPO=1 (consistente con cwd-based hint).
  - `resolve_source_for_list` ignora prefijo `local/*` (no es origen remoto válido).
  - Mensajes "Consultando upstream oficial" + "Origen remoto desconocido" (substrings esperados por suites BATS migradas).
  Adaptación de fixture en `tests/contracts/devtools-update.bats` (3 líneas): tests 23/24 ahora copian `lib/core/contract.sh` al toolrepo sandbox (canónico añadió esa dependencia).
- **Test 11 deferido**: F-DRIFT-BEHAVIORAL. El canónico reemplazó curl-tarball por git clone; el test espera el output legacy de curl-download. Restaurar tarball excede tope ≤30 líneas. Decisión documentada en ADR 0004 sección "Limitaciones de alcance"; ADR 0006 propuesta para futuro si se requiere reversión.
- **ADR 0004 — Formato de URL upstream** — estado: Aceptada. README.md de ADRs actualizado, sub-apps placeholder movido a 0005.
- **Suite contractual final**: 200 ok / 1 not ok / 0 skip / 201 plan. Pasados de 187 a 200. Único fallo restante = test 11 deferido.
- **Sin commit ni push**. A la espera de revisión humana vía zip antes de versionar.

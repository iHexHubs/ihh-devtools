# Estado del proyecto — ihh-devtools

> Documento de estado consolidado. Se actualiza al cerrar cada fase.
> Es el punto de entrada para cualquier sesión nueva de trabajo.
>
> Última actualización: 2026-04-25
> Última fase cerrada: Fase 2B (commit `ddf04486`)
> Próxima fase: Fase 2C — subcomando `vendor:check` solo lectura

## 1. Visión del proyecto

### 1.1 Qué es ihh-devtools

`ihh-devtools` es un **toolset CLI universal en bash** que se vendoriza
como subdirectorio `.devtools/` dentro de cada repo consumidor.
Implementa flujos estandarizados (commits, promociones entre ramas,
SemVer, changelog, sync GitOps) sin contaminar la configuración global
de git. La universalidad se materializa por **schema declarativo**: cada
consumidor declara un `contract.yaml` y el toolset opera sin asumir
nombre de proyecto, lenguaje ni dominio. El primer consumidor real es
`erd-ecosystem`; futuros consumidores incluyen la familia iHexHubs y
repos externos (ej. `acme-corp/widget-factory`, ya modelado como ejemplo
en `schema/v1/examples/external-generic.yaml`).

### 1.2 Modelo de operación

```
┌────────────┐  declara   ┌──────────────────┐  valida   ┌────────────┐
│ Consumidor │ ─────────▶ │ contract.yaml    │ ────────▶ │  Toolset   │
│ (cualquier │            │ (schema v1/v1.1) │           │ (vendorizado│
│  repo)     │            └──────────────────┘           │  en .devtools/)
└────────────┘                                           └────────────┘
                                                               │
                                                  registra en  ▼
                                              ┌────────────────────────┐
                                              │ .devtools/lock         │
                                              │ tag + SHA + tree_sha   │
                                              │ (schema v1.1)          │
                                              └────────────────────────┘
```

El toolset opera en modo solo-lectura sobre el contract; el lock lo
escribe el toolset al vendorizar. Drift de referencia (tag → SHA) y de
contenido (tree_sha) es detectable por `vendor_check_drift`.

## 2. Decisiones cerradas

### 2.1 P-AMBOS-5 corregida — toolset universal con schema declarativo

- **Decisión:** `ihh-devtools` es toolset universal con schema
  declarativo, no específico-multi cerrado. La identidad organizacional
  (`identity.family`, `identity.domain`) es metadata, no operativa: el
  core del toolset NO ramifica lógica por familia/dominio.
- **Fecha de cierre:** 2026-04-25 (antes de Fase 1, commit `a1f66277`).
- **Documentado en:** `docs/schema-v1.md` (sección 1), este doc.
- **Resumen:** el contract publicado en `schema/v1/contract.json` es
  estricto (`additionalProperties: false`) y agnóstico de proyecto. Los
  acoplamientos hoy presentes (~40 menciones literales a "pmbok" en, post-Phase1).
  `lib/promote/workflows/*`) son deuda activa que se resuelve en Fase 3,
  no nuevo diseño.

### 2.2 Defaults explícitos con rampa de migración asistida

- **Decisión:** configuración explícita obligatoria post-cutover, sin
  fallbacks legacy permanentes. Rampa: 3-4 sem preparación + 1 sem
  validación dry-run + cutover único + 1 sem soporte.
- **Fecha de cierre:** 2026-04-25 (junto con 2.1).
- **Documentado en:** este doc (sección 6.1).
- **Resumen:** sin híbridos legacy-con-warning. Los repos consumidores
  declaran `contract.yaml` antes del cutover; durante la rampa el
  validador opera en modo dry-run para detectar ausencia o malformación.

### 2.3 P-AMBOS-3 opción C — tag + SHA + verificación de contenido

- **Decisión:** el lock registra simultáneamente tag legible
  (`vendor.ref`), commit SHA (`vendor.sha`) y tree SHA opcional
  (`vendor.tree_sha`). Las tres piezas en un único archivo
  `.devtools/lock` formato YAML schema v1.1, no en archivos sueltos.
- **Fecha de cierre:** 2026-04-25 (antes de Fase 2A, commit `c8362767`).
- **Documentado en:** `docs/adr/0003-vendor-strategy.md` (canónica).
- **Resumen:** drift de referencia y de contenido detectables
  automáticamente; tag fantasma se rechaza en runtime; mutabilidad
  de tags mitigada por SHA registrado. Adopción simple para repos
  externos.

### 2.4 Cierres formales asociados a P-AMBOS-3

- **2.4.1 Schema bumpeado a v1.1** con `vendor.tree_sha` opcional, no
  breaking. `lock_version` y `contract_schema_version` siguen siendo `1`.
  Detalle en `docs/adr/0003-vendor-strategy.md` (decisión 1) y
  `docs/schema-v1.md` (sección 9).
- **2.4.2 Tag de referencia futuro recomendado: `v0.1.0-rc.7`.** Es el
  tag SemVer más reciente ancestor del HEAD, post-filtros
  `--exclude='backup/*' --exclude='archived/*'`. Sujeto a validación de
  contenido en Fase 2C antes de cualquier re-vendorizado real.
- **2.4.3 P-AMBOS-4 (múltiples `.devtools/` en sub-apps) diferida** hasta
  Fase 2D. NO bloquea Fases 2A, 2B, 2C.

## 3. Plan de fases

| Fase | Estado | Commit | Resumen |
|---|---|---|---|
| Fase 0 | cerrada | varios (ver §8) | descubrimiento, gobierno técnico, limpieza ramas, sync `versioning-research.md` |
| Fase 1 | cerrada | `a1f66277` | schema v1 publicado (contract + lock + 5 ejemplos + docs) |
| Fase 2A | cerrada | `c8362767` | schema v1.1 con `tree_sha` opcional + ADR 0003 |
| Fase 2B | cerrada | `ddf04486` | `lib/core/vendor.sh` + suite BATS (18 tests) |
| Fase 2C | pendiente | — | subcomando `vendor:check` solo lectura, primer contacto con erd-ecosystem |
| Fase 2D | bloqueada | — | re-vendorizado real (bloqueada por P-AMBOS-4) |
| Fase 2E | pendiente | — | limpieza de drift y automatización estable |
| Fase 3 | parcial (Phase1 cerrada 2026-04-26) | SEC-2B-Phase1 | Phase1: ~5 menciones retiradas de `devbox.json`. Phase2: ~40 menciones restantes en `lib/promote/workflows/**`. |
| Fase 4 | pendiente | — | erd-ecosystem adopta el `contract.yaml` |
| Fase 5 | bloqueada | — | resolución del tag fantasma con re-vendorizado real (depende de P-AMBOS-3 + P-AMBOS-4) |
| Fase 6 | pendiente | — | docs estables + adaptadores legacy |

> **Nota sesión 2026-04-26:** después de cerrar Fase 2B (`ddf04486`), se aplicaron 3 bloques estructurales no listados en la tabla canónica de fases: `SEC-2A` en erd-ecosystem (commit `7ad85d4`), `SEC-2B-Phase1` (commit `d190e9e6`) y `SEC-2B-Cleanup-Light` (commit `d55f2f26`) en ihh-devtools. Estos bloques NO sustituyen Fase 2C — ejecutan trabajo paralelo (seguridad y limpieza estructural) que estaba implícito en Fase 3 y bloques previos no formalizados. Detalle en §11.

### Detalle de fases pendientes (alto nivel)

- **Fase 2C** — `bin/vendor-check.sh` invoca `vendor_check_drift`,
  `task vendor:check` en `Taskfile.yaml`, suite BATS adicional, primer
  dry-run contra `/webapps/erd-ecosystem` para confirmar el drift ya
  documentado (tag fantasma + SHA no resuelve). Sin escritura.

- **Fase 2D** — `bin/git-devtools-update.sh:343-395` se refactoriza para:
  (a) usar `vendor.sh` para validar antes de mutar, (b) aplicar
  `vendor.manifest.yaml` real (no `git archive` del tag completo),
  (c) añadir `trap` con rollback automático, (d) emitir lock formato
  v1.1 en `.devtools/lock` y deprecar `.devtools.lock` legacy. Bloqueada
  por P-AMBOS-4.

- **Fase 2E** — limpieza de `VENDORED_TAG`/`VENDORED_SHA` sueltos,
  migración de cache `.devtools.bak.*` a TTL configurable, automatización
  CI de `vendor:check` en repos consumidores.

- **Fase 3** — eliminación de las ~40 menciones literales a `pmbok` (Phase2) en
  `lib/promote/workflows/{to-local/*,common.sh,to-dev.sh}` y
  `devbox.json`. Templatizar `DB_PASSWORD` y `SECRET_KEY` con referencias
  a `.env.local`. Decidir naming canónico del dominio Detective
  (`iHexHubs` ↔ `el_rincon` alias confuso en `common.sh`).

- **Fase 4** — `erd-ecosystem` adopta `contract.yaml` siguiendo el
  ejemplo de `schema/v1/examples/erd-ecosystem.yaml`. `lib/promote/`
  deja de tener defaults hardcodeados; `apps_list` y workflows leen
  del contract.

- **Fase 5** — re-vendorizado real de `erd-ecosystem` desde
  `v0.1.0-rc.7` (o tag posterior validado). Resuelve tag fantasma sin
  reescribir cosméticamente el lock. Coordina con purga histórica
  T0.0-bis (flujos paralelos independientes).

- **Fase 6** — docs estables (`docs/migration-2026-04/` se cierra),
  adaptadores legacy para los 7 repos hermanos restantes, suite
  contractual completa en `tests/contracts/` con `.ci/contract-checks.yaml`.

## 4. Decisiones diferidas (pendientes)

### 4.1 P-AMBOS-3 (método de vendorización)

**Estado:** cerrada en opción C (ver §2.3). Listada aquí solo como
referencia histórica para nuevas sesiones que vengan del transcript
y vean menciones a "P-AMBOS-3 abierta".

### 4.2 P-AMBOS-4 (vendorización anidada en sub-apps)

- **Pregunta:** ¿el toolset itera sobre todas las `.devtools/` en
  sub-apps, solo la del meta-repo, o cada consumidor declara cuáles
  vía contract?
- **Cuándo:** Fase 2D la necesita cerrada.
- **Diferida porque:** Fases 2A, 2B, 2C son agnósticas al número de
  ubicaciones. La info para decidir bien aparece durante Fase 2C
  (cuando `vendor_check_drift` se ejecute contra el consumer real
  y veamos el comportamiento sobre los 4 `.devtools/` que viven en
  erd-ecosystem: meta-repo, `apps/pmbok/`, `apps/pmbok/.bak.*`,
  `apps/erd/`).

### 4.3 P-AMBOS-1 (services.yaml vs apps.yaml)

- **Pregunta:** ¿se unifican `ecosystem/services.yaml` (catálogo deploy)
  y `.devtools/config/apps.yaml` (catálogo build) o se mantienen
  disjuntos?
- **Cuándo:** ADR 0002 reservado, sin urgencia operativa.
- **Estado:** confirmado por evidencia (sesión P-AMBOS-3 verificación)
  que la dualidad es **por diseño**, no accidente: cada catálogo tiene
  consumidor distinto (`apps_list` lee `apps.yaml`, GitOps lee
  `services.yaml`). El ADR 0002 puede formalizar la separación o
  consolidar.

### 4.4 Otras decisiones diferidas

- **4.4.1 Naming canónico del dominio Detective.** Alias confuso
  `iHexHubs` ↔ `el_rincon` ↔ `el-rincon-del-detective` en
  `lib/promote/workflows/common.sh:115-140`. Decidir durante Fase 3 al
  templatizar.
- **4.4.2 Adaptadores legacy: en toolset o en consumidor.** Los 7 repos
  hermanos restantes pueden adoptar el contract o quedarse con
  `.devtools.lock` legacy. Decidir durante Fase 6.
- **4.4.3 Política de versionado de schema.** ¿Cuándo bumpamos a v2?
  ¿qué cambios son breaking? Documentar en Fase 6.
- **4.4.4 Strictness inicial del validador en Fase 2C.** ¿Strict (rechaza
  cualquier desviación), lenient (warning + continúa), permissive
  (sólo log)? Decidir antes de implementar `bin/vendor-check.sh`.
- **4.4.5 Caso `git write-tree` en `vendor_compute_tree_sha`.** Hoy solo
  soporta repos con HEAD. Si Fase 2C confronta un `.devtools/` que no es
  repo git, hay que decidir: tratarlo como error o calcular tree
  sintético via `git hash-object`/`git mktree`.

## 5. Deudas acumuladas

### 5.1 Deudas P0 (datos sensibles, seguridad, bloqueantes)

- **Blob `498ddec`** en historia de erd-ecosystem (1219 bytes, 14 commits
  del 2026-01-19, 3 autores distintos identificados por email
  redactado). Path: `.devtools/.git-acprc`. Resuelve solo via `git
  filter-repo` + force-push coordinado (T0.0-bis). Independiente de
  Fase 5 (no mezclar flujos).
- **Secret `DB_PASSWORD` hardcodeado** en `devbox.json` del toolset:
  cerrado Phase1 (`SEC-2B-Phase1`, commit `d190e9e6`, 2026-04-26). El
  bloque `env` se redujo a `DEVBOX_ENV_NAME`; ya no contiene
  `DB_PASSWORD`, `SECRET_KEY` ni vars de stack. Phase2 (refactor de
  `lib/promote/workflows/**`) desbloqueada conceptualmente tras cierre
  de `T-IHH-20` (B-3); pendiente de ejecución como bloque separado.
- **Email gmail/hotmail/yahoo/outlook detectado** en
  `erd-ecosystem/devops/aws/workspaces/variables.tf` (1 archivo,
  detección en HEAD actual). Probablemente legítimo (defaults Terraform
  para `tag.owner`); pendiente verificación caso por caso.
- **Tag fantasma `v0.1.1-rc.1+build.40`** en `.devtools.lock` de
  erd-ecosystem. NO existe en `ihh-devtools` canónico. Solo se resuelve
  via re-vendorizado real (Fase 5), no cosméticamente.

### 5.2 Deudas P1 (operativas y arquitectónicas)

- **~40 hardcodings literales a "pmbok" (Phase2)** en 9 archivos del toolset
  (concentrados en `lib/promote/workflows/to-local/`). Desbloqueada
  conceptualmente: `T-IHH-20` resuelto en B-3 con suite contractual
  `tests/contracts/promote-workflows.bats` (21 tests sobre funciones
  casi puras de `common.sh` y `to-local/{10-utils,50-k8s}.sh`). El
  refactor queda pendiente de ejecución como SEC-2B-Phase2.
- **`vendorize.sh` decorativo** (33 líneas, NO lee `vendor.manifest.yaml`).
  El vendoring real lo hace `git archive --format=tar` en
  `bin/git-devtools-update.sh:356`, que extrae el árbol completo del
  tag (incluye `devbox.json` con secrets, `devbox-app/`, `docs/` y
  los 2 `.tgz` espurios). Se decide destino en Fase 2D-2E.
- **Sin rollback automático** en
  `bin/git-devtools-update.sh:343-395` (función
  `apply_vendored_snapshot_from_repo_tag`). Backup pasivo via `mv`. Si
  `cp -R` falla a la mitad, consumer queda con `.devtools/` parcial
  o vacío. Se aborda en Fase 2D al refactorizar.
- **`contract.sh` es loader, no validador** (343 líneas, 14 funciones
  públicas, 0 con validación de schema). Se extiende cuando llegue
  Fase 2.5 o se decide mantener separado en `vendor.sh`.
- **Sin verificación cruzada `lock` ↔ `VENDORED_TAG/SHA`.** Hoy solo
  `git-devtools-update.sh` lee/escribe esos archivos sueltos; no compara
  con `.devtools.lock`. Drift silencioso posible.
- **Múltiples `.devtools/` en sub-apps de erd-ecosystem** (4 ubicaciones
  detectadas: meta-repo, `apps/pmbok/`, `apps/pmbok/.bak.*`, `apps/erd/`).
  Cubierto por P-AMBOS-4 diferida.

### 5.3 Deudas P2 (legibilidad, mantenibilidad, micro-paranoias)

- **`docs/adr/README.md` no marca ADR 0003 como aceptado** (sigue como
  "reservado"). Una línea de cambio. Se cierra en este commit
  (`docs/project-state.md` + `docs/adr/README.md`).
- **`lint:contamination` en `Taskfile.yaml`** no tiene excepción para
  `lib/core/vendor.sh`, lo que obligó a evitar el literal `.devtools/`
  en el código nuevo. Considerar excepción explícita en próxima fase
  que toque el `Taskfile.yaml` (Fase 3 o Fase 6).
- **Caso `git write-tree`** en `vendor_compute_tree_sha` (repos sin
  commits) no implementado. Decisión técnica para Fase 2C cuando se
  confronte con `.devtools/` del consumer real.
- **`set -euo pipefail` en `lib/core/vendor.sh` es heredable al
  sourcer.** Cuando se diseñe wrapper CLI en Fase 2C, gestionar
  conscientemente con `set +e` post-source.
- **Alias confuso `el_rincon` ↔ `iHexHubs`** en
  `lib/promote/workflows/common.sh` (líneas ~117-128, 137-138, 174-176).
  Se documenta en Fase 3 al decidir naming canónico (4.4.1).
- **2 archivos `.tgz` espurios** en árbol del tag `v0.1.1`
  (`ihh-devtools_pkg1_contract_entrypoints.tgz`, `promote-bug-bundle.tgz`).
  Decisión separada de P-AMBOS-3 (¿cleanup con filter-repo selectivo
  o eliminación en versión próxima?).
- **`git describe` sin filtros devuelve `backup/*`** tags (deuda lateral
  de operación de limpieza 2026-04-25). Patrón seguro:
  `git describe --tags --abbrev=0 --exclude='backup/*' --exclude='archived/*'`.
  Documentado como regla inmutable en §6.3.
- **Tag `v0.1.1` real existe pero NO es ancestor del HEAD actual** de
  `ihh/work`. Apunta a una línea muerta. Por eso §2.4.2 elige
  `v0.1.0-rc.7`, no `v0.1.1`.
- **`tests/devbox-shell-smoke.sh`** sigue siendo placeholder vacío
  (0 bytes, untracked). Decidir destino (eliminar / implementar)
  cuando llegue suite contractual completa en Fase 6.
- **Paths absolutos del clon local en docs:**
  cerrado en `SEC-2B-Cleanup-Light` (commit `d55f2f26`, 2026-04-26). Los
  4 hits en `docs/migration-2026-04/README.md`, `docs/project-state.md`,
  `docs/adr/0001-...md`, `docs/schema-v1.md` se reemplazaron por
  placeholders portables (`<local clone of ihh-devtools>`,
  `${DEVTOOLS_REPO:-/path/to/ihh-devtools}`, etc.).

### 5.4 Deudas P3 (cosmética, baja prioridad)

- `T-IHH-19` — Hacer visible el aviso de tag-clobber en `git-acp.sh`
  (el `2>&1` en línea 218 silencia `[rejected] (would clobber existing
  tag)` aunque el fix de T-IHH-12 ya preserve el tag local). Descrita
  en `versioning-research.md`.
- Esqueleto de directorios reservados en `ihh-devtools/`: `intent/`,
  `spec/`, `implementation/experiments/`, `integration/`,
  `contracts/reviews/`. Vacíos a propósito (metodología spec-anchored).
- `releases/` en `.devtools/` del consumer es symlink colgante
  (`-> ../releases`). Heredado del legacy, solo desaparece al
  re-vendorizar.

## 6. Política operativa

### 6.1 Rampa de migración asistida (P-AMBOS-3)

- **Periodo de preparación 3-4 semanas** antes del cutover. Durante este
  tiempo:
  - Los repos consumidores redactan `contract.yaml` en draft local.
  - El validador (`vendor.sh` + futuro `bin/vendor-check.sh`) corre en
    modo dry-run.
  - `versioning-research.md` y `docs/project-state.md` se mantienen
    sincronizados con el progreso.
- **1 semana de validación dry-run.** El subcomando `vendor:check`
  reporta drift sin mutar nada.
- **Cutover único.** Re-vendorizado real, lock v1.1, eliminación del
  legacy `.devtools.lock` formato bash. Sin períodos largos de
  coexistencia bilateral.
- **1 semana de soporte post-cutover.** Atender errores; el toolset
  es reversible mientras `iHexHubs/devtools` legacy esté archivado en
  GitHub (no eliminado).
- **Sin fallbacks legacy permanentes.** El código no introduce paths
  `if format == "legacy"`. Migración explícita o nada.

### 6.2 Política entre fases

- **Pausa de revisión recomendada** 2-3 días entre fases mayores
  (especialmente Fases 2C → 2D, 2D → 3, 3 → 4).
- **Cada fase tiene su propio prompt** para Claude Code. No se mezclan
  alcances en una misma sesión.
- **Working tree debe estar limpio** antes de iniciar cada fase. Si la
  sesión anterior dejó cambios sin commitear, cerrarlos primero.
- **Cada commit cierra una fase** y deja referencia (commit SHA) en
  este doc para próxima sesión.
- **Pre-flight check** al inicio de cada fase: rama correcta, working
  tree limpio, HEAD esperado, herramientas disponibles.

### 6.3 Reglas inmutables del proyecto

- **NO crear el tag fantasma `v0.1.1-rc.1+build.40`** en ningún lado.
  Sería propagar el bug a la fuente.
- **NO mover el tag `v0.1.1`** a HEAD con `git tag -f`. Sería reescribir
  historia compartida.
- **NO usar `git describe --tags` sin filtros excluyentes.** Patrón
  seguro: `git describe --tags --abbrev=0 --exclude='backup/*'
  --exclude='archived/*'`.
- **NO reescribir `.devtools.lock` cosméticamente.** Solo via
  re-vendorizado real (Fase 5).
- **NO mezclar la migración del lock con purga del blob `498ddec`.**
  Son flujos paralelos independientes con coordinaciones distintas.
- **NO eliminar hardcodings PMBOK fuera de Fase 3** (mantener cohesión).
- **NO modificar erd-ecosystem fuera de fases que lo declaren
  explícitamente** (Fases 4, 5, y micro-tocaciones del consumer en
  2C-2D para dry-run).
- **NO crear ADR nuevo sin numeración correlativa** (siguiente
  disponible: 0004 reservado para P-AMBOS-4, 0005 libre).
- **NO commitear con `task ci` en rojo.**

## 7. Repos en el alcance

| Repo | Rol | Rama de trabajo | Última HEAD conocida |
|---|---|---|---|
| `<local clone of ihh-devtools>` | toolset canónico (productor) | `ihh/work` | `ddf04486` (Fase 2B) |
| `/webapps/erd-ecosystem` | primer consumidor real | `erd/work` | `ac975ba` (governance sync) |

Solo estos dos repos están en el alcance del proyecto actual. Los 7
repos hermanos restantes (mencionados en
`docs/migration-2026-04/legacy-devtools-references.txt`) entran en
Fase 6 cuando se diseñen adaptadores. **NO se inspecciona ni se hace
referencia a ningún otro repo del sistema.**

## 8. Cronología de commits clave

Solo commits estructurales del proyecto, no commits menores. Todos del
2026-04-25 (huso horario `-0500`).

| SHA | Hora | Repo | Fase | Resumen |
|---|---|---|---|---|
| `18ba7f6` | 08:14 | erd-ecosystem | Fase 0 | publicación gobierno técnico (README, versioning-research.md) |
| `a346790d` | 08:17 | ihh-devtools | Fase 0 | publicación gobierno técnico (paralelo) |
| `5b0252a5` | 09:50 | ihh-devtools | T-IHH-14/17 | `lint:contamination` amplía scope a `bin/`+`lib/` con filtro multi-regla |
| `6515740b` | 10:04 | ihh-devtools | T-IHH-12 | `git-acp.sh:218` sin `--force` (preserva tags locales tras rebase) |
| `a0a6cf74` | 11:32 | ihh-devtools | barrido | `versioning-research.md` sincronizado con SHAs cerrados |
| `ac975ba` | 11:32 | erd-ecosystem | barrido | `versioning-research.md` registra T-ERD-15 + H-ERD-15 |
| `a1f66277` | 12:38 | ihh-devtools | **Fase 1** | schema v1 publicado (`contract.json` + `lock.json` + 5 ejemplos + docs) |
| `c8362767` | 14:45 | ihh-devtools | **Fase 2A** | schema v1.1 con `tree_sha` opcional + ADR 0003 |
| `ddf04486` | 15:28 | ihh-devtools | **Fase 2B** | `lib/core/vendor.sh` (5 funciones públicas) + suite BATS (18 tests) |
| `9589027a` | 2026-04-26 ~10:00 | ihh-devtools | bloque P0 inicial | `git-promote.sh:259` valida `DEVTOOLS_PROMOTE_FROM_BRANCH` antes del cleanup. (Subject menciona "H-SCR-2" por error de etiquetado; fix real cubre `H-SCR-1` según `versioning-research.md`.) |
| `8645318` | 2026-04-26 ~10:30 | erd-ecosystem | bloque P0 inicial | `bin/devtools` valida target ejecutable antes del `exec` del wrapper (cubre `H-SCR-2`; subject del commit menciona `H-SCR-1` por mismo error de etiquetado). |
| `369e8c9` | 2026-04-26 | erd-ecosystem | mini-bloque higiene | `SEC-16` `letsencrypt/acme.json` destrackeado + entrada en `.gitignore`. |
| `3fa80e12` | 2026-04-26 | ihh-devtools | mini-bloque higiene | `SEC-23` `.env` raíz destrackeado + entrada en `.gitignore`. |
| `0e8151f` | 2026-04-26 | erd-ecosystem | auditoría inicial | cierre auditoría técnica paralela: 15 fixes documentales + scripts (`changelog-check.sh`, `new-webapp.sh`, `onboarding.md`, `fase-0-...md`, `versionado.md`, `arquitectura.md`, `.gitignore`, `.gitmodules`, governance docs, `AUDITORIA_TECNICA_PARALELA.md`). |
| `7ad85d4` | 2026-04-26 | erd-ecosystem | **SEC-2A** | refactor terraform `main-stack` (`secrets.tf` con `random_password`, `rds.tf` con `var.db_username`/`var.db_name`, `variables.tf` nuevas con validation; `devops/prod/compose.yml` eliminado). Cierra `SEC-09/10/13/18`. |
| `d190e9e6` | 2026-04-26 | ihh-devtools | **SEC-2B-Phase1** | toolset genérico: `devbox.json` `env` retirado salvo `DEVBOX_ENV_NAME`, `scripts.backend/frontend` eliminados, `init_hook` ajustado; README §5.1 migration note; `versioning-research.md` cierra parcial `H-AMBOS-9`/`P-AMBOS-5`/`T-AMBOS-3`. |
| `d55f2f26` | 2026-04-26 | ihh-devtools | **SEC-2B-Cleanup-Light** | guard en `git-feature.sh:83`, `eval`→`bash -c` en `git-pipeline.sh:27`, README L262 coherente con `P-AMBOS-5` cerrado, 4 paths absolutos del clon retirados de docs, conteo "44" → "~40 (Phase2)". |

Antes del 2026-04-25, el repo tenía gobierno técnico parcial sin
estado consolidado. Esta cronología empieza desde el primer commit
estructural del plan de fases actual.

## 9. Punto de entrada para sesión nueva

### 9.1 Qué leer primero

1. **Este documento** (`docs/project-state.md`).
2. `docs/adr/0001-devtools-consolidation.md` (consolidación toolset).
3. `docs/adr/0003-vendor-strategy.md` (estrategia vendorización).
4. `docs/schema-v1.md` (schema v1 + v1.1, contract + lock + ejemplos).
5. `versioning-research.md` (detalle de hallazgos T/H/J/P/B con
   evidencia).

### 9.2 Qué NO necesita reconstruir

- **El análisis de fondo del proyecto** (este doc lo cubre en §1).
- **Las decisiones P-AMBOS-3 y P-AMBOS-5** (cerradas, no se reabren —
  ver §2).
- **El plan por fases** (§3).
- **La política de rampa de migración** (§6.1).
- **Las reglas inmutables** (§6.3).
- **La cronología hasta `ddf04486`** (§8).

### 9.3 Próximo paso operativo

Tres opciones reales (espejo de HANDOFF §9). **Elegir una; no avanzar en paralelo.**

**Opción A — `T-IHH-20` (suite de regresión específica para `lib/promote/workflows/**`) — APLICADA EN B-3.** `tests/contracts/promote-workflows.bats` (21 tests) cubre las funciones casi puras de `common.sh` y `to-local/{10-utils,50-k8s}.sh`. SEC-2B-Phase2 desbloqueada conceptualmente, pendiente de ejecución.

**Opción B — `H-IHH-14` (refactor `git-acp.sh:187`) — APLICADA EN B-2.** Modos de staging configurables (`--staged-only`, `--interactive`, `--yes`) + variable `DEVTOOLS_ACP_DEFAULT_MODE`; default cambia a `confirm`.

**Opción C — pausar ihh-devtools, avanzar en erd-ecosystem (`SEC-2C`).** Atacar k8s manifests (`devops/k8s/components/postgres-db/secret.yaml`, overlays con `django-insecure-*`, ArgoCD apps con `password: secretpassword`). Esfuerzo mediano-grande; requiere decisión arquitectónica (ExternalSecret vs SealedSecret) + rotación coordinada.

**Fase 2C (validador integrado) sigue diferida.** Sin urgencia operativa; requiere decisiones humanas previas (strictness, lectura de lock legacy paralela, caso `git write-tree` sin HEAD). Decisiones bloqueadas en §4.4.4 + §5.3 + §9.3 anterior.

NO migrar erd-ecosystem todavía. NO tocar tag fantasma aislado. NO tocar `.devtools.lock` cosméticamente.

## 10. Mantenimiento de este documento

Este documento se actualiza al cerrar cada fase. Reglas:

- **§3 Plan de fases:** marcar fase como cerrada, agregar SHA del
  commit en columna correspondiente.
- **§5 Deudas:** agregar/quitar entradas según se cierren o se
  descubran. Mantener orden P0 → P3.
- **§8 Cronología:** agregar commit estructural con hora exacta.
- **NO reescribir secciones cerradas** (decisiones §2, política
  operativa §6). Si una decisión se supersede, escribir ADR nueva y
  agregar nota en §2 con referencia a la ADR superseder.
- **NO duplicar contenido** que vive en ADRs o `docs/schema-v1.md`.
  Citar por referencia.
- **Actualizar el header**: fecha de última actualización, última fase
  cerrada y próxima fase, en cada update.

## 11. Estado de bloques 2026-04-26

Esta sección consolida el inventario de hallazgos al cierre de la sesión 2026-04-26 tras los bloques `SEC-2A`, `SEC-2B-Phase1` y `SEC-2B-Cleanup-Light`. Es snapshot, no canon — la fuente autoritativa sigue siendo §3 (Plan de fases) + `versioning-research.md`.

### 11.1 Cerrado (commit ya pusheado)

- `H-SCR-1`/`H-SCR-2` — guards en `bin/git-promote.sh:259` y `bin/devtools` wrapper. Commits `9589027a` (ihh) y `8645318` (erd). IDs intercambiados en subjects.
- `SEC-09`, `SEC-10`, `SEC-13`, `SEC-18` — refactor terraform main-stack. Commit `7ad85d4` (erd).
- `SEC-16` — `letsencrypt/acme.json` destrackeado + `.gitignore`. Commit `369e8c9` (erd).
- `SEC-23` — `.env` raíz destrackeado + `.gitignore`. Commit `3fa80e12` (ihh).
- `SEC-19` Phase1 — bloque `env` del `devbox.json` raíz purgado. Commit `d190e9e6` (ihh).
- `H-AMBOS-9` parcial, `P-AMBOS-5` parcial, `T-AMBOS-3` Phase1, `B-AMBOS-3` retirado. Commit `d190e9e6` (ihh).
- `N-SCR-1` (`git-feature.sh`), `N-SCR-2` (`git-pipeline.sh` `eval`→`bash -c`), 4 paths absolutos retirados de docs, conteo "44 menciones" → "~40 (Phase2)", coherencia README L262. Commit `d55f2f26` (ihh).
- 15 fixes documentales de auditoría inicial (`onboarding.md`, `arquitectura.md`, `versionado.md`, `.gitignore`, `.gitmodules`, etc.). Commit `0e8151f` (erd).

### 11.2 Cumplido por estado preexistente (sin commit)

- `SEC-17` — `.env` raíz de erd-ecosystem nunca estuvo en index; `.gitignore:48` ya lo cubría desde antes. No requirió acción.

### 11.3 Acción local del operador (sin commit)

- Investigación `certs/dev.key` en historia git de erd-ecosystem clasificada P1 `real_sin_uso_evidente` (RSA 2048 mkcert local, SAN sólo loopback, sin referencias activas). Rotación local mkcert ejecutada en máquina del operador.

### 11.4 En curso / bloqueado

- `H-AMBOS-9` Phase2 — ~40 menciones literales `pmbok` en `lib/promote/workflows/**`. Desbloqueado conceptualmente tras cierre de `T-IHH-20` (B-3); pendiente de ejecución como bloque separado.
- `H-IHH-14` cerrado en B-2 (refactor opción F en `git-acp.sh` con flags `--staged-only`/`--interactive`/`--yes` + variable `DEVTOOLS_ACP_DEFAULT_MODE`).
- `T-IHH-16` cerrado en `ddf04486` (Fase 2B). Suite `tests/contracts/vendor.bats` con 18 tests. `.ci/contract-checks.yaml` queda como sub-deuda P2 separada, no bloqueante.
- `T-IHH-20` cerrado en B-3. Suite `tests/contracts/promote-workflows.bats` con 21 tests cubriendo funciones casi puras de `common.sh` y `to-local/{10-utils,50-k8s}.sh`.

### 11.5 Pendiente P0 (sin commit, sin bloqueo de tests)

- `SEC-2C` (futuro) — k8s manifests con `password: secretpassword` (5 envs ArgoCD + bootstrap legacy + componente postgres-db) y overlays con `django-insecure-*`. Requiere decisión arquitectónica humana (ExternalSecret/SealedSecret/k8s manual) + rotación coordinada postgres real.
- `T0.0-bis` — purga histórica de blob `498ddec` en erd-ecosystem (`.devtools/.git-acprc` con perfiles personales de 4 contribuidores). Requiere `git filter-repo` + `git push --force-with-lease` coordinado con todos los contribuidores activos.
- `T-AMBOS-4` — decidir tag base real para reescribir `.devtools.lock` del consumer (hoy declara `v0.1.1-rc.1+build.40` que NO existe en el productor canónico).

### 11.6 Pendiente P1 (sin urgencia inmediata)

- `H-IHH-14` (`git add .` sin filtros).
- `T-IHH-5` — rollback automático en `git-devtools-update.sh:343-395`.
- `T-IHH-3` — validación del contrato del consumer en `git-devtools-update`.
- `T-AMBOS-5` — migrar 11 BATS suites del consumer a `tests/contracts/` antes de re-vendorizar.
- `T-AMBOS-6` — estandarizar URL canónica en docs/scripts restantes.

### 11.7 Pospuesto P2 (no se aborda esta etapa)

- `H-IHH-5`, `H-IHH-6`, `H-IHH-7`, `H-IHH-8`, `H-IHH-9`, `H-IHH-10`.
- `H-AMBOS-6` (`cliff.toml` duplicado), `H-AMBOS-7` (convenciones IA divergen).
- Reescritura de `docs/release-flow.md`, `docs/contrato-tags.md`, runbooks.

### 11.8 Bloqueado por decisión humana

- `P-AMBOS-1` (services.yaml vs apps.yaml) — ADR 0002 sin escribir.
- `P-AMBOS-3` (método de vendorización) — bloquea `T-IHH-4` (`vendorize.sh` real).
- `P-AMBOS-4` (sub-apps `.devtools/`) — diferida hasta Fase 2D.
- `P-ERD-1` (conservar/eliminar `new-webapp.sh`) — decisión humana en erd-ecosystem.
- `P-ERD-2` (rama `main` vs `prod`) — contradicción documental abierta en erd-ecosystem.

### 11.9 Bloqueado por falta de tests

- (vacío) `T-IHH-20` resuelto en B-3; `H-AMBOS-9` Phase2 desbloqueado conceptualmente, pendiente de ejecución.

### 11.10 Riesgos abiertos relevantes

- **Tag fantasma `v0.1.1-rc.1+build.40`** declarado en `.devtools.lock` del consumer pero NO existe en productor. Cualquier `git devtools-update` ejecutado contra el consumer fracasa hasta resolver `T-AMBOS-4`.
- **Vendoring ignora `vendor.manifest.yaml`** (`H-AMBOS-8`). Cualquier re-vendorización propaga el árbol completo del tag (incluyendo `devbox-app/`, `docs/`, `devbox.json`, archivos `.tgz` espurios) al consumer.
- **Sin rollback automático en `git-devtools-update.sh`** (`T-IHH-5`). Falla parcial deja `.devtools/` consumer corrupto.
- **K8s manifests con secrets triviales en path `/prod/`** (commit `7ad85d4` retiró Terraform; los manifests siguen abiertos en `SEC-2C` futuro).

### 11.11 Próximos bloques recomendados (orden defendible)

1. **SEC-2B-Phase2** (en ihh-devtools) — refactor de las ~40 menciones literales `pmbok` en `lib/promote/workflows/**`. Desbloqueado conceptualmente tras cierre de `T-IHH-20` (B-3) y `H-IHH-14` (B-2). Riesgo medio; suite contractual (`promote-workflows.bats`) cubre funciones casi puras como red de seguridad.
2. **`SEC-2C`** (en erd-ecosystem) — alto impacto en seguridad real; requiere decisión arquitectónica primero.
3. **`T-AMBOS-4`** + **`T-ERD-3`** + **`T0.0-bis`** — flujo coordinado de re-vendorización + purga histórica. Requiere ventana de mantenimiento + comunicación a contribuidores.
4. **Fase 2C** (validador integrado en CLI) — diferible mientras los pasos 1-3 no estén cerrados.

NO se recomienda avanzar en paralelo en más de un frente sin ADR explícito.

---

*Este documento es punto de entrada. Si esta sesión no es la última y
nos vemos en otra: empezar leyendo §1, §3 y §9.3.*

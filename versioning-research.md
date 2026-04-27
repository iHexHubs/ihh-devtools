# Versioning Research — `ihh-devtools`

> Documento de gobierno técnico. Se actualiza cuando se descubren nuevos hallazgos,
> se toman decisiones arquitectónicas, se cierran tareas o se desbloquean dependencias.
>
> Convención de etiquetas: T (Tarea), H (Hallazgo), J (Decisión), P (Pregunta), B (Bloqueo).
> Sufijos: `-IHH-` (afecta a este repo), `-ERD-` (afecta a `erd-ecosystem`), `-AMBOS-` (afecta a ambos).

---

## 1. Propósito del documento

Este archivo registra:

- Criterios de versionado del toolset (SemVer estricto desde ADR 0001 J-05).
- Decisiones arquitectónicas tomadas (referenciadas a las ADRs).
- Riesgos de compatibilidad con repos consumidores (8 identificados).
- Contratos publicados (`devtools.repo.yaml`, `vendor.manifest.yaml`).
- Tareas de estabilización pendientes.
- Hallazgos técnicos relacionados con vendorizado, releases, integración con consumidores.
- Referencias cruzadas con `erd-ecosystem`.

---

## 2. Estado actual del repo

| Aspecto | Valor | Verificación |
|---|---|---|
| Tipo | Toolset CLI (Bash) | Verificado en archivo (`README.md`, ADR 0001) |
| Lenguaje | Bash | Verificado por inspección |
| Cantidad de scripts | 17 entrypoints en `bin/`, ~32 archivos en `lib/` | Verificado por listado |
| Gestor de entorno | Devbox (Nix) | Verificado en `devbox.json` |
| Orquestador | go-task (`Taskfile.yaml`) | Verificado |
| Versionado | SemVer estricto `vX.Y.Z[-rc.N][+build.N]` | Verificado en ADR 0001 J-05 |
| `VERSION` actual | `0.1.0` | Verificado |
| `.promote_tag` actual | `v0.1.0` (env=prod) | Verificado |
| Rama según reporte previo | `main-b80c3c4` (75 commits adelante de `main`) | Verificado por reporte previo |
| Tests contractuales (`tests/contracts/`) | Implementados parcialmente (Fase 2B, `tests/contracts/vendor.bats` con 18 tests, commit `ddf04486`) | Verificado por inspección |

**Documentación encontrada:**

- `README.md` (actualizado por auditoría 2026-04-25; ahora declara explícitamente lo que aún no existe).
- `AGENTS.md` (reglas para agentes IA; alineado con el estado real).
- `docs/adr/0001-devtools-consolidation.md` (canónica de la consolidación del toolset).
- `docs/migration-2026-04/README.md` (plan de migración).
- `docs/migration-2026-04/legacy-devtools-references.txt` (247 hits en 8 repos).
- `devtools.repo.yaml` (contrato declarado, schema_version 1).
- `vendor.manifest.yaml` (manifest de vendoring **no aplicado** — ver `H-AMBOS-8`).

**Lo que aún NO está verificado:**

- Estado real de la rama `main-b80c3c4` y su desfase con `main`.
- Coherencia entre `vendor.manifest.yaml` y el contenido real de `git archive` por tag.
- Existencia del tag `v0.1.1-rc.1+build.40` declarado en el lock de `erd-ecosystem`.
- Comportamiento end-to-end de `git devtools-update` desde un consumidor real.

---

## 3. Relación con `erd-ecosystem`

`ihh-devtools` es **productor** y `erd-ecosystem` es uno de los 8 consumidores. La relación se materializa en:

- El consumidor vendoriza `.devtools/` desde un tag de este repo.
- El consumidor declara la versión en su `.devtools.lock`.
- El script `git devtools-update` (en `bin/`) sincroniza la copia.
- El `devbox.json` del toolset es el que el consumidor usa como entorno (vía symlink en `new-webapp.sh:36` o equivalente).

**Inventario de consumidores:** 8 repos (ver `docs/migration-2026-04/README.md`):

1. `erd-ecosystem` (`iHexHubs/ihh-ecosystem`).
2. `agents-control-plane` (`reydem/openai-agents`).
3. `pmbok` (`sixdriven/pmbok`).
4. `rust-lang-book` (`reydem/rust-lang-book`).
5. `rust-w3schools` (`reydem/rust-w3schools`).
6. `sixdriven` (`reydem/sixdriven`).
7. `sixdriven-web` (`reydem/sixdriven-web`).
8. `tvw-ecosystem` (`reydem/tvw-ecosystem`).

Inventario completo de referencias legadas: `docs/migration-2026-04/legacy-devtools-references.txt` (247 hits).

---

## 4. Decisiones arquitectónicas

### J-IHH-1 — Repo legado `iHexHubs/devtools` queda archivado

- estado: resuelto (ADR 0001 J-02, ejecutado 2026-04-24)
- contexto: existían dos toolsets en paralelo. El legado ya no recibe cambios.
- decisión: el repo legado queda en modo solo-lectura en GitHub. Eliminación definitiva diferida hasta que los 8 repos consumidores migren.
- justificación: archivar permite revertir si algo se rompe durante la migración.
- consecuencias: período de transición con `.devtools/` vendorizados desde el legado siguen funcionales hasta que el operador los actualice.
- repos afectados: ambos.
- tareas relacionadas: `T-AMBOS-1` (migrar 7 repos hermanos), `T-AMBOS-11` (eliminación definitiva).

### J-IHH-2 — SemVer estricto para tags nuevos

- estado: resuelto (ADR 0001 J-05)
- contexto: el repo tenía tags estilo `ihh-devtools-v0.1.0.rc.1-build.1-rev.1`, fuera del estándar SemVer.
- decisión: tags nuevos siguen `v<major>.<minor>.<patch>[-rc.<n>][+build.<n>]`. El esquema histórico queda deprecado.
- justificación: alineación con herramientas estándar que asumen SemVer.
- consecuencias: tags históricos no se renombran (rompería referencias). Scripts que parseen tags deben aceptar ambos formatos.
- repos afectados: ambos.
- tareas relacionadas: `T-IHH-1`.

### J-AMBOS-1 — `iHexHubs/ihh-devtools` es el toolset canónico

- estado: resuelto (ADR 0001 J-01, aceptada 2026-04-24)
- contexto: replicada en `erd-ecosystem/versioning-research.md`. Aquí se referencia para trazabilidad.
- decisión: este repo es la única fuente de verdad para la vendorización.
- repos afectados: ambos.
- tareas relacionadas: ver `T-IHH-2`.

### J-AMBOS-2 — Vendorización debe ser output exacto del manifest

- estado: abierto
- contexto: ADR 0001 J-04 declara que `.devtools/` en consumidores debe ser el output exacto del contrato declarado en `vendor.manifest.yaml`.
- decisión: no se toleran enlaces rotos ni directorios fantasma.
- justificación: integridad del contrato.
- consecuencias: el método concreto (submódulo, copia determinista, ambos) queda diferido a ADR 0003.
- nota: actualmente el contrato NO se cumple (ver `H-AMBOS-8`). Inferencia pendiente de validación: la decisión J-04 está aceptada, pero la implementación no la respeta.
- repos afectados: ambos.
- tareas relacionadas: `T-IHH-4`, `T-AMBOS-10`, `P-AMBOS-3`.

### J-AMBOS-3 — URL canónica = SSH con host alias

- estado: resuelto (ADR 0001 J-06)
- contexto: replicada en `erd-ecosystem/versioning-research.md`.
- decisión: `git@github.com-reydem:iHexHubs/ihh-devtools.git`.
- repos afectados: ambos.

### J-AMBOS-4 — Migración progresiva, no urgente

- estado: resuelto (ADR 0001 J-07)
- contexto: replicada en `erd-ecosystem/versioning-research.md`.
- repos afectados: ambos.

---

## 5. Hallazgos técnicos

### H-IHH-1 — Rama `main-b80c3c4` desfasada de `main`

- estado: abierto
- severidad: alta
- evidencia: el reporte de auditoría previa indica que esta rama tiene 75 commits adelante de `main`, y que `tests/devbox-shell-smoke.sh` está untracked.
- archivo: estado del repo (no inspeccionable desde el zip sin `.git`).
- línea: no aplicable.
- impacto: cualquier `git clone` aterriza en `main` (estado obsoleto). Tags publicados que apunten a `main-b80c3c4` quedan inválidos si la rama se renombra.
- tarea relacionada: `T-IHH-2`.
- repos afectados: `ihh-devtools`.

### H-IHH-2 — Confusión sobre rol de `tests/`

- estado: abierto
- severidad: alta
- evidencia: `AGENTS.md` declara que `tests/contracts/` y `.ci/contract-checks.yaml` son "objetivos pendientes" (corrección aplicada por auditoría previa). El reporte previo menciona un `tests/devbox-shell-smoke.sh` untracked. No hay decisión sobre si ese archivo se trackea como parte del esqueleto futuro o se mueve.
- archivo: `tests/` (estado no en zip).
- línea: no aplicable.
- impacto: documentación y código divergen sobre qué representa `tests/`.
- tarea relacionada: `T-IHH-2`.
- repos afectados: `ihh-devtools`.

### H-IHH-3 — `git-devtools-update.sh` sin rollback automático

- estado: abierto
- severidad: alta
- evidencia: `bin/git-devtools-update.sh:367-378`. El flujo es:
  ```
  mv "${ROOT}/${TARGET_PATH}" "$backup_path"
  mkdir -p "${ROOT}/${TARGET_PATH}"
  cp -R "${src_dir}/." "${ROOT}/${TARGET_PATH}/"
  ```
  Si `cp -R` falla tras el `mv`, el destino queda vacío. El backup queda intacto pero el script no revierte.
- archivo: `bin/git-devtools-update.sh`.
- línea: 367-378.
- impacto: una falla de disco o permisos durante la actualización deja al consumidor sin `.devtools/`. El usuario tiene que descubrir manualmente el `.bak.<timestamp>` y revertir.
- tarea relacionada: `T-IHH-5`.
- repos afectados: `ihh-devtools` (impacta a los 8 consumidores).

### H-IHH-4 — README no documenta todos los entrypoints

- estado: resuelto (auditoría 2026-04-26)
- severidad: media
- evidencia: README sección 5 reescrita en tres tablas: "Públicos (uso diario)", "Auxiliares y wrappers", "De infraestructura (no se exponen como `git ...`)". Cada entrada lista comando, entrypoint y descripción. Cubre `git acp/promote/feature/gp/rp/sweep/devtools-update` (públicos), `git ci/pipeline/pr/release-draft/lim/sw` (auxiliares), y `bin/devtools`, `bin/setup-wizard.sh`, `bin/git-devtools-update.sh` (infraestructura).
- archivo: `README.md`.
- línea: 36-66 (post-fix).
- impacto: descubribilidad completa.
- tarea relacionada: `T-IHH-6`.
- repos afectados: `ihh-devtools`.

### H-IHH-5 — Patrón inconsistente en `lib/promote/workflows/`

- estado: abierto
- severidad: media
- evidencia: `lib/promote/workflows/to-local/` está dividido en 8 sub-archivos numerados (`00-env.sh` a `90-main.sh`). Los demás workflows (`to-dev.sh`, `to-staging.sh`, `to-prod.sh`, `dev-update.sh`, `hotfix.sh`) son monolíticos.
- archivo: `lib/promote/workflows/`.
- línea: no aplicable.
- impacto: dos patrones distintos para problemas similares. Mantenibilidad y descubribilidad inconsistentes.
- tarea relacionada: `T-IHH-7`.
- repos afectados: `ihh-devtools`.

### H-IHH-6 — Solapamiento entre `lib/core/git*.sh` y `lib/git*.sh`

- estado: abierto
- severidad: media
- evidencia: `lib/core/git.sh`, `lib/core/git-ops.sh`, `lib/git-context.sh`, `lib/git-flow.sh`, `lib/git-profile.sh`. Sin documentación de dominio de cada uno.
- archivo: varios.
- línea: no aplicable.
- impacto: posible duplicación de helpers. Decisión de "dónde añadir lógica nueva" es ambigua.
- tarea relacionada: `T-IHH-8`.
- repos afectados: `ihh-devtools`.

### H-IHH-7 — `vendor.manifest.yaml` sin schema, sin validación

- estado: abierto
- severidad: baja
- evidencia: archivo de 4 líneas con lista plana de globs. Sin `schema_version`. Ningún script lo lee (ver también `H-AMBOS-8`).
- archivo: `vendor.manifest.yaml`.
- línea: 1-7.
- impacto: cambio en el manifest no produce ningún efecto observable.
- tarea relacionada: `T-IHH-4`, `T-AMBOS-10`.
- repos afectados: ambos.

### H-IHH-8 — Wrappers cortos en `bin/git-lim.sh` y `bin/git-sw.sh`

- estado: abierto
- severidad: baja
- evidencia: archivos de 176 y 187 bytes respectivamente. Probables wrappers/aliases.
- archivo: `bin/git-lim.sh`, `bin/git-sw.sh`.
- línea: archivos completos.
- impacto: si son redirecciones triviales, considerar consolidar o documentar el patrón.
- tarea relacionada: `T-IHH-9`.
- repos afectados: `ihh-devtools`.

### H-IHH-9 — `devtools.repo.yaml` con `registries: null` sin documentación de comportamiento

- estado: abierto
- severidad: baja
- evidencia: el archivo declara `registries.build: null` y `registries.deploy: null` con un comentario sobre "defaults permitidos". El comportamiento de "null = usa default" no está documentado en código.
- archivo: `devtools.repo.yaml`.
- línea: 4-7.
- impacto: ambigüedad para implementadores nuevos.
- tarea relacionada: `T-IHH-10`.
- repos afectados: `ihh-devtools`.

### H-IHH-10 — `bin/.codex/` directorio de propósito desconocido

- estado: abierto
- severidad: baja
- evidencia: directorio listado en `bin/`. Probable artefacto de la herramienta Codex.
- archivo: `bin/.codex/`.
- línea: no aplicable.
- impacto: si es residuo, ocupa espacio y confunde. Si es funcional, no está documentado.
- tarea relacionada: `T-IHH-11`.
- repos afectados: `ihh-devtools`.

### H-IHH-11 — `git-acp.sh:218` hace `git fetch --tags --force` tras rebase

- estado: resuelto (commit 6515740b)
- severidad: media
- evidencia: tras un push rechazado, el script intenta `pull --rebase` y, si tiene éxito, ejecuta `git fetch --tags --force` antes del retry de push.
- archivo: `bin/git-acp.sh`.
- línea: 218.
- impacto: sobrescribe tags locales del usuario sin advertencia. Comportamiento sorprendente para un comando básico de "add+commit+push".
- tarea relacionada: `T-IHH-12`.
- repos afectados: `ihh-devtools` (impacta a todos los usuarios del comando `git acp`).

### H-IHH-12 — `git-promote.sh:272` hace `checkout` con variable potencialmente vacía

- estado: resuelto (auditoría 2026-04-26)
- severidad: baja
- evidencia: el bloque de cleanup ahora valida `DEVTOOLS_PROMOTE_FROM_BRANCH` antes de invocar checkout. Si está vacío, emite aviso `↩️ Cleanup: rama original desconocida ...; no se restaura.` y sugiere `git status -sb`. Si tiene valor, restaura como antes.
- archivo: `bin/git-promote.sh`.
- línea: 265-282 (post-fix).
- impacto: el operador ya no queda en rama inesperada sin saberlo. Sintaxis validada con `bash -n`.
- tarea relacionada: `T-IHH-13`.
- repos afectados: `ihh-devtools`.

### H-IHH-13 — `lint:contamination` no escanea `bin/` ni `lib/`

- estado: resuelto (commit 5b0252a5)
- severidad: alta
- evidencia: `Taskfile.yaml` define el lint con `TARGETS=(README.md CHANGELOG.md scripts devtools.repo.yaml)`. NO incluye `bin` ni `lib`.
- archivo: `Taskfile.yaml`.
- línea: 17-30.
- impacto: una ruta hardcodeada (p. ej. `/webapps/...`) en código bash NO se detecta. La inspección manual confirma que actualmente el código está limpio, pero por suerte, no por contrato.
- tarea relacionada: `T-IHH-14`.
- repos afectados: ambos (impacta a calidad del código que se vendoriza).

### H-IHH-14 — `git-acp.sh:187` hace `git add .` sin filtros

- estado: resuelto (B-2)
- severidad: alta
- evidencia original: línea 187 ejecutaba `git add .` sin preview, sin `--staged-only`, sin `git add -p`.
- evidencia post-fix: `git add .` ya no aparece como statement directo en `bin/git-acp.sh`. La estrategia de staging vive en `lib/core/acp-mode.sh` (helper `acp_run_add_strategy`) y se selecciona via flag CLI o variable `DEVTOOLS_ACP_DEFAULT_MODE`. El default es `confirm` (muestra `git status --short` y pide `[Y/n]` antes de stagear).
- archivo: `bin/git-acp.sh` + `lib/core/acp-mode.sh` + `lib/core/config.sh`.
- impacto residual: ninguno con default `confirm`. El comportamiento legacy sigue disponible explícitamente con `--yes` / `--no-confirm` o `DEVTOOLS_ACP_DEFAULT_MODE=yes`.
- tarea relacionada: `T-IHH-15` (resuelto en el mismo bloque).
- repos afectados: ambos.

### H-IHH-15 — `lint:contamination` confunde docs legítima con contaminación

- estado: resuelto (commit 5b0252a5)
- severidad: media
- evidencia: descubierto durante T-IHH-14. El filtro original solo perdonaba `CHANGELOG.md:.devtools/releases/(prod|staging).md`. Cualquier mención literal de `.devtools/` en otros docs disparaba el lint, incluyendo el README de gobierno publicado en a346790d.
- archivo: `Taskfile.yaml`.
- línea: tarea `lint:contamination`, regla `filtered`.
- impacto: lint falla en baseline tras publicar gobierno técnico, bloqueando `task ci` en clones limpios.
- tarea relacionada: `T-IHH-17`.
- repos afectados: `ihh-devtools`.

### H-AMBOS-1 — `.devtools.lock` declara versión inexistente

- estado: abierto
- severidad: crítica
- evidencia: detallado en `erd-ecosystem/versioning-research.md`. Resumen aquí: el consumidor declara `DEVTOOLS_VERSION="v0.1.1-rc.1+build.40"`. Este toolset tiene `VERSION=0.1.0` y `.promote_tag=v0.1.0`. El tag no existe en este repo.
- archivo: `erd-ecosystem/.devtools.lock` (líneas 9-13).
- línea: 9-13 del lock del consumidor.
- impacto: bloquea `git devtools-update` del consumidor.
- tarea relacionada: `T-AMBOS-4`.
- repos afectados: ambos.

### H-AMBOS-2 — 11 BATS suites no migradas al canónico

- estado: abierto
- severidad: alta
- evidencia: detallado en `erd-ecosystem/versioning-research.md`.
- archivo: `erd-ecosystem/.devtools/tests/*.bats` (no en zip), `ihh-devtools/tests/`.
- línea: no aplicable.
- impacto: re-vendorizar borra cobertura.
- tarea relacionada: `T-AMBOS-5`.
- repos afectados: ambos.

### H-AMBOS-3 — Contrato del consumidor no se valida

- estado: abierto
- severidad: alta
- evidencia: detallado en `erd-ecosystem/versioning-research.md`.
- archivo: `lib/core/contract.sh`, `bin/git-devtools-update.sh`.
- línea: pendiente de revisión completa.
- impacto: errores de contrato se descubren en runtime.
- tarea relacionada: `T-IHH-3`.
- repos afectados: ambos.

### H-AMBOS-8 — `vendorize.sh` placeholder; manifest decorativo

- estado: abierto
- severidad: crítica
- evidencia:
  - `scripts/vendorize.sh` (33 líneas) solo verifica que existen `bin/devtools` y `lib/`.
  - `bin/git-devtools-update.sh:356` usa `git archive --format=tar "$tag"` para extraer el árbol completo. Ignora `vendor.manifest.yaml`.
- archivo: `scripts/vendorize.sh`, `bin/git-devtools-update.sh:356`, `vendor.manifest.yaml`.
- línea: 1-33 del placeholder; 356 del flujo real.
- impacto: el contrato anunciado (incluir solo `bin/**, lib/**, config/**, scripts/**, VERSION, README.md`) NO se cumple. El consumidor recibe el árbol completo del tag (incluyendo `devbox-app/`, `docs/`, `devbox.json` con secret).
- tarea relacionada: `T-IHH-4`, `T-AMBOS-10`, `P-AMBOS-3`.
- repos afectados: ambos.

### H-AMBOS-9 — Toolset acoplado a PMBOK con secret hardcodeado

- estado: parcialmente resuelto (Phase1 cerrada 2026-04-26; Phase2 pendiente)
- severidad: crítica
- evidencia original:
  - `devbox.json:30-33`: `DB_NAME=pmbok_db`, `DB_USER=pmbok_user`, `DB_PASSWORD=secretpassword123`.
  - `devbox.json:152-153`: scripts `backend` y `frontend` ejecutan `cd apps/pmbok/...`.
  - `devbox.json:145`: el menú "Dev" exporta `DEVBOX_ENV_NAME=PMBOK`.
- evidencia post-Phase1:
  - `devbox.json` `env`: bloque retirado, solo conserva `DEVBOX_ENV_NAME=IHH` (identificador del shell, no app).
  - `devbox.json` `scripts.backend`/`frontend`: eliminados.
  - `devbox.json` `init_hook` línea 143: aviso genérico; línea 145 case "Dev": `DEVBOX_ENV_NAME=DEV`.
- pendiente Phase2:
  - ~40 menciones literales `pmbok` en `lib/promote/workflows/common.sh`, `to-dev.sh`, `to-local/*.sh` (refactor mayor; coupled a `tests/`).
- archivo: `devbox.json` (Phase1) + `lib/promote/workflows/**` (Phase2).
- impacto residual:
  - Vía `H-AMBOS-8`, el `devbox.json` ya purgado de PMBOK viajará a cada consumer cuando re-vendorize. Riesgo principal acotado.
  - El acoplamiento en `lib/promote/workflows/**` sigue activo hasta Phase2.
- tarea relacionada: `T-AMBOS-3` (Phase1 cerrada, Phase2 abierta).
- repos afectados: ambos.

---

## 6. Tareas ejecutables

### T-IHH-1 — Validar parsers de tags ante esquema dual (legacy + SemVer estricto)

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `J-IHH-2`.
- qué se hizo: nada.
- qué falta: revisar `lib/core/semver.sh` y otros parsers para confirmar que aceptan ambos esquemas.
- bloqueos: ninguno.
- siguiente paso: leer parsers y crear tests si es necesario.

### T-IHH-2 — Resolver desfase `main-b80c3c4` ↔ `main` y decidir destino de `tests/devbox-shell-smoke.sh`

- estado: abierto
- prioridad: P0
- hallazgo relacionado: `H-IHH-1`, `H-IHH-2`.
- qué se hizo: nada.
- qué falta: decidir si `main-b80c3c4` se mergea, renombra o se hace nueva rama. Decidir si `tests/devbox-shell-smoke.sh` se trackea o se mueve a `tests/contracts/`.
- bloqueos: ninguno.
- siguiente paso: ejecutar `git rev-parse main && git rev-parse HEAD` y comparar.

### T-IHH-3 — Implementar validación del contrato del consumidor

- estado: abierto
- prioridad: P1
- hallazgo relacionado: `H-AMBOS-3`.
- qué se hizo: nada.
- qué falta: en `lib/core/contract.sh`, añadir verificación de que el consumidor tiene `devtools.repo.yaml` válido. Llamarla desde `git-devtools-update.sh` antes de cualquier operación destructiva.
- bloqueos: ninguno.
- siguiente paso: diseñar la firma de la función y los códigos de error.

### T-IHH-4 — Implementar `vendorize.sh` real o eliminar manifest

- estado: abierto
- prioridad: P0
- hallazgo relacionado: `H-AMBOS-8`, `H-IHH-7`.
- qué se hizo: nada (decisión humana pendiente).
- qué falta: decisión `P-AMBOS-3` (método canónico de vendorización). Si se conserva el manifest, implementar `vendorize.sh` que produzca un snapshot real respetando los globs. Si se elimina, retirar el manifest y ajustar documentación.
- bloqueos: `P-AMBOS-3`.
- siguiente paso: pedir decisión arquitectónica.

### T-IHH-5 — Implementar rollback automático en `git-devtools-update.sh`

- estado: abierto
- prioridad: P1
- hallazgo relacionado: `H-IHH-3`.
- qué se hizo: nada.
- qué falta: si `cp -R` falla tras el `mv`, restaurar el backup. Limpieza programada de `.bak.<timestamp>` viejos.
- bloqueos: ninguno.
- siguiente paso: editar `apply_vendored_snapshot_from_repo_tag` (línea 343-396).

### T-IHH-6 — Documentar todos los entrypoints en README

- estado: resuelto (auditoría 2026-04-26)
- prioridad: P2
- hallazgo relacionado: `H-IHH-4`.
- qué se hizo: README sección 5 reescrita con tres tablas (públicos, auxiliares, infraestructura). Cada entrada con entrypoint y descripción.
- qué falta: nada.
- bloqueos: ninguno.

### T-IHH-7 — Decidir patrón único en `lib/promote/workflows/`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-IHH-5`.
- qué se hizo: nada.
- qué falta: o convertir todos los workflows al patrón numerado de `to-local/`, o consolidar `to-local/` en un solo archivo.
- bloqueos: ninguno.
- siguiente paso: discutir patrón.

### T-IHH-8 — Documentar dominio de `lib/core/git*.sh` y `lib/git*.sh`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-IHH-6`.
- qué se hizo: nada.
- qué falta: cabecera por archivo explicando responsabilidad. O consolidar.
- bloqueos: ninguno.
- siguiente paso: revisar cada archivo.

### T-IHH-9 — Documentar o consolidar `bin/git-lim.sh` y `bin/git-sw.sh`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-IHH-8`.
- qué se hizo: nada.
- qué falta: leer ambos archivos y decidir.
- bloqueos: ninguno.
- siguiente paso: leer.

### T-IHH-10 — Documentar comportamiento de `registries: null`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-IHH-9`.
- qué se hizo: nada.
- qué falta: documentar en `lib/core/contract.sh` y/o en el comentario de `devtools.repo.yaml`.
- bloqueos: ninguno.
- siguiente paso: redactar.

### T-IHH-11 — Verificar pertenencia de `bin/.codex/`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-IHH-10`.
- qué se hizo: nada.
- qué falta: confirmar con operador si pertenece al repo o se elimina.
- bloqueos: ninguno.
- siguiente paso: confirmar.

### T-IHH-12 — Quitar `--force` en `git fetch` de `git-acp.sh`

- estado: resuelto
- prioridad: P1
- hallazgo relacionado: `H-IHH-11`.
- qué se hizo: en commit 6515740b se quitó `--force` de la línea 218 de `bin/git-acp.sh`. El `git fetch --tags` ya no sobrescribe tags locales divergentes; git emite `[rejected] (would clobber existing tag)` aunque el `2>&1` lo silencia (deuda menor T-IHH-19).
- qué falta: nada. Verificado con sandbox aislado en dos escenarios (con/sin `--force`).
- bloqueos: ninguno.
- siguiente paso: editar y testear con un escenario de tags divergentes.

### T-IHH-13 — Validar variable antes de `checkout` en `git-promote.sh:272`

- estado: resuelto (auditoría 2026-04-26)
- prioridad: P2
- hallazgo relacionado: `H-IHH-12`.
- qué se hizo: cleanup_on_exit captura `DEVTOOLS_PROMOTE_FROM_BRANCH` en variable local `from_branch`; si está vacía, salta el restore con aviso explícito. Sintaxis validada con `bash -n`.
- qué falta: nada.
- bloqueos: ninguno.

### T-IHH-14 — Ampliar `lint:contamination` a `bin/` y `lib/`

- estado: resuelto
- prioridad: P1
- hallazgo relacionado: `H-IHH-13`.
- qué se hizo: en commit 5b0252a5 se amplió `TARGETS` del lint a `bin` y `lib` (cubre 79 scripts shell productivos). Se descubrió que el lint pesimista trataba como contaminación menciones legítimas de `.devtools/` en docs (nuevo hallazgo H-IHH-15); se resolvió en el mismo commit con un filtro multi-regla (T-IHH-17). H-IHH-13 confirmado como falso positivo: `bin/` y `lib/` no tenían contaminación real, solo 4 falsos positivos clasificados (2 self-ref + 2 string match URL).
- qué falta: nada. Verificado con `task ci` y contraprueba canary.
- bloqueos: ninguno.
- siguiente paso: edición de una línea.

### T-IHH-15 — Refactorizar `git-acp.sh` para `git add` controlado

- estado: resuelto (B-2)
- prioridad: P1
- hallazgo relacionado: `H-IHH-14`.
- qué se hizo: refactor opción F (combinación de modos). Default cambia a `confirm` (muestra `git status --short`, pide `[Y/n]` antes de `git add .`). Flags nuevos: `--staged-only` (alias `--no-add`), `--interactive` (alias `-p`, invoca `git add -p`), `--yes` (alias `--no-confirm`, comportamiento legacy). Variable `DEVTOOLS_ACP_DEFAULT_MODE` (`confirm | staged | interactive | yes`) controla el default; flag CLI siempre gana. Helper en `lib/core/acp-mode.sh`. Suite contractual en `tests/contracts/git-acp.bats` (19 tests).
- qué falta: nada del scope original.
- bloqueos: ninguno.

### T-IHH-16 — Crear `tests/contracts/` con suite base

- estado: resuelto (Fase 2B, commit `ddf04486`)
- prioridad: P1
- hallazgo relacionado: `H-IHH-2`.
- qué se hizo: `tests/contracts/vendor.bats` con 18 tests (`vendor_resolve_tag`, `vendor_is_excluded_tag`, `vendor_compute_tree_sha`, `vendor_validate_lock`, `vendor_check_drift` e invariantes), más 5 fixtures controlados en `tests/contracts/fixtures/`.
- qué falta: nada del scope original. Sub-deuda separada: `.ci/contract-checks.yaml` (registrada como P2 no bloqueante; mientras tanto `task ci` cubre la validación).
- bloqueos: ninguno.
- nota: `T-IHH-20` abre el frente específico de regresión para `lib/promote/workflows/**` antes de SEC-2B-Phase2.

### T-IHH-17 — Separar reglas de contaminación entre código y documentación

- estado: resuelto
- prioridad: P1
- hallazgo relacionado: `H-IHH-15`.
- qué se hizo: en commit 5b0252a5 se amplió el filtro de `lint:contamination` de 1 a 4 reglas. (1) Backticks en markdown para `.devtools/` legítimo en docs. (2) Self-reference de la propia definición del pattern en `lib/promote/workflows/common.sh`. (3) String match de URLs `://github.com/` en `lib/wizard/step-04-profile.sh`. (4) La regla CHANGELOG existente intacta. PATTERN base sin cambios; el filtro NO perdona rutas absolutas ni URLs sin contexto. Verificado con cuatro contrapruebas.
- qué falta: nada.
- bloqueos: ninguno.

### T-IHH-19 — Hacer visible el aviso de tag-clobber en `git-acp.sh`

- estado: resuelto (auditoría 2026-04-26)
- prioridad: P2
- hallazgo relacionado: ninguno (deuda menor descubierta al cerrar T-IHH-12).
- qué se hizo: el `git fetch --tags` post-rebase ahora redirige stdout a `/dev/null` y captura stderr en variable. Si stderr contiene "rejected" o "clobber", se muestran al operador prefijados como aviso (`Tags locales preservados ...`). Sintaxis validada con `bash -n`.
- qué falta: nada. UX queda visible sin perder el silencio del flujo normal.
- bloqueos: ninguno.

### T-IHH-20 — Suite de regresión para `lib/promote/workflows/**`

- estado: resuelto (B-3)
- prioridad: P1
- hallazgo relacionado: `H-AMBOS-9` Phase2.
- qué se hizo: suite contractual `tests/contracts/promote-workflows.bats` con 21 tests cubriendo las funciones casi puras de `lib/promote/workflows/{common.sh,to-local/10-utils.sh,to-local/50-k8s.sh}`: `resolve_promote_component` (6 tests), `promote_is_protected_branch` (4 tests), `promote_local_is_valid_tag_name` (3 tests), `promote_local_read_overlay_tag_from_text` (2 tests), `promote_local_next_tag_from_previous` (2 tests, con mocks de `promote_base_tag_for_local` / `promote_strip_rev_from_tag`), `promote_local_pull_policy` (3 tests) e invariante estructural (1 test). Estrategia escogida: invocación dry-run de funciones aisladas con stubs de logging y mocks puntuales para dependencias de `lib/promote/version-strategy.sh`.
- qué falta: nada del scope original. Cobertura intencionalmente excluida (orquestadores end-to-end, funciones que requieren docker/kubectl/argocd/red): pendiente como bloque P2 separado si surge necesidad.
- bloqueos: ninguno.
- impacto: SEC-2B-Phase2 desbloqueada conceptualmente; el refactor de las ~40 menciones literales `pmbok` queda pendiente de ejecución como bloque separado, ya con red de seguridad contractual.

---

## 7. Preguntas abiertas

### P-IHH-1 — ¿`bin/.codex/` pertenece al repo?

- estado: abierto
- pregunta: ¿el directorio es funcional o un artefacto residual de la herramienta Codex?
- contexto: `H-IHH-10`.
- decisión requerida: conservar o eliminar.
- impacto si no se responde: continúa la duda.
- responsable sugerido: operador del repo.

### P-AMBOS-1 — Unificar `services.yaml` vs `apps.yaml` (ADR 0002)

- estado: abierto
- contexto: replicada en `erd-ecosystem/versioning-research.md`.
- responsable sugerido: arquitecto del ecosistema.

### P-AMBOS-3 — Método canónico de vendorización

- estado: abierto
- contexto: ADR 0001 P-02. Detallada en `erd-ecosystem/versioning-research.md`.
- decisión requerida: ADR 0003.
- impacto si no se responde: el manifest seguirá decorativo. Bloquea `T-IHH-4`.
- responsable sugerido: mantenedor de este repo.

### P-AMBOS-5 — Toolset genérico vs específico de PMBOK

- estado: cerrado parcialmente el 2026-04-26 (bloque SEC-2B-Phase1).
- decisión tomada: **toolset genérico**. ihh-devtools no asume `pmbok` ni stack Django/Vite.
- implementación Phase1 (bloque SEC-2B-Phase1):
  - `devbox.json` `env`: bloque retirado salvo `DEVBOX_ENV_NAME`.
  - `devbox.json` `scripts.backend`/`frontend`: eliminados.
  - `devbox.json` `init_hook`: ajustes de mensaje y label.
  - `README.md`: nota de cierre + migration note para consumers.
  - `versioning-research.md`: este cierre.
- pendiente Phase2: refactor de `lib/promote/workflows/**` (~40 menciones literales `pmbok`). Desbloqueado conceptualmente: `T-IHH-20` resuelto en B-3 (`tests/contracts/promote-workflows.bats`); pendiente de ejecución como bloque separado. Nota: `T-IHH-16` cerrado en `ddf04486`.
- responsable Phase2: mantenedor de este repo.

---

## 8. Bloqueos externos

### B-IHH-1 — Tag inexistente en `.devtools.lock` del consumidor (`H-AMBOS-1`)

- estado: abierto
- bloqueo: el lock declara `v0.1.1-rc.1+build.40` pero este repo no tiene ese tag.
- causa: el tag se heredó del legado `iHexHubs/devtools`.
- impacto: cualquier `git devtools-update` desde el consumidor falla.
- dependencia externa: decidir tag base real (acción en este repo) y reescribir el lock (acción en `erd-ecosystem`).
- siguiente paso: ver `T-AMBOS-4`.

### B-AMBOS-2 — ADR 0002 sin escribir bloquea sync de catálogos

- estado: abierto
- contexto: replicada.

### B-AMBOS-3 — Genericidad del toolset bloqueada por `H-AMBOS-9`

- estado: abierto
- contexto: replicada.

---

## 9. Tareas conjuntas con `erd-ecosystem`

### T-AMBOS-1 — Migrar 7 repos hermanos al canónico (T-ADR-05)

- estado: abierto
- prioridad: P2
- hallazgo relacionado: 247 referencias inventariadas.
- qué se hizo: inventario completo en `docs/migration-2026-04/legacy-devtools-references.txt`.
- qué falta: ejecutar el procedimiento de migración en cada repo cuando tenga trabajo activo.
- bloqueos: `J-AMBOS-4` permite que sea progresivo.
- siguiente paso: el operador decide en qué orden.

### T-AMBOS-3 — Aislar variables específicas de PMBOK del `devbox.json`

- estado: Phase1 resuelto (2026-04-26); Phase2 abierto
- prioridad: P0 → P1 (Phase2)
- hallazgo relacionado: `H-AMBOS-9`, `H-ERD-8`.
- qué se hizo Phase1: bloque SEC-2B-Phase1. `devbox.json` `env` retirado, `scripts` PMBOK eliminados, `init_hook` ajustado.
- qué falta Phase2: refactor de `lib/promote/workflows/**` (~40 hits literales). `T-IHH-20` resuelto en B-3 (`tests/contracts/promote-workflows.bats`); SEC-2B-Phase2 desbloqueado conceptualmente, pendiente de ejecución como bloque separado.
- bloqueos Phase2: ninguno conceptual. Pendiente de ejecución (decisión de scheduling humana).
- siguiente paso: abrir SEC-2B-Phase2 cuando el operador lo priorice; la suite contractual ya cubre las funciones casi puras de los 3 archivos núcleo.

### T-AMBOS-4 — Decidir tag base real y reescribir `.devtools.lock`

- estado: abierto
- prioridad: P0
- hallazgo relacionado: `H-AMBOS-1`.
- qué se hizo: nada.
- qué falta: en este repo, decidir si crear un tag SemVer (p. ej. `v0.1.0` ya existe; o nuevo `v0.1.1`). En el consumidor, reescribir el lock.
- bloqueos: ninguno operacional.
- siguiente paso: confirmar tag y editar.

### T-AMBOS-5 — Migrar 11 BATS suites al canónico antes de re-vendorizar

- estado: abierto
- prioridad: P0
- hallazgo relacionado: `H-AMBOS-2`.
- qué se hizo: nada.
- qué falta: identificar las 11 suites en `erd-ecosystem/.devtools/tests/`, copiarlas a `ihh-devtools/tests/contracts/` (o estructura aceptada), validar que pasan en este repo. Solo entonces ejecutar `T-ERD-3`.
- bloqueos: ninguno.
- siguiente paso: listar suites y diseñar la integración.

### T-AMBOS-6 — Estandarizar URL canónica en todos los lugares

- estado: en-progreso (parcialmente aplicada en `erd-ecosystem`)
- prioridad: P1
- hallazgo relacionado: `H-AMBOS-4`.
- qué se hizo: lock corregido a `iHexHubs/ihh-devtools` en el consumidor; `new-webapp.sh:31` cambió a HTTPS público.
- qué falta: cambiar `new-webapp.sh:31` a SSH con host alias. Auditar todas las referencias en docs.
- bloqueos: ninguno.
- siguiente paso: editar y validar.

### T-AMBOS-7 — Documentar relación `VERSION` ↔ `.promote_tag`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-AMBOS-5`.
- qué se hizo: nada.
- qué falta: documentación cruzada en ambos `docs/versionado.md`.
- bloqueos: ninguno.
- siguiente paso: redactar.

### T-AMBOS-8 — Decidir gobernanza de `cliff.toml`

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-AMBOS-6`.
- qué se hizo: nada.
- qué falta: decidir si se vendoriza desde este repo o se mantiene independiente.
- bloqueos: ninguno.
- siguiente paso: discutir.

### T-AMBOS-9 — Estandarizar convenciones de "guías para agentes IA"

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `H-AMBOS-7`.
- qué se hizo: nada.
- qué falta: decidir si `AGENTS.md` es el único, o si conviven con `GEMINI.md` y `.claude/`.
- bloqueos: ninguno.
- siguiente paso: discutir.

### T-AMBOS-10 — Resolver `vendor.manifest.yaml` decorativo

- estado: abierto
- prioridad: P0
- hallazgo relacionado: `H-AMBOS-8`.
- qué se hizo: nada.
- qué falta: decisión `P-AMBOS-3`. Si se conserva el manifest, implementar `vendorize.sh` real. Si no, eliminar el manifest y ajustar docs.
- bloqueos: `P-AMBOS-3`.
- siguiente paso: pedir decisión.

### T-AMBOS-11 — Eliminación definitiva de `iHexHubs/devtools` (T-ADR-07)

- estado: abierto
- prioridad: P2
- hallazgo relacionado: `J-IHH-1`.
- qué se hizo: el repo legado está archivado.
- qué falta: ejecutar tras `T-AMBOS-1` y `T-ADR-06` (auditoría final de residuos).
- bloqueos: depende de cierre de migración.
- siguiente paso: posterior.

---

## 10. Checklist para próxima auditoría

- [ ] `git status -sb && git log --oneline -10`
- [ ] `git rev-parse main && git rev-parse HEAD`  → confirmar estado de `H-IHH-1`
- [ ] `task ci`  → exit 0 esperado
- [ ] `bash scripts/gh-policy-check.sh`  → exit 0
- [ ] `bash scripts/vendorize.sh; echo "exit=$?"`  → confirmar `H-AMBOS-8` (solo verifica paths)
- [ ] `find tests -type f`  → confirmar contenido real de `tests/`
- [ ] `git tag --list | sort -V | tail -10`  → verificar si existe `v0.1.1-rc.1+build.40` (`H-AMBOS-1`)
- [ ] `grep -nE 'DB_PASSWORD|pmbok' devbox.json`  → confirmar `H-AMBOS-9`
- [ ] `grep -rEn '/webapps/[a-z]|/home/[a-z]+/|/Users/[A-Za-z]+/' bin lib`  → debe estar limpio
- [ ] Validar que `git-devtools-update.sh` tiene rollback (post `T-IHH-5`)

---

## 11. Referencias

- `docs/adr/0001-devtools-consolidation.md` (canónica de la consolidación).
- `docs/migration-2026-04/README.md` (plan de migración).
- `docs/migration-2026-04/legacy-devtools-references.txt` (247 hits).
- `erd-ecosystem/versioning-research.md` (gobierno paralelo del consumidor principal).
- `erd-ecosystem/AUDITORIA_TECNICA_PARALELA.md` (fase 1).
- `erd-ecosystem/AUDITORIA_INDEPENDIENTE_FASE_2.md` (fase 2).

# ihh-devtools

Toolset CLI en Bash para estandarizar el ciclo de vida de código en repos que usan Git.

> **Estado de genericidad:** `H-AMBOS-9` y `P-AMBOS-5` cerrados parcialmente el 2026-04-26 (bloque SEC-2B-Phase1). El bloque `env` del `devbox.json` raíz fue retirado; los scripts `backend`/`frontend` PMBOK eliminados. Las ~40 menciones literales `pmbok` en `lib/promote/workflows/**` se difieren a Phase2. Ver [`./versioning-research.md`](./versioning-research.md) para detalle.

## 1. Descripción

Toolset que se vendoriza como `.devtools/` dentro de cada consumidor. Expone comandos como aliases efímeros de Git dentro de `devbox shell`, sin contaminar la configuración global.

## 2. Estado actual

| Aspecto | Estado | Verificación |
|---|---|---|
| Toolset canónico (ADR 0001) | Vigente | Verificado en archivo |
| 17 entrypoints en `bin/` | Verificado | Listado |
| ~32 archivos en `lib/` | Verificado | Listado |
| Repo legado archivado en GitHub | Resuelto | Por reporte previo |
| Rama `main-b80c3c4` desfasada de `main` | Pendiente | Por reporte previo |
| Tests contractuales (`tests/contracts/`) | Implementados parcialmente (Fase 2B, `vendor.bats`) | Verificado |
| `vendor.manifest.yaml` aplicado | **No** (decorativo) | Verificado en `scripts/vendorize.sh` |
| Migración de 7 repos hermanos | Pendiente | Por inventario |

## 3. Relación con el ecosistema

`ihh-devtools` es **productor**. [`erd-ecosystem`](../erd-ecosystem) es uno de los 8 consumidores (ver `docs/migration-2026-04/README.md`).

Hallazgos cruzados activos están registrados en [`./versioning-research.md`](./versioning-research.md) bajo el prefijo `H-AMBOS-`.

## 4. Qué problema resuelve

Equipos con múltiples repos necesitan un flujo consistente de commits, promociones entre ramas, versionado SemVer y changelog. `ihh-devtools` se vendoriza dentro de cada repo y expone comandos como aliases efímeros de Git dentro de `devbox shell`.

## 5. Comandos disponibles

### Públicos (uso diario)

| Comando | Entrypoint | Descripción |
|---|---|---|
| `git acp` | `bin/git-acp.sh` | Add + commit + push con gestión de identidades SSH y enforcement de feature branch. Modos de staging: default `confirm` (pide `[Y/n]`), `--staged-only`/`--no-add`, `--interactive`/`-p`, `--yes`/`--no-confirm`. Variable `DEVTOOLS_ACP_DEFAULT_MODE` (`confirm \| staged \| interactive \| yes`) controla el default. |
| `git promote` | `bin/git-promote.sh` | Promoción entre ramas con gates por SHA, versionado SemVer, changelog automático y tags. |
| `git feature` | `bin/git-feature.sh` | Crear/actualizar ramas `feature/*` desde `dev`. |
| `git gp` | `bin/git-gp.sh` | Generar prompt para IA con el diff actual. |
| `git rp` | `bin/git-rp.sh` | Reset + force push destructivo del último commit (solo ramas no protegidas). |
| `git sweep` | `bin/git-sweep.sh` | Limpieza masiva de ramas y tags obsoletos. |
| `git devtools-update` | `bin/git-devtools-update` (wrapper) → `git-devtools-update.sh` | Actualizar la copia vendorizada en repos consumidores. |

### Auxiliares y wrappers

| Comando | Entrypoint | Descripción |
|---|---|---|
| `git ci` | `bin/git-ci.sh` | Ejecuta el menú de CI detectado para el repo actual. |
| `git pipeline` | `bin/git-pipeline.sh` | Ejecuta el pipeline local detectado para el repo actual. |
| `git pr` | `bin/git-pr.sh` | Crea o abre un PR en GitHub para la rama actual (`BASE_BRANCH=dev` por defecto). |
| `git release-draft` | `bin/git-release-draft.sh` | Crea o actualiza un release draft en GitHub para un tag existente (`TAG=v1.2.3`). |
| `git lim` | `bin/git-lim.sh` | Alias rápido: `git-sweep --apply --no-tags`. |
| `git sw` | `bin/git-sw.sh` | Alias plano hacia `git-sweep` (pasa argumentos tal cual). |

### De infraestructura (no se exponen como `git ...`)

| Entrypoint | Descripción |
|---|---|
| `bin/devtools` | Dispatcher principal del toolset. Ejemplo de uso: `devtools apps sync [--only <app>]`. |
| `bin/setup-wizard.sh` | Wizard interactivo de setup local (identidades SSH/GPG, perfiles); se invoca al entrar por primera vez a `devbox shell`. |
| `bin/git-devtools-update.sh` | Implementación real de `git devtools-update` (vendoring vía `git archive` del tag base). |

## 5.1 Migration note para consumers existentes (SEC-2B-Phase1, 2026-04-26)

El bloque `env` del `devbox.json` raíz fue retirado en Phase1. Los consumers que dependían de variables exportadas por el shell `devbox` del toolset (p. ej. `SECRET_KEY`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `VITE_API_URL`, etc.) deben definirlas localmente:

- En su propio `devbox.json` (en el `env` del consumer, no del toolset vendorizado).
- O en `.env.local` ignorado por git, cargado por el flujo del consumer.

Los scripts `backend` y `frontend` que ejecutaban `cd apps/pmbok/...` también fueron retirados. Los consumers que los usaban deben definirlos en su propio `devbox.json`.

Aliases git (`acp`, `gp`, `rp`, `promote`, `feature`) y scripts `setup-k8s`, `dev:*` se conservan. Esta migración no rompe el flujo de promoción.

Phase2 (futura) abordará las ~40 menciones literales `pmbok` en `lib/promote/workflows/**`.

## 6. Requisitos previos

- [Devbox](https://www.jetify.com/devbox) (gestiona todas las dependencias).
- Git.
- SSH configurado para el host de Git.
- Docker (para `devbox-app` de referencia).

Devbox instala automáticamente: `gh`, `gum`, `jq`, `yq`, `bats`, `git-cliff`, `starship`, `kubectl`, `helm`, `kustomize`, `argocd`, `terraform`, `awscli`.

## 7. Instalación

### En un repo existente (como submódulo)

```bash
git submodule add git@github.com-reydem:iHexHubs/ihh-devtools.git .devtools
```

> URL canónica según ADR 0001 J-06 (`J-AMBOS-3`).

### Uso

```bash
devbox shell        # Activa el entorno: aliases efímeros, wizard, prompt
git acp             # Commit y push
git promote         # Promoción entre ramas
```

Al entrar a `devbox shell` por primera vez, el **setup wizard** guía la configuración de identidades SSH/GPG y perfiles.

## 8. Flujo de promoción

```
feature/* → dev-update → dev → staging → main
```

Cada salto tiene:
- **Gate por SHA**: verifica que el commit esperado es el que se promueve.
- **Menú de seguridad**: confirmación interactiva obligatoria.
- **Estrategia configurable**: merge, rebase o fast-forward según la rama.
- **Versionado automático**: bump SemVer + tag + changelog (git-cliff).
- **Sync GitOps**: actualización de manifiestos Kustomize y sync con ArgoCD (si aplica).

## 9. Estructura del repo

```
bin/                    Entrypoints de cada comando
lib/
  core/                 Motor compartido: semver, config, logging, git-ops
  promote/
    workflows/          Un workflow por salto de rama (to-dev.sh, to-staging.sh, etc.)
    strategies/         Estrategias de merge
  wizard/               Pasos del setup wizard
  ui/                   Banners, prompts, estilos (gum)
config/                 Archivos de configuración (workflows.conf)
scripts/                Scripts auxiliares (vendorize.sh, gh-policy-check.sh)
devbox-app/             App de referencia (React + Django + Postgres + GitOps)
docs/                   ADRs (`docs/adr/`) y plan de migración (`docs/migration-2026-04/`)
.github/workflows/      CI (lint shell + contaminación) y release de devbox-app
```

> **Esqueleto en preparación:** `intent/`, `spec/`, `implementation/`, `integration/`, `contracts/` contienen subdirectorios reservados para artefactos de la metodología spec-anchored. Aún no hay contenido.
>
> **`tests/contracts/vendor.bats`** está implementado desde Fase 2B (18 tests, commit `ddf04486`). `.ci/contract-checks.yaml` queda como sub-deuda P2 separada y no bloqueante; mientras tanto la validación CI vive en `Taskfile.yaml` (`lint:shell`, `lint:contamination`, `gh-policy-check`).
>
> **Importante:** `vendor.manifest.yaml` actualmente NO se aplica al vendorizar (`H-AMBOS-8`). El consumidor recibe el árbol completo del tag.

## 10. Configuración

### `devtools.repo.yaml`

Contrato del repo. Define paths canónicos y registros:

```yaml
schema_version: 1
paths:
  vendor_dir: .devtools
config:
  profile_file: .git-acprc
```

### `.git-acprc`

Perfil de identidad por repo. Configurado por el setup wizard. Contiene el nombre, email y clave SSH a usar en commits.

> **Aviso:** `.git-acprc` puede contener datos personales. Mantenerlo SIEMPRE en `.gitignore`. Verificar en historia git antes de hacer push (referencia: T0.0-bis en `erd-ecosystem`).

## 11. `devbox-app`

El directorio `devbox-app/` contiene una aplicación de referencia (React + Django + Postgres) con manifiestos GitOps (Kustomize + ArgoCD) que sirve para validar que todo el tooling funciona end-to-end.

## 12. Testing, lint, typecheck y build

| Comando | Estado |
|---|---|
| `task ci` | Detectado, no ejecutado en esta auditoría |
| `task lint:shell` | Solo verifica `bash -n` (sintaxis), no ejecuta `shellcheck` |
| `task lint:contamination` | **Solo escanea `README.md, CHANGELOG.md, scripts, devtools.repo.yaml`** (`H-IHH-13`). NO escanea `bin/` ni `lib/` |
| `bash scripts/gh-policy-check.sh` | Detectado, no ejecutado |
| `bash scripts/vendorize.sh` | **Es un placeholder** (`H-AMBOS-8`). Solo verifica que existen `bin/devtools` y `lib/`. No empaqueta nada |
| BATS tests | `tests/contracts/vendor.bats` (Fase 2B, 18 tests, validación de `lib/core/vendor.sh`) + `tests/contracts/git-acp.bats` (B-2, 19 tests, modos de staging de `bin/git-acp.sh` + `lib/core/acp-mode.sh`) + `tests/contracts/promote-workflows.bats` (B-3, 21 tests, regresión de funciones casi puras de `lib/promote/workflows/**`) + `tests/contracts/services.bats` (B-5, 22 tests, helper canónico `lib/core/services.sh`). |

## 13. Auditoría técnica y gobierno del repo

El gobierno técnico del repo se trazea en [`./versioning-research.md`](./versioning-research.md).

### Convención de etiquetas

| Tipo | Significado |
|---|---|
| T | Tarea ejecutable |
| H | Hallazgo con evidencia |
| J | Justificación / decisión arquitectónica |
| P | Pregunta abierta al equipo |
| B | Bloqueo externo |

Sufijos: `-IHH-` (este repo), `-ERD-` (`erd-ecosystem`), `-AMBOS-` (afecta a ambos).

### Estados

| Estado | Significado |
|---|---|
| abierto | Identificado, no iniciado |
| en-progreso | En ejecución |
| bloqueado | No puede avanzar por dependencia |
| resuelto | Completado y validado |
| descartado | Cerrado sin acción |

### Prioridades

| Prioridad | Significado |
|---|---|
| P0 | Crítico / bloqueante |
| P1 | Importante / próximo ciclo |
| P2 | Mejora / deuda no bloqueante |

### Resumen de deuda técnica abierta (al 2026-04-26)

| ID | Severidad | Resumen |
|---|---|---|
| `H-AMBOS-8` | Crítica | `vendorize.sh` placeholder; `vendor.manifest.yaml` decorativo |
| `H-AMBOS-1` | Crítica | Lock del consumidor declara versión que no existe aquí |
| `H-IHH-1` | Alta | Rama `main-b80c3c4` desfasada |
| `H-IHH-3` | Alta | `git-devtools-update.sh` sin rollback automático |
| `H-AMBOS-2` | Alta | 11 BATS suites del consumer no migradas al canónico |

> Hallazgos resueltos en la auditoría 2026-04-26 / 2026-04-27: `H-IHH-4` (entrypoints documentados), `H-IHH-12` (cleanup `git-promote.sh` con variable validada), T-IHH-19 (aviso tag-clobber visible en `git-acp.sh`), **`H-AMBOS-9` Phase1+Phase2** (bloque `env` PMBOK retirado del `devbox.json` en SEC-2B-Phase1; refactor de `lib/promote/workflows/**` consumiendo `lib/core/services.sh` en B-5 SEC-2B-Phase2), **`H-IHH-14`** (refactor opción F en `git-acp.sh` con flags `--staged-only`/`--interactive`/`--yes` + variable `DEVTOOLS_ACP_DEFAULT_MODE`; bloque B-2). Ya resueltos previamente: `H-IHH-11`, `H-IHH-13`, `H-IHH-15`. Detalles en [`./versioning-research.md`](./versioning-research.md).

### Tareas P0 abiertas

- `T-IHH-2` — Resolver desfase `main-b80c3c4` ↔ `main` y destino de `tests/devbox-shell-smoke.sh`.
- `T-IHH-4` — Implementar `vendorize.sh` real o eliminar manifest (bloqueado por `P-AMBOS-3`).
- `T-AMBOS-3` — Phase1+Phase2 cerradas (Phase1 SEC-2B-Phase1 2026-04-26 + Phase2 SEC-2B-Phase2 / B-5 2026-04-27): refactor de `lib/promote/workflows/**` consumiendo `lib/core/services.sh` (helper canónico ADR 0002).
- `T-AMBOS-4` — Decidir tag base real y reescribir `.devtools.lock` del consumidor.
- `T-AMBOS-5` — Migrar 11 BATS suites antes de re-vendorizar.
- `T-AMBOS-10` — Resolver `vendor.manifest.yaml` decorativo (bloqueado por `P-AMBOS-3`).

### Tareas P1 abiertas

- `T-IHH-3` — Validación de contrato del consumidor.
- `T-IHH-5` — Rollback automático en `git-devtools-update.sh`.
- `T-IHH-15` — Refactorizar `git-acp.sh` para `git add` controlado. (resuelto en B-2)
- `T-IHH-16` — Crear `tests/contracts/` con suite base. (resuelto en commit `ddf04486`, Fase 2B)
- `T-IHH-20` — Suite de regresión específica para `lib/promote/workflows/**`. (resuelto en B-3, `tests/contracts/promote-workflows.bats` con 21 tests; SEC-2B-Phase2 desbloqueada conceptualmente)
- `T-AMBOS-6` — Estandarizar URL canónica (parcialmente resuelta en `erd-ecosystem` el 2026-04-26).

### Bloqueos activos

- `B-IHH-1` — Tag fantasma en `.devtools.lock` del consumidor.
- `B-AMBOS-2` — ADR 0002 sin escribir.

## 14. Auditorías paralelas

- `erd-ecosystem/AUDITORIA_TECNICA_PARALELA.md` — Fase 1 (Claude Code en terminal).
- `erd-ecosystem/AUDITORIA_INDEPENDIENTE_FASE_2.md` — Revisión externa fase 2.

Ambos archivos viven en `erd-ecosystem` por convención del operador.

## 15. Próximos pasos

1. Verificar baseline en terminal antes de modificar nada (ver checklist en `versioning-research.md` sección 10).
2. Resolver `T-IHH-2` (rama y tests) — alto impacto, bajo esfuerzo.
3. Aplicar `T-IHH-14` (lint:contamination) — cambio de una línea, alto valor.
4. Decidir `P-AMBOS-3` (vendorización). `P-AMBOS-5` cerrado totalmente: Phase1 (SEC-2B-Phase1, 2026-04-26) + Phase2 (B-5 SEC-2B-Phase2, 2026-04-27); `lib/promote/workflows/**` consume `lib/core/services.sh`.
5. Implementar `T-IHH-5` (rollback) antes de cualquier `git devtools-update` masivo.

## 16. Licencia

Consultar el archivo `LICENSE` en la raíz del repo (no presente en esta versión del zip).

# AGENTS.md — Reglas para agentes de IA

**ihh-devtools** es un toolset CLI en Bash que se vendoriza (como submódulo `.devtools`) dentro de otros repos para estandarizar el ciclo de vida de código: commits, promociones entre ramas, versionado semver, changelog y sync GitOps.

## Estructura del repo

```
bin/            Entrypoints de cada comando (git-acp.sh, git-promote.sh, etc.)
lib/
  core/         Motor compartido: semver, config, logging, git-ops, contratos
  promote/      Lógica de promoción: workflows por rama, estrategias de merge, helpers
  wizard/       Pasos del setup wizard (auth, ssh, config, profile)
  ui/           Banners, prompts y estilos (gum)
config/         Archivos de configuración (workflows.conf, workflows.conf.example)
scripts/        Scripts auxiliares (vendorize.sh, gh-policy-check.sh)
devbox-app/     App de referencia (React + Django + Postgres + GitOps/Kustomize)
docs/           ADRs (`docs/adr/`) y plan de migración (`docs/migration-2026-04/`)
.github/        Workflows: ci.yaml (lint shell, contaminación) y devbox-app-release.yaml
```

> **Esqueleto en preparación (sin contenido todavía):** `intent/intents/`, `spec/features/`, `implementation/experiments/`, `integration/tests/`, `integration/deltas/`, `integration/wsv/`, `contracts/reviews/`. Reservados para artefactos de la metodología spec-anchored.
>
> **Tests contractuales (`tests/contracts/`) y `.ci/contract-checks.yaml`** son objetivos pendientes. La validación actual vive en `Taskfile.yaml`: `task lint:shell`, `task lint:contamination`, `task ci`. Nuevas reglas se añaden ahí o en `scripts/gh-policy-check.sh` mientras no exista el plano contractual.

## Reglas

1. **No mezclar cambios de producto con cambios metodológicos.** Si estás tocando lógica de un comando (bug fix, feature), no incluyas en el mismo cambio refactors de estructura, specs o documentación metodológica.

2. **`devbox shell` es la frontera CLI/shell local.** Todo lo que ocurre dentro de `devbox shell` (aliases efímeros, wizard, prompt) es el entorno de ejecución. No asumas que los comandos existen fuera de esa sesión.

3. **`devbox shell --print-env` es una subfrontera observable.** Su superficie de exports es consumida por `lib/promote/workflows/common.sh`. Cambios en las variables exportadas pueden romper el flujo de promoción.

4. **Respetar el contrato en `devtools.repo.yaml`.** Este archivo define paths canónicos (`vendor_dir`, `profile_file`) y registros. No hardcodear esos valores en scripts; leerlos del contrato.

5. **No introducir rutas hardcodeadas.** Nada de `/home/usuario`, `/Users/foo`, ni paths absolutos a directorios personales. Usar `$root`, `$DT_ROOT` y resolución dinámica. El check `task lint:contamination` lo valida en cada CI.

6. **Antes de tocar un flujo, entender la cadena completa.** Cada comando empieza en `bin/git-<comando>.sh`, que hace `source` de módulos en `lib/`. Trazar la cadena de sources antes de modificar.

7. **Validación actual del repo:** `task ci` ejecuta `lint:shell` (sintaxis bash en `bin/` y `lib/`), `lint:contamination` y `scripts/gh-policy-check.sh` (políticas GitHub Actions). Cuando exista la suite contractual planificada en `tests/contracts/` y `.ci/contract-checks.yaml`, esta nota se actualiza.

## Archivos clave

Siempre considerar antes de hacer cambios:

- `devbox.json` — paquetes, variables de entorno, init_hook (aliases efímeros, wizard, prompt)
- `bin/setup-wizard.sh` — entrypoint del wizard interactivo
- `lib/core/*.sh` — motor compartido (semver, config, logging, git-ops)
- `lib/promote/workflows/common.sh` — lógica común de promoción, consume `--print-env`
- `devtools.repo.yaml` — contrato del repo (paths, registros)
- `vendor.manifest.yaml` — declara qué se incluye al vendorizar
- `Taskfile.yaml` — `ci`, `lint:shell`, `lint:contamination`, `app:devbox:*`
- `VERSION` y `.promote_tag` — versión semver actual del toolset

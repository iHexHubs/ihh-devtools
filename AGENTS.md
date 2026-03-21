# Reglas del repo

- La memoria metodologica de cada flujo vive dentro del repo.
- Para `devbox-shell`, el backbone SDD canonico vive en `specs/flows/devbox-shell/01-discovery.md` a `04-spec-as-source.md`.
- La derivacion `Contract-Driven` de `devbox-shell` vive en `specs/flows/devbox-shell/05-contract-scope.md`, `specs/flows/devbox-shell/06-contract-adoption.md`, `specs/contracts/devbox-shell/`, `tests/contracts/devbox-shell/` y `.ci/contract-checks.yaml`.
- No mezclar discovery, spec-first, spec-anchored, spec-as-source, Contract-Driven, Context-Driven ni Agentic QA.
- No introducir cambios de producto durante trabajo metodologico salvo autorizacion explicita.
- Tratar `devbox shell` como frontera CLI/shell local del flujo; `devbox shell --print-env` es una subfrontera observable consumida por `lib/promote/workflows/common.sh`.
- La validacion contractual primaria de `devbox-shell` debe ser nativa del runtime shell/CLI; `Specmatic` solo aplica si aparece una subfrontera honestamente soportada.
- Antes de promover una fase, dejar trazabilidad a `devbox.json`, `bin/setup-wizard.sh`, `lib/core/*.sh`, `lib/promote/workflows/common.sh`, `devtools.repo.yaml` y a cualquier corrida segura usada como evidencia.

# AGENTS.md

## Alcance

Este repositorio usa memoria metodológica por flujo dentro de `specs/flows/<flow-id>/`.
Para esta corrida, el flujo activo es `devbox-shell` y sus artefactos viven en:

- `specs/flows/devbox-shell/01-discovery.md`
- `specs/flows/devbox-shell/02-spec-first.md`
- `specs/flows/devbox-shell/03-spec-anchored.md`

## Reglas del repo para trabajo metodológico

- Mantener pureza de fase: no mezclar discovery, spec-first, spec-anchored, spec-as-source, implementation, evaluation ni review.
- No tocar código del producto durante reconstrucción metodológica salvo bootstrap documental del método.
- No convertir el comportamiento actual en contrato por inercia.
- Mantener visibles unknowns, seams, divergencias y límites reales.
- Usar evidencia rastreable del repo antes de afirmar comportamiento del flujo.

## Superficies probables del flujo `devbox shell`

Inspeccionar primero, según relevancia del hallazgo:

- `README.md`
- `devbox.json`
- `.devbox/`
- `Taskfile.yaml`
- `bin/`
- `lib/`
- `scripts/`
- `tests/`

## Verificación

- Preferir lectura de archivos, búsqueda estructural y observación no destructiva.
- Si se ejecuta algo del flujo, debe ser solo para observar y no para implementar ni mutar contrato.

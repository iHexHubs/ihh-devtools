# Reglas Operativas del Repo

Este repo guarda la memoria metodológica del flujo dentro de `specs/flows/<flow-id>/`.

## Estructura metodológica

- Usa `specs/flows/<flow-id>/01-discovery.md` para memoria del flujo observado.
- Usa `specs/flows/<flow-id>/02-spec-first.md` para la memoria contractual inicial.
- No mezcles discovery, spec-first y fases posteriores en un mismo artefacto.

## Alcance para discovery y spec-first

- Durante `discovery` y `spec-first` no edites código funcional del producto.
- Durante `discovery` y `spec-first` no escribas tests del producto ni refactors.
- Mantén visibles unknowns, conflictos y puntos no sustentados.

## Flujo `devbox-shell`

- El `flow-id` esperado para `devbox shell` es `devbox-shell`.
- La evidencia primaria del flujo vive en el repo, no en el chat.
- Para este flujo, el análisis debe centrarse en el entrypoint real del `shell` de `devbox.json` y sus handoffs relevantes.

## Verificación mínima

- Verifica que cada artefacto quede en la ruta correcta y no vacío cuando corresponda.
- Verifica que el contenido siga el schema de la fase antes de cerrar la etapa.

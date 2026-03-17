# Repo Guidance

## Scope

- Este repo usa memoria metodológica en `specs/flows/<flow-id>/`.
- Trabaja una fase a la vez. No mezcles discovery con diseño, implementación, evaluación o review.
- Durante discovery no se toca código del producto. Solo se permite bootstrap metodológico y artefactos de fase.

## Discovery

- Usa un `flow-id` corto, estable y específico por flujo.
- El artefacto principal de discovery vive en `specs/flows/<flow-id>/01-discovery.md`.
- El flujo debe quedar sustentado con evidencia rastreable del repo, comandos seguros y unknowns visibles.
- Si el flujo estudiado es de shell o bootstrap, inspecciona primero entrypoints declarativos como `devbox.json`, `Taskfile.yaml`, `README.md`, `bin/`, `lib/` y submódulos o carpetas auxiliares como `.devtools/`.

## Repo Notes

- `devbox shell` puede depender de `devbox.json`, de scripts localizados por búsqueda dinámica y del submódulo `.devtools/`.
- Prefiere validación estática o de baja intervención antes de ejecutar flujos con side effects.

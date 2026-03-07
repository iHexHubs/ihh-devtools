# Flow: git-acp.post-push

- maturity: discovery
- status: draft
- priority: active
- source-of-truth: this file
- related-tests:
  - tests/git_acp_post_push.bats

## Objetivo

Describir y madurar el flujo reusable que se ejecuta después del push exitoso de ACP
y que también puede ser invocado desde otros entrypoints del repo.

## 1. Discovery

### Entry point

Entry point funcional central:
- `lib/ci-workflow.sh::run_post_push_flow`

Entry points de activación observados:
- `bin/git-acp.sh`
- `bin/git-ci.sh`
- `bin/git-promote.sh`

### Dispatcher chain

- `bin/git-acp.sh` -> `run_post_push_flow "$current_branch" "$base_branch"`
- `bin/git-ci.sh` -> `run_post_push_flow "$CURRENT_BRANCH" "$BASE_BRANCH"`
- `bin/git-promote.sh` -> `POST_PUSH_FLOW=true run_post_push_flow "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" "local"`

### Camino feliz

Pendiente de cerrar con lectura completa de `run_post_push_flow`.

### Ramas importantes

- activación desde ACP normal
- activación desde `git-ci`
- activación desde `git-promote to-local`
- ramas internas del workflow aún pendientes de confirmar

### Side effects

Pendiente de cerrar con lectura del cuerpo del workflow.
Hay evidencia textual de que participa en validaciones de entorno y flujo CI/PR.

### Inputs

- branch actual
- branch base
- flag `POST_PUSH_FLOW=true` en algunos callers

### Outputs

Pendiente de confirmar:
- código de salida
- logging
- posibles acciones CI/PR

### Preconditions

Pendiente de confirmar.

### Error modes

Pendiente de confirmar.

### Archivos / funciones involucradas

Archivos ya confirmados:
- `bin/git-acp.sh`
- `bin/git-ci.sh`
- `bin/git-promote.sh`
- `lib/ci-workflow.sh`
- `lib/core/config.sh`
- `lib/core/contract.sh`

### Unknowns

- qué hace exactamente `run_post_push_flow`
- cuál es su primera decisión fuerte
- qué helpers llama
- qué side effects ejecuta realmente
- si el camino feliz depende de `.git-acprc`, entorno CI, PR o validaciones de host/branch
- si hay ramas legacy dentro del mismo workflow

### Sospechas de legacy / compatibility seams

- el flujo parece reusable y pudo crecer por acumulación de casos (`git-acp`, `git-ci`, `git-promote`)
- falta validar si las ramas compartidas siguen siendo núcleo o compatibilidad

### Evidencia

- `bin/git-acp.sh` comenta: “Si todo salió bien, ejecutamos el flujo post-push (CI/PR)”
- `bin/git-ci.sh` comenta: “Simulando post-push”
- `bin/git-promote.sh` comenta que reutiliza el mismo flujo post-push para verificación de entorno
- `lib/ci-workflow.sh` define `run_post_push_flow()`

### Promotion gate to spec-first

No promover hasta:
- leer el cuerpo completo de `run_post_push_flow`
- identificar helpers directos llamados
- reconstruir camino feliz y ramas principales
- confirmar side effects con una validación segura
# Constitución

## Propósito

Este repositorio documenta comportamiento por flujo, no solo por carpetas.
La meta es entender los flujos reales en Bash antes de cambiar código.

## Estructura canónica de documentos

- `README.md` se mantiene corto y convencional
- `AGENTS.md` define reglas de trabajo para agentes
- `specs/constitution.md` define reglas globales de documentación y madurez
- `specs/templates/*.md` define plantillas por etapa
- `specs/flows/*.md` define un archivo por flujo
- `tests/*.bats` valida comportamiento estable de flujos

## Nombres de flujos

Usar identificadores estables y descriptivos:

- `bootstrap.devbox-shell`
- `devtools.apps-sync`
- `git-promote.to-local`
- `git-acp.post-push`

## Modelo de madurez

Cada flujo progresa por estas etapas:

1. `discovery`
2. `spec-first`
3. `spec-anchored`
4. `spec-as-source`

Un flujo puede quedarse bastante tiempo en una etapa.
La promoción debe basarse en evidencia.

## Política de evidencia

No se debe documentar como hecho nada importante si no existe al menos una de estas evidencias:

- evidencia en código
- evidencia en comandos
- evidencia en tests
- evidencia por observación en ejecución

## Política de drift

Si documentación y código no coinciden:

1. documentar la diferencia
2. no “arreglar” la spec en silencio para encajar una suposición
3. identificar si la doc está vieja, el código es legacy o el contrato es ambiguo

## Política de tests

Cuando un flujo sea lo bastante estable para validarse, se debe agregar o actualizar cobertura con Bats.
Bats es el mecanismo de validación para flujos maduros.

## Política de legacy

Un código no es “legacy” solo porque se vea viejo.
Primero se marca como sospecha de legacy.
Solo se confirma cuando exista evidencia de que es:
- no usado
- solo de compatibilidad
- irrelevante para el camino feliz
- contradictorio con el contrato actual

## Prioridad actual del repo

El flujo prioritario para la adopción inicial es:

- `bootstrap.devbox-shell`

Los demás flujos pueden existir como placeholder, pero no están en promoción activa todavía.

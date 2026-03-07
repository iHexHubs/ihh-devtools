# Flow: <flow-id>

- maturity: discovery
- status: draft
- priority: backlog
- source-of-truth: this file
- related-tests:
  - tests/<flow-test>.bats

## Objetivo

Describir y madurar un flujo desde discovery hasta spec-as-source.

# Plantilla: discovery

## Propósito

Describir el flujo real observado sin inventar todavía el contrato.

## Secciones

### Flow id
`<flow-id>`

### Objetivo
Qué intenta lograr el usuario u operador.

### Entry point
Comando, script, función o archivo donde empieza el flujo.

### Dispatcher chain
Cadena ordenada de handoff desde la entrada hacia funciones o archivos más profundos.

### Camino feliz
Ruta normal observada, paso a paso.

### Ramas importantes
Flags, variables de entorno, bifurcaciones o rutas alternativas relevantes.

### Side effects
Git, red, sistema de archivos, subprocesos, cambios de entorno, etc.

### Inputs
Flags CLI, variables de entorno, archivos, config, supuestos sobre cwd.

### Outputs
Salida en consola, archivos creados, repos actualizados, exit codes, cambios de estado.

### Preconditions
Qué debe existir antes de correr el flujo.

### Error modes
Fallos conocidos u observados.

### Archivos y funciones involucradas
Listar solo las importantes.

### Unknowns
Qué todavía no está demostrado.

### Sospechas de legacy / seams de compatibilidad
Todo lo que parece tolerado pero no central.

### Evidencia
Referencias concretas:
- paths de archivos
- nombres de funciones
- comandos
- corridas observadas

### Criterio de salida para promover a spec-first
Qué falta aclarar antes de promover.

# Plantilla: spec-anchored

## Propósito

Amarrar el contrato intencional al codebase actual.

## Secciones

### Flow id
`<flow-id>`

### Resumen del contrato
Reformulación corta del comportamiento esperado.

### Code anchors
Mapa del contrato hacia la implementación actual:
- archivo
- función
- script
- path de config

### Mapeo del camino feliz
Dónde vive cada paso del camino feliz en el código.

### Mapeo de ramas
Dónde viven flags, fallbacks y rutas alternativas.

### Notas de drift
Dónde no coinciden por completo la spec y el código.

### Boundaries
Qué pertenece a este flujo y qué pertenece a flujos vecinos.

### Seams sospechosos de legacy
Código que parece de compatibilidad, opcional o heredado.

### Estado de validación
Qué ya es testeable y qué sigue siendo manual.

### Notas de seguridad para refactor
Qué no se debe romper si el código cambia después.

### Criterio de salida para promover a spec-as-source
Qué falta para que la spec pase a ser autoritativa.
# Plantilla: spec-as-source

## Propósito

Convertir la spec del flujo en la referencia autoritativa para cambios futuros.

## Secciones

### Flow id
`<flow-id>`

### Contrato canónico
Comportamiento autoritativo del flujo.

### Invariants obligatorios
Lo que siempre debe mantenerse.

### Inputs aceptados
Entradas y formatos soportados.

### Supuestos prohibidos
Cosas en las que los contribuidores no deben apoyarse.

### Resultados observables
Qué debe ocurrir desde afuera.

### Suite de aceptación
Qué tests Bats prueban el contrato.

### Protocolo de cambio
Cuando este flujo cambie:
1. actualizar primero la spec
2. actualizar después el código
3. actualizar después Bats
4. documentar drift o notas de migración

### Política de deprecación
Cómo tratar caminos de compatibilidad y comportamiento viejo.

### Notas de ownership
Quién revisa este flujo o qué experticia requiere.

### Historial de versión / revisión
Registrar cambios importantes del contrato.

## Promotion log
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

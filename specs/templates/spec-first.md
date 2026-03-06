# Plantilla: spec-first

## Propósito

Escribir el contrato intencional del flujo antes de cambiar comportamiento.

## Secciones

### Flow id
`<flow-id>`

### Intención
Qué debería garantizar el flujo.

### Contrato visible para el usuario
Qué puede asumir un usuario u operador.

### Preconditions
Setup requerido y supuestos.

### Inputs
Entradas aceptadas y sus formas válidas.

### Outputs
Resultados esperados y efectos observables.

### Invariants
Condiciones que deberían mantenerse siempre.

### Failure modes
Fallos esperados y su significado.

### No-goals
De qué no es responsable este flujo.

### Ejemplos
Ejemplos concretos de uso válido y resultado esperado.

### Acceptance candidates
Afirmaciones que deberían convertirse en tests Bats.

### Preguntas abiertas
Cualquier detalle contractual todavía no resuelto.

### Criterio de salida para promover a spec-anchored
Qué falta mapear contra el código real.

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

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

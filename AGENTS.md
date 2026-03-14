# AGENTS.md

## Reglas del proyecto
- Si un artefacto de etapa ya existe, no asumir que es correcto por existir; validarlo contra el repo y la evidencia actual antes de reutilizarlo.
- La memoria del proyecto vive en el repo.
- El rol o personalidad de los agentes no se define aquí; vive fuera del repo.
- Idioma obligatorio de análisis y artefactos: español.
- No cerrar ramas no verificadas por inferencia.
- Mantener separados:
  - evidencia observada,
  - inferencias,
  - validaciones pendientes.
- No ampliar alcance sin que el artefacto de la etapa anterior lo autorice.
- Priorizar cambios pequeños, verificables y reversibles.

## Regla por etapa
- Discovery:
  - separar siempre observado, inferido y no verificado;
  - declarar explícitamente el punto exacto donde termina la evidencia observada;
  - no modificar código salvo que la tarea pida explícitamente escribir el artefacto de discovery.
- Diseño:
  - convertir discovery aprobado en un diseño mínimo implementable;
  - fijar alcance, no-alcance, archivos probables a tocar y criterios de aceptación;
  - no rediseñar el sistema completo.
- Implementación:
  - implementar solo lo aprobado en diseño;
  - tocar el mínimo de archivos necesario;
  - no ampliar alcance.
- Evaluación:
  - validar el cambio contra diseño y diff actual;
  - no implementar cambios nuevos.
- Revisión:
  - comparar discovery, diseño, implementación, evaluación y diff final;
  - decidir aprobar o rechazar con razones explícitas.
  
## Rutas obligatorias para este flujo
- Discovery:
  `specs/flows/01-bootstrap.devbox-shell/01-discovery.md`
- Diseño:
  `specs/flows/01-bootstrap.devbox-shell/02-design.md`
- Implementación:
  `specs/flows/01-bootstrap.devbox-shell/03-implementation.md`
- Evaluación:
  `specs/flows/01-bootstrap.devbox-shell/04-evaluation.md`
- Revisión:
  `specs/flows/01-bootstrap.devbox-shell/05-review.md`

## Criterio metodológico
- Priorizar evidencia del repo, del diff y de la corrida observada.
- Registrar ramas abiertas, huecos y validaciones pendientes.
- La aprobación final depende de consistencia entre intención, artefactos y resultado.
# ADRs — ihh-devtools

Registro de decisiones arquitectónicas del toolset canónico.

## Convención
- Un archivo por decisión: `NNNN-<slug-kebab-case>.md`.
- Numeración secuencial sin huecos: 0001, 0002, 0003, …
- Estructura mínima: Estado · Contexto · Decisión · Consecuencias · Acciones.
- Una ADR aceptada es inmutable. Para cambiar una decisión, se escribe una
  ADR nueva que la supersede explícitamente.

## Estados posibles
- `Propuesto` — en discusión.
- `Aceptado` — aprobado y vinculante.
- `Superseded por NNNN` — reemplazado por otra ADR.
- `Descartado` — se consideró y se rechazó; se conserva por trazabilidad.

## Índice
- [0001 — Consolidación del toolset](./0001-devtools-consolidation.md) · Aceptado · 2026-04-24
- [0002 — Fuente de verdad de servicios y jerarquía de resolución](./0002-services-source-of-truth.md) · Aceptado · 2026-04-27
- [0003 — Método canónico de vendorización (P-AMBOS-3 opción C)](./0003-vendor-strategy.md) · Aceptado · 2026-04-25

## ADRs propuestos (sin escribir)
- 0004 — Estrategia para múltiples `.devtools/` en sub-apps (P-03).

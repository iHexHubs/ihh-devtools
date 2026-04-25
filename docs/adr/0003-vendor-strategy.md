# ADR 0003: Estrategia universal de vendorización (P-AMBOS-3 opción C)

## Status

Aceptada — 2026-04-25

## Context

El toolset `ihh-devtools` se vendoriza en consumidores como
directorio `.devtools/`. La estrategia actual (pre-v1.1) registra
solo un tag y un SHA en archivos sueltos (`VENDORED_TAG`,
`VENDORED_SHA`) y en `.devtools.lock` legacy. Esto produjo drift
verificado entre lo declarado y lo realmente vendorizado en al
menos un consumer (erd-ecosystem). El tag declarado en el lock no
existe en el origen canónico.

La sesión de evidencia (verificación P-AMBOS-3, 2026-04-25)
confirmó:

- `.devtools.lock` del consumer declara `v0.1.1-rc.1+build.40`,
  inexistente en `ihh-devtools`.
- `VENDORED_SHA` del consumer es `2e8cffbf…`, no presente como
  objeto git en el canónico.
- Comparado con el árbol del tag `v0.1.1` real del canónico, el
  consumer tiene 15 archivos extras (las 11 BATS del legado más
  metadatos) y le faltan 94 (todo `devbox-app/`).
- `vendorize.sh` es decorativo (33 líneas, no aplica el manifest).
- `apply_vendored_snapshot_from_repo_tag` extrae todo el árbol del
  tag con `git archive`, sin filtrar por manifest, sin trap, sin
  rollback automático.
- El productor solo conoce el formato legacy `.devtools.lock`
  bash key=value (variable `LEGACY_LOCK_FILE`). El formato YAML del
  schema v1 publicado en Fase 1 aún no se lee.
- `git describe --tags --abbrev=0` sin filtros devuelve un tag
  `backup/*` en ambos repos. Riesgo latente en cualquier código
  futuro que infiera versión por descripción.

## Decision

Adoptar la **opción C de P-AMBOS-3**: el lock registra
simultáneamente:

1. **Tag legible** (`vendor.ref`): para que humanos reconozcan la
   versión.
2. **Commit SHA** (`vendor.sha`): para reproducibilidad
   criptográfica del commit origen.
3. **Tree SHA** (`vendor.tree_sha`, opcional desde v1.1): para
   detectar drift local del contenido vendorizado.

Las tres piezas en un único archivo (`.devtools/lock` formato YAML
schema v1.1), no en archivos sueltos.

## Cierres formales asociados

### Decisión 1 — bump a schema v1.1

- Schema v1.1 añade `vendor.tree_sha` como campo opcional al lock.
- No breaking: locks v1.0 siguen válidos contra v1.1.
- `lock_version` y `contract_schema_version` siguen siendo `1`.
- `tree_sha` es opcional. La obligatoriedad efectiva la marca la
  versión del toolset que escribe el lock: toolset >= v0.2.0
  incluye `tree_sha`; versiones anteriores no.
- NO se reutiliza `integrity.digest` para este propósito:
  `integrity` es genérico (archivos individuales, paquetes), mientras
  `tree_sha` es semánticamente específico (objeto tree git).

### Decisión 2 — tag de referencia para erd-ecosystem

- Tag de referencia futuro recomendado: **`v0.1.0-rc.7`**.
- Es el tag más reciente ancestor del HEAD de `ihh/work`
  post-filtros (`--exclude='backup/*' --exclude='archived/*'`).
- `v0.1.1` queda descartado: existe pero no es ancestor del HEAD,
  apunta a una línea no activa.
- Sujeto a verificación de contenido en Fase 2C antes de
  re-vendorizar (verificar que el árbol de v0.1.0-rc.7 no contiene
  los `.tgz` espurios y compatibilidad con BATS migrado).

### Decisión 3 — P-AMBOS-4 diferida

- Las múltiples ubicaciones de `.devtools/` en sub-apps de
  erd-ecosystem (P-AMBOS-4) NO bloquean Fases 2A, 2B, 2C.
- Bloquean Fase 2D (escritura sobre consumer real) y Fase 5.
- Se documenta el alcance pero la política operativa se decide
  cuando llegue Fase 2D, con datos de Fase 2C en mano.

## Consequences

### Positivas

- Drift de origen y de contenido detectables automáticamente.
- Tag fantasma se rechaza en runtime sin requerir parche cosmético.
- Mutabilidad de tags mitigada por SHA registrado.
- Adopción simple para repos externos (declaran tag legible, el
  toolset registra todo).

### Negativas

- Implementación de Fase 2B más compleja que la estrategia anterior:
  requiere calcular `tree_sha` al vendorizar y al verificar.
- Latencia mínima añadida en operaciones que validan contenido.

## Lo que NO se hace

- NO se crea el tag fantasma `v0.1.1-rc.1+build.40` en ningún lado.
  Es propagar el bug a la fuente.
- NO se mueve el tag `v0.1.1` a HEAD con `git tag -f`. Sería
  reescribir historia compartida.
- NO se reescribe el `.devtools.lock` actual de erd-ecosystem
  cosméticamente. La resolución es operacional (re-vendorizado real
  en Fase 5), no documental.
- NO se usa `git describe --tags` sin filtros. La sesión de
  evidencia confirmó que devuelve tags `backup/*`. Cualquier código
  futuro que necesite descripción de versión usa
  `git describe --tags --abbrev=0 --exclude='backup/*' --exclude='archived/*'`
  o `git ls-remote --tags`.

## Implementación

- **Fase 2A (cerrada):** schema v1.1 publicado. Sin código.
- **Fase 2B (cerrada):** `lib/core/vendor.sh` implementado con las 5
  funciones públicas (`vendor_resolve_tag`, `vendor_compute_tree_sha`,
  `vendor_validate_lock`, `vendor_check_drift`, `vendor_is_excluded_tag`).
  Suite BATS en `tests/contracts/vendor.bats`. Sin invocación
  productiva todavía.
- **Fase 2C:** subcomando `vendor:check` solo lectura, primer
  contacto con erd-ecosystem.
- **Fase 2D:** primer re-vendorizado real bajo nueva estrategia.
  Bloqueada por P-AMBOS-4.
- **Fase 2E:** limpieza de drift y automatización estable.

# HANDOFF — ihh-devtools

> Punto de entrada rápido para sesiones nuevas. Resumen ejecutivo.
> Para detalle granular, ver `docs/project-state.md`.
>
> Última actualización: 2026-04-25
> Última fase cerrada: Fase 2B (commit `ddf04486`)
> Próxima fase recomendada: Fase 2C (requiere análisis previo).

## 1. Rol del repo

`ihh-devtools` es el **toolset canónico universal** del ecosistema.
Se vendoriza en repos consumidores como subdirectorio `.devtools/`.
Implementa flujos estandarizados de commits, promoción entre ramas,
SemVer, changelog y sync GitOps. El consumo se declara via schema
universal (`contract.yaml`); el toolset opera sin asumir nombre de
proyecto, lenguaje ni dominio.

NO es específico de PMBOK ni de iHexHubs. La identidad organizacional
en el contract (`identity.family`, `identity.domain`) es metadata,
no operativa.

## 2. Cómo continuar en nueva sesión

1. Leer este `HANDOFF.md` completo.
2. Leer `docs/project-state.md` para detalle granular.
3. Revisar ADRs relevantes:
   - `docs/adr/0001-devtools-consolidation.md`
   - `docs/adr/0003-vendor-strategy.md`
4. Leer `docs/schema-v1.md` (cara humana del schema v1 + v1.1).
5. NO saltar a Fase 2C sin análisis previo.
6. NO tocar erd-ecosystem desde este repo. Tiene su propio HANDOFF.

## 3. Alcance

### Dentro de alcance

- Schema universal (`schema/v1/`, `schema/v1.1/`).
- Validador de vendorización (`lib/core/vendor.sh`).
- Suite contractual (`tests/contracts/`).
- Documentación canónica (ADRs, schema docs, este HANDOFF,
  `docs/project-state.md`).

### Fuera de alcance

- Migración real de consumidores (vive en cada consumer).
- Resolución aislada del tag fantasma `v0.1.1-rc.1+build.40`.
- Movimiento del tag `v0.1.1`.
- Eliminación de hardcodings PMBOK (corresponde a Fase 3).
- Cambios cosméticos sin justificación.

## 4. Fases completadas

### Fase 1 — Schema universal v1 (commit `a1f66277`)

- **Objetivo:** publicar contrato técnico formal del consumidor.
- **Archivos principales:** `schema/v1/contract.json`,
  `schema/v1/lock.json`, `schema/v1/examples/*.yaml` (5 ejemplos),
  `docs/schema-v1.md`.
- **Validaciones:** JSON válido, JSON Schema válido contra Draft
  2020-12, ejemplos válidos pasan, ejemplo inválido falla con
  error legible.
- **Resultado:** schema universal publicado con
  `additionalProperties: false`, sin defaults retrocompatibles.
- **Fuera de alcance de la fase:** loader runtime, integración
  con consumer.

### Fase 2A — Schema v1.1 + ADR 0003 (commit `c8362767`)

- **Objetivo:** bumpar schema a v1.1 (no breaking) con
  `vendor.tree_sha` opcional + ADR formal de vendorización.
- **Archivos principales:** `schema/v1.1/contract.json`,
  `schema/v1.1/lock.json`, `schema/v1.1/examples/*.yaml`
  (2 ejemplos), `docs/adr/0003-vendor-strategy.md`,
  `docs/schema-v1.md` (sección 9).
- **Validaciones:** retrocompatibilidad confirmada (lock v1.0
  valida contra v1.1), ejemplos pasan, schema v1 preservado intacto.
- **Resultado:** base contractual de P-AMBOS-3 publicada. ADR
  documenta decisiones 1 (bump v1.1), 2 (tag de referencia
  `v0.1.0-rc.7`), 3 (P-AMBOS-4 diferida).
- **Fuera de alcance de la fase:** código que consuma el schema.

### Fase 2B — Validador dry-run (commit `ddf04486`)

- **Objetivo:** implementar librería bash testeada que valide tag,
  SHA y tree_sha contra fixtures controlados, sin invocación
  productiva.
- **Archivos principales:** `lib/core/vendor.sh` (5 funciones
  públicas), `tests/contracts/vendor.bats` (18 tests),
  `tests/contracts/fixtures/*.yaml` (5 fixtures).
- **Validaciones:** 18/18 tests BATS pasan, sintaxis bash OK,
  sin `git describe` sin filtros, sin hardcoding de dominios,
  sin operaciones destructivas, `task ci` exit 0.
- **Resultado:** librería operativa pero **sin invocación
  productiva**. Solo se invoca desde la suite BATS contra fixtures.
- **Fuera de alcance de la fase:** CLI, task expuesto, integración
  con `git-devtools-update.sh`, lectura de consumer real.

## 5. Decisiones cerradas

- **5.1** ihh-devtools será toolset universal, no específico-multi.
- **5.2** Schema declarativo obligatorio (`contract.yaml`).
- **5.3** Defaults explícitos con rampa asistida (3-4 sem
  preparación + 1 sem dry-run + cutover único + 1 sem soporte).
  Sin fallbacks legacy permanentes.
- **5.4** P-AMBOS-3 opción C: tag + SHA + `tree_sha` opcional.
- **5.5** Schema v1.1 con `tree_sha` opcional, no breaking.
- **5.6** NO crear el tag fantasma `v0.1.1-rc.1+build.40`.
- **5.7** NO mover el tag `v0.1.1`.
- **5.8** Tag de referencia futuro recomendado: `v0.1.0-rc.7`,
  sujeto a validación de contenido en Fase 2C.
- **5.9** P-AMBOS-4 diferida hasta Fase 2D. NO bloquea Fases 2A-2C.

## 6. Archivos clave actuales

| Path | Contenido | Estado |
|---|---|---|
| `schema/v1/contract.json` | Schema v1 del contract | publicado |
| `schema/v1/lock.json` | Schema v1 del lock | publicado |
| `schema/v1.1/contract.json` | Schema v1.1 (paridad funcional) | publicado |
| `schema/v1.1/lock.json` | Schema v1.1 con `tree_sha` opcional | publicado |
| `docs/schema-v1.md` | Cara humana del schema | publicado |
| `docs/adr/0001-devtools-consolidation.md` | ADR consolidación | aceptado |
| `docs/adr/0003-vendor-strategy.md` | ADR P-AMBOS-3 opción C | aceptado |
| `docs/adr/README.md` | Índice de ADRs | actualizado |
| `docs/project-state.md` | Estado detallado del proyecto | publicado |
| `lib/core/vendor.sh` | Validador dry-run (5 funciones) | publicado |
| `tests/contracts/vendor.bats` | Suite BATS (18 tests) | 18/18 pasa |
| `tests/contracts/fixtures/*.yaml` | Fixtures contractuales | publicados |

## 7. Qué valida Fase 2B

Funciones públicas en `lib/core/vendor.sh`:

- `vendor_resolve_tag <repo> <tag>`: confirma tag existe, devuelve
  commit SHA. Exit 4 si no existe, exit 7 si está excluido
  (`backup/*`, `archived/*`).
- `vendor_compute_tree_sha <directory>`: calcula tree SHA del
  directorio (debe ser repo git con HEAD).
- `vendor_validate_lock <lock_path>`: valida YAML contra
  `schema/v1.1/lock.json`. Exit 3 si schema falla.
- `vendor_check_drift <consumer_root> <source_repo>`: verifica
  consistencia tag/SHA/tree_sha. Exit 5 drift de referencia,
  exit 6 drift de contenido.
- `vendor_is_excluded_tag <tag>`: utility para excluir
  `backup/*` y `archived/*`.

Garantías comprobadas por la suite BATS:

- Tag existente resuelve, tag inexistente falla con error claro.
- Tags `backup/*` y `archived/*` excluidos.
- Tag fantasma falla.
- `tree_sha` opcional: locks sin él validan; locks con él
  exigen formato hex de 40 chars.
- Sin `git describe` sin filtros en código.
- Sin hardcoding de dominios.
- Sin operaciones destructivas.
- Modo dry-run: sin tocar consumidores reales.

## 8. Qué NO está integrado todavía

- Sin CLI final. No hay `bin/vendor-check.sh` ni binario expuesto.
- Sin task expuesto. `Taskfile.yaml` NO tiene `task vendor:check`.
- Sin integración con `git-devtools-update.sh`.
- Sin migración de erd-ecosystem.
- Sin modificación de `.devtools.lock` legacy.
- Sin resolución de P-AMBOS-4.
- Sin eliminación de hardcodings PMBOK.

## 9. Próximo paso recomendado

**Fase 2C** debe ser **integración controlada del validador**, no
implementación a ciegas. Antes del prompt:

1. Decidir strictness del validador (strict / lenient / permissive).
2. Decidir si el subcomando lee `.devtools.lock` legacy bash en
   paralelo al `.devtools/lock` YAML nuevo (recomendación previa: sí).
3. Decidir caso `git write-tree` cuando `.devtools/` no es repo git.

Después:

- `bin/vendor-check.sh` (entrypoint).
- `task vendor:check` en `Taskfile.yaml`.
- Suite BATS adicional.
- **Primer dry-run contra erd-ecosystem solo lectura.**

NO migrar erd-ecosystem todavía. NO tocar tag fantasma aislado.
NO tocar `.devtools.lock` cosméticamente.

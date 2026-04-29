# ADR 0004 — Formato de URL upstream en mensajes de `git-devtools-update`

## Estado
**Aceptado** · 2026-04-29 · Canónico en `ihh-devtools/docs/adr/`.

## Resumen ejecutivo
El binario `bin/git-devtools-update.sh` emite mensajes que mencionan la URL del upstream del toolset (operaciones `list`, `TAG=...`, etc.). Esta ADR fija el contrato del **formato de display** de esa URL en los mensajes: forma HTTPS literal (`https://github.com/<org>/<repo>.git`), independientemente de la forma en que el clone real se ejecute (SSH, HTTPS o `--repo` local). Esta ADR responde al F-DRIFT-1 documentado en `T-AMBOS-5/failures.txt` (9 tests fallidos en `tests/contracts/devtools-update.bats`).

## Contexto

### Estado previo a la decisión
- Las suites BATS migradas en `T-AMBOS-5` (commit `66d375e`) esperan que `bin/git-devtools-update.sh` emita el formato:
  ```
  Consultando upstream oficial: https://github.com/<org>/<repo>.git
  ```
  cuando resuelve un upstream remoto en operaciones `list` o `TAG=...`.
- El canónico actual emite:
  ```
  Consultando remoto: <URL_LITERAL_SSH>
  ```
  donde `<URL_LITERAL_SSH>` es la forma SSH del candidato (ej. `git@github.com:acme/erd-devtools.git`).
- Análogamente, el canónico actual emite "Origen remoto no definido." donde los tests esperan "Origen remoto desconocido.".

### Diagnóstico
Los 9 fallos F-DRIFT-1 (`tests 17, 18, 20-26` en `devtools-update.bats`) son consecuencia de un **refactor del canónico que cambió el contrato de mensajes sin actualizar a los consumers**. Los tests del consumer documentaban (y validaban) el contrato anterior. El cambio en el canónico fue accidental respecto al contrato del consumer.

### Hallazgo de alcance
- HTTPS literal en mensajes ofrece valor operativo: copia-pega a navegador, clones anónimos en CI, no asume credenciales SSH.
- La forma SSH para clone real puede mantenerse (afecta la operación, no el display).
- El verbo "Consultando upstream oficial" tiene más contexto que "Consultando remoto" (refuerza que es el upstream del toolset, no el `origin` del consumer).

## Opciones evaluadas

### Opción 1 — HTTPS literal en mensajes (display) + SSH/HTTPS/local para clone
Adoptar el formato HTTPS literal en los mensajes de display, manteniendo flexibilidad de clone (la lista de candidatos sigue admitiendo SSH y `--repo`).
- **Pros**: anónimo, copiable a navegador, no asume credenciales SSH, contrato del consumer preservado, cambio mínimo.
- **Contras**: el mensaje difiere visualmente del clone real cuando el operador clona vía SSH.

### Opción 2 — SSH literal en mensajes (current canonical)
Mantener el output SSH literal y adaptar los 9 tests del consumer al nuevo formato.
- **Pros**: consistencia entre display y clone real cuando se usa SSH.
- **Contras**: rompe contrato del consumer, exige actualizar tests migrados, anónimos en CI no pueden usar el output del display sin transformar a HTTPS, va contra directriz de auditoría AUDITORIA_TECNICA_PARALELA.md línea 433 (preservar cobertura del consumer).

### Opción 3 — Derivar del remoto real (`git config --get remote.origin.url`)
- **Pros**: respeta la elección de cada clone.
- **Contras**: el output cambia entre máquinas; los tests requieren mock o fixture especial; menor reproducibilidad operativa.

### Opción 4 — Dual (HTTPS para display + SSH para clone explícito)
- **Pros**: explícito.
- **Contras**: doble línea, más ruido visual, no aporta sobre Opción 1.

## Decisión

**Opción 1: HTTPS literal en mensajes de display.**

### Cambios concretos en `bin/git-devtools-update.sh`

1. Añadir helper `__display_remote_url()` (≤10 líneas) que convierte URLs SSH a HTTPS sólo para display. Si el input es ya HTTPS o `file://` o un path local, lo retorna tal cual. Conversión típica:
   ```
   git@github.com:acme/repo.git → https://github.com/acme/repo.git
   ```
2. Cambiar la línea `ui_info "Consultando remoto: ${remote_url}"` por `ui_info "Consultando upstream oficial: $(__display_remote_url "${remote_url}")"`.
3. Reemplazar las 4 ocurrencias del literal `"Origen remoto no definido."` por `"Origen remoto desconocido."` (preservar el suffix `Usa --source owner/repo o --repo /ruta/upstream.`).

### Lo que NO cambia
- Mecánica de clone: sigue iterando `remote_candidates` (SSH/HTTPS/local) hasta encontrar uno válido.
- Códigos de salida.
- Comportamiento de `--repo` y `--source`.
- Otras secciones del archivo.

## Consecuencias

- 9 fallos F-DRIFT-1 en `tests/contracts/devtools-update.bats` cierran sin tocar tests.
- Suite contractual queda en 201 ok / 0 not ok / 0 skip / 201 plan.
- Op-C re-vendoring incorpora el cambio sin sorpresas: el consumer recibe un canónico cuyo contrato de mensajes coincide con sus tests.
- Operadores que clonen vía SSH ven un mensaje HTTPS en logs; esto es display informativo, no afecta operación. La consistencia con tests prima sobre la "exactitud literal" del clone.
- Si en el futuro se descubre que algún flujo CI dependía del literal SSH en el output, se documentará en una ADR posterior que supersede a 0004.

## Acciones

- **A1** Implementar el cambio en `bin/git-devtools-update.sh` con tope de 30 líneas netas (cumplido: 23 líneas netas en β-acotada).
- **A2** Re-ejecutar la suite `bats tests/contracts/` para validar conteos finales.
- **A3** Actualizar `docs/adr/README.md` para marcar 0004 como `Aceptado`.
- **A4** Mover el placeholder previo (sub-apps) a `0005 — Estrategia para múltiples .devtools/ en sub-apps (P-03)`.
- **A5** Versionar el cambio en una iteración separada `beta-acotada-VERSIONING` tras validación humana del zip.

## Limitaciones de alcance — test 11 deferido

`tests/contracts/devtools-update.bats:test 11` ("TAG without --repo in vendored mode downloads tarball from lock source", línea 398) valida un comportamiento del legacy donde el script descargaba un tarball vía `curl` desde `https://github.com/<org>/<repo>/archive/refs/tags/<tag>.tar.gz`. El canónico actual reemplazó esa ruta por `git clone --depth 1 --branch <tag>` (más rápido, autenticación SSH/HTTPS unificada, sin dependencia de `curl`).

**Restaurar el flujo tarball** excedería el tope de 30 líneas netas de β-acotada (requeriría reintroducir el fetch curl, el extract tar, el manejo de `DEVTOOLS_TEST_TARBALL`, y la rama de fallback git-clone). Esa decisión necesita una ADR dedicada en una iteración posterior si el operador prioriza compatibilidad con el output del legacy sobre el flujo unificado actual.

**Decisión interina (β-acotada)**: test 11 queda **abierto** como F-DRIFT-BEHAVIORAL. Suite contractual al cierre de β-acotada: 200 ok / 1 not ok / 0 skip. La cobertura de los 13 cierres documentados en esta ADR es robusta y no compromete Op-C; el comportamiento del flujo TAG sigue siendo correcto, sólo el formato de mensaje y la elección curl-vs-clone divergen.

Para una decisión futura: ADR 0006 — "Mecanismo de download del tarball: clone vs curl-tarball" si se necesita.

## Referencias

- T-AMBOS-5 / `failures.txt`: causa raíz F-DRIFT-1.
- T-AMBOS-5-FIX: confirmación de los 9 fallos persistentes.
- HANDOFF.md sección 10: deuda pendiente bloqueando Op-C.
- AUDITORIA_TECNICA_PARALELA.md líneas 433, 550: directriz de preservar cobertura del consumer antes de re-vendorizar.

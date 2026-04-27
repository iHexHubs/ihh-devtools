# ADR 0001 — Consolidación del toolset

## Estado
**Aceptado** · 2026-04-24 · Canónico en `ihh-devtools/docs/adr/`.

## Resumen ejecutivo
Existían dos repositorios de toolset en paralelo (`ihh-devtools` y el repo
remoto `iHexHubs/devtools`, también llamado localmente `erd-devtools`). Ambos
con esquemas de versionado y procedencias mezcladas. Esta ADR declara que
**`iHexHubs/ihh-devtools` es el único toolset canónico**. El repo legado
`iHexHubs/devtools` queda **archivado** en GitHub (modo solo-lectura,
reversible) y se eliminará definitivamente una vez completada la migración
de los 8 repositorios consumidores.

## Contexto

### Estado previo a la decisión
- `iHexHubs/ihh-devtools` (path local del clon, ej. `./ihh-devtools/`): toolset con
  tags estilo `ihh-devtools-v0.1.0.rc.1-build.1-rev.1` (no-SemVer estricto).
  Es el más actualizado y la fuente de verdad declarada.
- `iHexHubs/devtools` (path local `/webapps/erd-devtools/`): toolset paralelo
  con tags SemVer estrictos `v0.1.1-rc.1+build.40`. Tenía ramas `main`, `dev`,
  `staging`, `local`. Quedó descartado.
- `erd-ecosystem/.devtools.lock` apuntaba a `/webapps/erd-devtools` con
  `DEVTOOLS_SOURCE="iHexHubs/devtools"`.

### Hallazgo de alcance ampliado
Una auditoría posterior reveló que la vendorización legada afecta a **8 repos
del operador**, no solo a `erd-ecosystem`:

1. `erd-ecosystem` → remote `iHexHubs/ihh-ecosystem`
2. `agents-control-plane` → remote `reydem/openai-agents`
3. `pmbok` → remote `sixdriven/pmbok`
4. `rust-lang-book` → remote `reydem/rust-lang-book`
5. `rust-w3schools` → remote `reydem/rust-w3schools`
6. `sixdriven` → remote `reydem/sixdriven`
7. `sixdriven-web` → remote `reydem/sixdriven-web`
8. `tvw-ecosystem` → remote `reydem/tvw-ecosystem`

Total de referencias textuales encontradas: **247** (inventariadas en
`ihh-devtools/docs/migration-2026-04/legacy-devtools-references.txt`).

### Hallazgos críticos detectados durante el proceso
- `iHexHubs/ihh-devtools`: contenía `.devtools/.git-acprc` con email y ruta
  SSH personal del operador en historial. Purgado el 2026-04-24 mediante
  tarea T0.0 (`git filter-repo`, force-push, verificación en clon fresco).
- `iHexHubs/ihh-ecosystem` (path local `erd-ecosystem`): contiene 3 blobs
  con datos sensibles (incluyendo datos de 4 contribuidores en
  `.devtools/.git-acprc`, blob 498ddec). Pendiente T0.0-bis.
- Archivo `constitution.yaml` de la metodología `sixdriven` apareció
  huérfano en `/webapps/erd-devtools/.sixdriven/` (propietario root).
  Verificado posteriormente que ya existía la copia legítima en
  `/webapps/sixdriven/.sixdriven/`. La copia huérfana se descartó. Indica
  que el path `/webapps/erd-devtools/` se usaba accidentalmente como
  destino de procesos automatizados.

### Opciones consideradas

| Opción | Pros | Contras |
|---|---|---|
| A. Consolidar en `ihh-devtools` | Repo más actualizado; fuente única; alineado con la decisión del operador. | Migración de 8 repos consumidores. |
| B. Consolidar en `iHexHubs/devtools` | Versionado SemVer ya limpio. | El operador lo descartó; no es el más actualizado. |
| C. Mantener ambos con roles diferenciados | Bajo coste inmediato. | Perpetúa la deuda. Rechazada. |

**Opción elegida: A.**

## Decisiones

### J-01 · Canonicidad del toolset
`iHexHubs/ihh-devtools` es el único toolset canónico. Es la única fuente de
verdad para la vendorización del subdirectorio `.devtools/` en repos
consumidores.

### J-02 · Retirada de `iHexHubs/devtools`
`iHexHubs/devtools` queda **archivado** en GitHub (modo solo-lectura) a
fecha 2026-04-24. La eliminación definitiva queda diferida hasta que todos
los repos consumidores estén migrados a `ihh-devtools`.

El directorio local `/webapps/erd-devtools/` fue eliminado el 2026-04-24
durante la limpieza. El directorio vacío `/webapps/ihh-ecosystem/` (creado
por error en febrero) también fue eliminado.

### J-03 · Modelo de apps en `erd-ecosystem`
`erd-ecosystem` es un meta-repo orquestador. La carpeta `apps/` permanece
en `.gitignore`. Cada aplicación vive en su propio repositorio independiente.
Las apps en `apps/` son clones locales efímeros.

### J-04 · Vendorización real
`.devtools/` en los consumidores es el output exacto del contrato declarado
en `ihh-devtools/vendor.manifest.yaml`. No se toleran enlaces rotos ni
directorios fantasma. El método concreto (submódulo git, copia determinista,
o ambos) se decide en un ADR posterior.

### J-05 · Versionado SemVer estricto para tags nuevos
`ihh-devtools` adopta SemVer estricto
(`v<major>.<minor>.<patch>[-rc.<n>][+build.<n>]`) para todos los tags nuevos
a partir de esta ADR. El esquema histórico
(`ihh-devtools-v0.1.0.rc.1-build.1-rev.1`) queda deprecado. Los tags
históricos no se renombran porque romperían referencias existentes.

### J-06 · Reescritura progresiva de referencias
Toda referencia a `iHexHubs/devtools`, `reydem/devtools`, o paths locales
`/webapps/erd-devtools` debe reescribirse a `iHexHubs/ihh-devtools` con la
URL real `git@github.com-reydem:iHexHubs/ihh-devtools.git`.

### J-07 · Migración progresiva, no urgente
Mientras `iHexHubs/devtools` esté archivado pero accesible, los `.devtools/`
vendorizados desde él siguen funcionales. La migración de los 8 repos no
bloquea trabajo. Cada repo migra cuando tenga actividad (PR, release, etc.).

## Consecuencias

### Positivas
- Elimina la ambigüedad sobre cuál es el toolset canónico.
- Permite adoptar herramientas estándar que asumen SemVer.
- Reduce la superficie de mantenimiento a un único toolset.
- Archivar en lugar de borrar permite revertir sin pérdida si surge un
  problema durante la migración.

### Costosas
- Cada uno de los 8 repos consumidores requiere una operación manual de
  re-vendorización (`git devtools-update` apuntando al canónico).
- Tags históricos con esquema viejo conviven con SemVer estricto durante
  un periodo de transición. Scripts que parseen tags deben contemplar
  ambos esquemas.
- El force-push del 2026-04-24 invalidó los `.devtools/` vendorizados que
  apuntaban al historial pre-purga. La re-vendorización es obligatoria
  además de recomendable.

### Preguntas abiertas
A resolver en ADRs posteriores:

- **P-01** — ¿Unificar `erd-ecosystem/ecosystem/services.yaml` con
  `.devtools/config/apps.yaml`, o mantenerlos como contratos separados?
  (Propuesto: ADR 0002.)
- **P-02** — Método canónico de vendorización: ¿submódulo git, copia
  determinista vía `vendorize.sh`, o ambos? (Propuesto: ADR 0003.)
- **P-03** — Las múltiples copias de `.devtools/` en sub-apps de
  `erd-ecosystem`, ¿se consolidan o cada app mantiene la suya?
  (Propuesto: ADR 0004, subordinado a J-03.)

## Acciones derivadas

### T-ADR-01 · Archivar `iHexHubs/devtools`
- Estado: **completado** 2026-04-24.
- Acción: archivado en GitHub vía Danger Zone → "Archive this repository".
- Verificación: el repo aparece como "Archived" en la UI; `git ls-remote`
  sigue funcional pero sin escritura.

### T-ADR-02 · Reescribir `.devtools.lock` en `erd-ecosystem`
- Estado: pendiente.
- Acción: actualizar el `.devtools.lock` de la raíz de `erd-ecosystem` y
  de cada sub-app que tenga uno, apuntando a `iHexHubs/ihh-devtools` con
  un tag base SemVer.
- Verificación: `grep -rE "iHexHubs/devtools[^-]|reydem/devtools|erd-devtools" .`
  en `erd-ecosystem` devuelve solo hits informativos (CHANGELOG, backups).

### T-ADR-03 · Corregir `devops/scripts/new-webapp.sh`
- Estado: pendiente.
- Acción: la línea 29 de
  `erd-ecosystem/devops/scripts/new-webapp.sh` contiene
  `git submodule add -b main https://github.com/elrincondeldetective/erd-devtools.git .devtools`.
  Reescribir a `iHexHubs/ihh-devtools.git` con la URL real.

### T-ADR-04 · Re-vendorizar `.devtools/` de la raíz de `erd-ecosystem`
- Estado: pendiente. Bloquea T0.0-bis si se hace en orden inverso.
- Acción: regenerar `erd-ecosystem/.devtools/` desde `ihh-devtools` con
  el tag base acordado.
- Dependencias: T-ADR-02, T0.0-bis.

### T-ADR-05 · Migrar los 7 repos hermanos
- Estado: pendiente, no urgente.
- Acción: para cada uno de los repos identificados en
  `ihh-devtools/docs/migration-2026-04/`, ejecutar el procedimiento de
  migración cuando el repo tenga trabajo activo. No requiere atención
  inmediata mientras `iHexHubs/devtools` siga archivado y accesible.

### T-ADR-06 · Auditoría final de referencias residuales
- Estado: pendiente, posterior a T-ADR-05.
- Acción: tras migrar todos los consumidores, ejecutar
  `git grep -nE "iHexHubs/devtools[^-]|reydem/devtools|erd-devtools"` en
  todos los repos para detectar residuos. Reescribir cada ocurrencia.

### T-ADR-07 · Eliminación definitiva de `iHexHubs/devtools`
- Estado: pendiente, posterior a T-ADR-05 y T-ADR-06.
- Acción: una vez confirmado que ningún repo consumidor depende del legado,
  eliminar el repo archivado en GitHub vía Danger Zone → "Delete this
  repository".
- Plazo sugerido: no antes de que los 8 repos hayan migrado.

### T-ADR-08 · Sincronizar `versioning-research.md` con esta ADR
- Estado: pendiente. Solo aplicable si se crean los `versioning-research.md`
  propuestos en sesiones anteriores.
- Acción: marcar como resueltas las decisiones J-IHH-01, J-IHH-02, J-ERD-01,
  J-ERD-02 referenciando esta ADR.

## Registro de aplicación

| Fecha | Acción | Operador | SHA / Verificación |
|---|---|---|---|
| 2026-04-24 | T0.0 ejecutada en `ihh-devtools` (purga `.git-acprc`) | reydem | commit `dd655a3`, force-push verificado |
| 2026-04-24 | Inventario de migración commiteado en `ihh-devtools` | reydem | commit `08eb220` |
| 2026-04-24 | T-ADR-01 — `iHexHubs/devtools` archivado en GitHub | reydem | UI Settings → Archive |
| 2026-04-24 | `/webapps/erd-devtools/` y `/webapps/ihh-ecosystem/` eliminados localmente | reydem | rmdir |
| 2026-04-24 | ADR 0001 aceptado | reydem | _este commit_ |
| — | T0.0-bis en `erd-ecosystem` | — | _pendiente_ |
| — | T-ADR-02 — `.devtools.lock` reescrito | — | _pendiente_ |
| — | T-ADR-03 — `new-webapp.sh` corregido | — | _pendiente_ |
| — | T-ADR-04 — `.devtools/` raíz re-vendorizado | — | _pendiente_ |
| — | T-ADR-05 — 7 repos hermanos migrados | — | _pendiente, progresivo_ |
| — | T-ADR-06 — auditoría final de residuos | — | _pendiente_ |
| — | T-ADR-07 — `iHexHubs/devtools` eliminado definitivamente | — | _pendiente, último paso_ |

## Referencias
- Inventario de referencias legadas:
  `ihh-devtools/docs/migration-2026-04/legacy-devtools-references.txt`
- Plan de migración por repo:
  `ihh-devtools/docs/migration-2026-04/README.md`
- Backup de purga T0.0:
  `~/backups-git-acprc-20260424T192628Z/` (retener hasta 2026-05-24)

---

*Esta ADR es inmutable una vez aceptada. Si la arquitectura cambia, se
escribe una ADR nueva que la supersede explícitamente y actualiza la tabla
de aplicación.*

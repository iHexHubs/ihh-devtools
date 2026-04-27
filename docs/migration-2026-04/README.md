# Migración desde iHexHubs/devtools (legado)

## Contexto

El 24 de abril de 2026 se decidió consolidar el toolset en `ihh-devtools`.
El repo legado `iHexHubs/devtools` (local: `/webapps/erd-devtools/`) quedó 
descartado y archivado en GitHub.

Esta carpeta documenta las referencias al toolset legado que existen en el 
sistema a fecha de la migración. Sirve como mapa para migraciones progresivas.

## Archivos

- `legacy-devtools-references.txt`: 247 hits encontrados en `/webapps/` con 
  `grep -rEn "erd-devtools|reydem/devtools|iHexHubs/devtools[^-]"`.
  Excluye `node_modules`, `.devbox`, `.git`, `venv`.

## Distribución

| Categoría | Hits | Estrategia |
|---|---|---|
| `.devtools.lock` (config viva) | 6 | Editar manualmente el `.lock` y apuntar a ihh-devtools. |
| `.devtools.bak.*` (backups) | 17 | Borrar el directorio de backup. |
| `.devtools/` vendorizado | 214 | Re-vendorizar cada repo con `git devtools-update`. |
| Otros (CHANGELOG + scripts) | 10 | CHANGELOG no se toca (historia). Scripts se editan. |

## Repos afectados (8)

Todos son repos del operador. Migrar cuando cada uno tenga trabajo activo:

1. `erd-ecosystem` (iHexHubs/ihh-ecosystem) — prioridad, es el meta-repo.
2. `agents-control-plane` (reydem/openai-agents)
3. `pmbok` (sixdriven/pmbok)
4. `rust-lang-book` (reydem/rust-lang-book)
5. `rust-w3schools` (reydem/rust-w3schools)
6. `sixdriven` (reydem/sixdriven)
7. `sixdriven-web` (reydem/sixdriven-web)
8. `tvw-ecosystem` (reydem/tvw-ecosystem)

## Plan de migración por repo

Para cada repo N:
1. Verificar que ningún cambio local pendiente.
2. Actualizar `.devtools.lock`:
   - `DEVTOOLS_SOURCE="iHexHubs/ihh-devtools"`
   - `DEVTOOLS_REPO="${DEVTOOLS_REPO:-/path/to/ihh-devtools}"` (ajustar al path local del clon, o usar URL remota si aplica).
3. Ejecutar `git devtools-update` para re-vendorizar `.devtools/` desde el canónico.
4. Borrar `.devtools.bak.*` si existe.
5. Probar que los comandos `git acp`, `git promote`, etc. funcionan.
6. Commit y push.

Esta migración NO es urgente mientras el repo legado siga archivado y 
accesible en GitHub. Cada repo se migra cuando tenga cambios activos.

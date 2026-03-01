# CHANGELOG

## v0.1.2-rc.6+build.1



### Correcciones

- empuja rama fuente y maneja rc de estrategia al promover a `dev`

- fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`
fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`

📅 Fecha: 2026-02-09 07:15

Conteo: commit #17

- muestra menú post-push en cualquier rama NO protegida

- fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`
fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`

📅 Fecha: 2026-02-09 06:45

Conteo: commit #11

- fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`
fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`

📅 Fecha: 2026-02-09 06:39

Conteo: commit #10

- fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`
fix(devtools): corrige encabezado de reporte diario en `.devtools/bin/git-acp.sh`

📅 Fecha: 2026-02-09 06:37

Conteo: commit #7

- evitar borrar la rama origen si no aterriza en destino

- fix(promote): validar .promote_tag como cache y mantener compatibilidad
fix(promote): validar .promote_tag como cache y mantener compatibilidad

📅 Fecha: 2026-02-08 16:43

Conteo: commit #42

- excluir `chore(release): actualizar changelog` del resumen y prompt de notas


### Documentación

- ajustar encabezado de sección en `hotfix.sh`

- ajustar encabezado de sección en `hotfix.sh`

- ajustar encabezado de sección en `hotfix.sh`

- corregir comentario de salida en `.devtools/bin/git-gp.sh`

- normalizar encabezado de sección en `hotfix.sh`

- ajustar encabezado de sección en `hotfix.sh`


### Funciones

- exporta tag de imagen y acepta `+build` como legado


### Mantenimiento

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.6+build.1

- actualizar changelog v0.1.2-rc.5+build.1

- actualizar changelog v0.1.2-rc.5+build.1

- actualizar changelog v0.1.2-rc.5+build.1

- actualizar changelog v0.1.2-rc.5+build.1

## v0.1.2-rc.5



### Correcciones

- priorizar tags de `origin` y estabilizar estrategia de `dev` cuando hay `rc` activo

- calcular rango de changelog en `to-dev.sh` usando `dev` cuando coincide con `source_sha`


### Mantenimiento

- actualizar changelog v0.1.2-rc.4+build.1

- actualizar changelog v0.1.3-rc.1+build.1

## v0.1.2-rc.4



### Correcciones

- limpiar entradas duplicadas de `v0.2.0-rc.1+build.1` en `CHANGELOG.md` y `.devtools/CHANGELOG.md`


### Funciones

- generar tag de `prod` como estable sin `rc` ni `+build` desde el último `staging`


### Mantenimiento

- actualizar changelog v0.2.0-rc.1+build.1

## v0.1.2-rc.3



### CI

- crear script `git-release-draft.sh` para crear/actualizar releases draft por tag

- deshabilitar Release Please renombrando configs y workflows a `.disabled`

- deshabilitar `release-please` y documentar fuente única de `VERSION`


### Correcciones

- inferir `TAG_PREFIX` desde `.promote_tag` antes de calcular `final_tag` en `to-staging.sh`

- permitir prefijo `release-please--*` en `gh-policy-check.sh`

- reemplazar `rg` por `grep` y escanear workflows sin `ripgrep`

- evitar fallo de `yq` al resolver `APP` usando `strenv(NEEDLE)`

- exigir `+build` en `to-staging.sh`

- unificar ruta de `.promote_tag` con `promote_tag_file_path`

- evitar colisiones de `build_number` usando `.promote_tag`

- forzar incremento de `rc.N` sobre `base_ver` cuando ya existe RC pendiente

- detectar rango vacío con `git rev-list --count` y robustecer subjects

- extraer correctamente `rc.N` al calcular el siguiente tag en `semver_next_rc`

- fix(devtools): permitir `feat/*` y relajar enforcement de renombre en `git-flow.sh`
fix(devtools): permitir `feat/*` y relajar enforcement de renombre en `git-flow.sh`

📅 Fecha: 2026-02-06 16:34

Conteo: commit #43


### Documentación

- documentar flujo actual de tags en `.devtools/notes/tag-flow.md`

- docs(release): corregir comentario de estrategia de tags en `.devtools/lib/promote/version-strategy.sh`
docs(release): corregir comentario de estrategia de tags en `.devtools/lib/promote/version-strategy.sh`

📅 Fecha: 2026-02-07 21:48

Conteo: commit #97

- documentar matriz de build `build_matrix` y reflejarla en `.devtools/config/apps.yaml`

- ajustar encabezado de changelog en `common.sh`

- ajustar comentario de sección de changelog en `common.sh`

- documentar monorepo y matriz de versionado en .devtools/README.md


### Funciones

- generar tag de `staging` como `rc` sin `+build` a partir del último `dev`

- calcular `rc`/`build` de `dev` a partir del último tag en `staging` y `dev`

- priorizar tags remotos con `git ls-remote` para calcular `rc`/`build` y último estable

- permitir update vendorizado y consolidar estrategia de tags por entorno

- crear releases draft en GitHub desde `git promote` (staging/prod/hotfix)

- soportar prefijo de tag por app y sufijo `+build` en promote

- soportar CI por componentes en `apps.yaml`

- agregar parser del registro `apps.yaml` y tareas `task app:*`

- registrar apps y bootstrap de `apps/erd/mobile`

- validar policy de GitHub Actions y bloquear tagging/versionado en workflows

- permitir override interactivo del tag sugerido por `.promote_tag`

- generar y commitear changelog por componente durante `git promote`

- mostrar resumen y `git diff --stat` en modo `--dry-run` para `to-staging.sh`, `to-prod.sh` y `hotfix.sh`

- agregar pre-check de reconciliación `main -> staging -> dev` con `git fetch` y validaciones de ancestro

- mostrar `render_commit_diff_panel` para comparación `main` vs `hotfix/*`

- agregar UI interactiva y sync a `staging` en `finish_hotfix`

- publicar release final en GitHub desde tag `vX.Y.Z`

- agregar UI interactiva para versión final y notas en `to-prod.sh`

- publicar pre-release en GitHub desde tag `vX.Y.Z-rc.N`

- agregar UI interactiva para tag RC y notas en `to-staging.sh`

- renderizar panel de comparación con `ui_card` en `render_commit_diff_panel`

- mostrar panel de comparación de commits en `git promote` (modo TTY)

- agregar resumen de commits por tipo y scope en `generate_ai_prompt`

- agregar `--dry-run` y cálculo de versión sin cambios en `git promote`

- resolver último tag estable en `main` con fallback de arranque

- extraer helpers a `semver.sh` y reutilizarlos en `release-flow.sh`

- integrar herramientas de desarrollo git-acp pro y ajustar flujo de release-please


### Mantenimiento

- actualizar changelog v0.2.0-rc.1+build.1

- actualizar changelog v0.2.0-rc.1+build.1

- actualizar changelog v0.2.0-rc.1+build.1

- actualizar changelog v0.1.3-rc.1+build.3

- actualizar changelog v0.1.3-rc.1+build.2

- actualizar changelog v0.1.3-rc.1+build.1

- actualizar `staging.md` y agregar regla en `.gitignore`

- deshabilitar workflows de tagging moviéndolos a `.disabled`

- actualizar changelog v0.4.0-rc.2

- actualizar changelog v0.4.1-rc.1

- actualizar changelog v0.4.1-rc.1

- actualizar changelog v0.4.1-rc.1

- actualizar changelog v0.4.1-rc.1

- actualizar changelog v0.4.1-rc.1

- añadir `git-cliff@latest` a la toolchain en `devbox.json`

- eliminar macro `sync` y retirar `git-sync.sh` del flujo de `git-promote.sh`

- revertir patrón `....` en `/.devtools/.gitignore`

- ajustar reglas en `/.devtools/.gitignore`

- integrar .devtools como subtree


### Refactor

- seleccionar último tag por entorno sin depender de `sort -V`

- migrar scripts de herramientas a submódulos de git



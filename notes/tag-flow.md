# Flujo actual de tags y lanzamientos (estado actual)

## Punto de entrada y ruteo
- Archivo: `<vendor_dir>/bin/git-promote.sh`.
- Carga: `release-flow.sh`, `promote/version-strategy.sh`, `workflows/common.sh`.
- Enruta a: `promote_to_dev`, `promote_to_staging`, `promote_to_prod`, `promote_hotfix_start`.

## Calculo de tags (logica actual)
- Archivo: `<vendor_dir>/lib/promote/version-strategy.sh`.
- Funciones clave: `promote_next_tag_dev`, `promote_next_tag_staging`, `promote_next_tag_prod`.
- Fuente inmediata: `promote_last_tag_or_empty` lee `.promote_tag`.
- Alternativa: `get_last_stable_tag` y helpers `semver_*`, `next_rc_number`, `next_build_number`.
- Prefijo: `promote_infer_tag_prefix_from_tag` usa `[APP]-`.

## Semver y arranque
- Archivo: `<vendor_dir>/lib/core/semver.sh`.
- Parseo y formato: `semver_parse_tag`, `semver_format_tag`.
- RC/build: `semver_next_rc`, `semver_next_build` usan `git tag -l` y `git fetch origin --tags`.
- Ultimo estable: `semver_last_stable_tag`, `semver_last_stable_tag_or_bootstrap`.
- Arranque: `semver_bootstrap_tag` usa `SEMVER_BOOTSTRAP_VERSION` (por defecto `0.1.0`).

## Uso de rangos para calculo
- DEV: `<vendor_dir>/lib/promote/workflows/to-dev.sh` usa rango `origin/staging..source_sha` para `promote_next_tag_dev`.
- STAGING: `<vendor_dir>/lib/promote/workflows/to-staging.sh` usa rango `origin/staging..dev` para `promote_next_tag_staging`.
- PROD: `<vendor_dir>/lib/promote/workflows/to-prod.sh` usa `promote_next_tag_prod` (sin rango).

## Persistencia de .promote_tag (almacen temporal)
- Ruta: `<vendor_dir>/lib/promote/version-strategy.sh` -> `promote_tag_file_path`.
- Lectura: `promote_last_tag_or_empty` (version-strategy).
- Escritura en DEV: `<vendor_dir>/lib/promote/workflows/to-dev.sh`.
- Lectura y re-escritura en STAGING: `<vendor_dir>/lib/promote/workflows/to-staging.sh`.
- Lectura y re-escritura en PROD: `<vendor_dir>/lib/promote/workflows/to-prod.sh`.
- Lectura en HOTFIX: `<vendor_dir>/lib/promote/workflows/hotfix.sh`.

## Notas de lanzamiento (.md)
- STAGING: `<vendor_dir>/releases/staging.md` generado en `to-staging.sh`.
- PROD: `<vendor_dir>/releases/prod.md` generado en `to-prod.sh`.
- HOTFIX: `<vendor_dir>/releases/hotfix.md` generado en `hotfix.sh`.
- Helpers: `capture_release_notes` y `prepend_release_notes_header` en `<vendor_dir>/lib/release-flow.sh`.

## Creacion de tags y lanzamientos en GitHub
- Archivo: `<vendor_dir>/lib/promote/helpers/gh-interactions.sh`.
- Funciones: `gh_create_prerelease_draft_from_tag`, `gh_create_prerelease_from_tag`, `gh_create_release_draft_from_tag`, `gh_create_release_from_tag`.
- Comportamiento: verifica tag remoto con `git ls-remote --tags`, crea tag anotado con `git tag -a`, hace `git push` del tag, y crea lanzamiento con `gh release create`.
- Llamadas desde: `to-staging.sh` (prelanzamiento) y `to-prod.sh` (lanzamiento final).

## Dueño de tags en staging/prod
- La decisión se resuelve en `promote_resolve_tag_owner_for_env` (`version-strategy.sh`).
- Si detecta workflow de tagging del entorno: `Owner tags = GitHub | Razón = workflow`.
- Si no detecta workflow: `Owner tags = Local | Razón = workflow`.
- Overrides soportados:
- `DEVTOOLS_FORCE_LOCAL_TAGS=1` -> `Owner tags = Local | Razón = override:DEVTOOLS_FORCE_LOCAL_TAGS`
- `DEVTOOLS_DISABLE_GH_TAGGER=1` -> `Owner tags = Local | Razón = override:DEVTOOLS_DISABLE_GH_TAGGER`
- En `to-staging.sh` y `to-prod.sh`, el log aparece una vez por ejecución.
- Cuando `Owner tags = GitHub`, el flujo local omite creación/push local de tag.

## Changelog (commit de lanzamiento)
- Archivo: `<vendor_dir>/lib/promote/workflows/common.sh`.
- Funcion: `prepare_changelog_commit` genera changelog con `git-cliff` y crea commit `chore(release): actualizar changelog <tag>`.

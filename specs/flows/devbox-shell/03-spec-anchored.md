## Estado de cierre de la fase
- Flow id: `devbox-shell`
- Estado global del anclaje: `listo con reservas`
- Pregunta de anclaje principal resuelta: `si`
- Juicio provisional: `el contrato inicial ya puede mapearse con claridad al codigo real y deja base suficiente para spec-as-source`

# Flow id
`devbox-shell`

# Intencion contractual de referencia
- Referencia funcional: entrada local `devbox shell` gobernada por el repo y subfrontera `devbox shell --print-env` consumible por workflows internos.
- Clausulas relevantes de `02-spec-first.md`:
  - resolver root y contrato antes del wizard;
  - gate estricto cuando hay marker + TTY;
  - no presentar la sesion como lista/contextualizada si la verificacion falla;
  - mantener `print-env` util para consumidores no interactivos.
- Limites de fase:
  - anclar contrato al codigo real;
  - no redisenar el flujo;
  - no abrir aun la adopcion contractual materializada.

# Entry point real anclado
- **Anclaje claro:** `devbox.json` contiene el `shell.init_hook` que actua como punto repo-controlado inicial del flujo.
- **Evidencia:** `devbox.json` lineas 45-148.
- **Entrypoint contractual vs real:** el comando visible es `devbox shell` (externo), pero la primera superficie editable del repo es `devbox.json:shell.init_hook`.
- **Subfrontera anclada:** `lib/promote/workflows/common.sh` usa `devbox shell --print-env` como consumer fallback (`common.sh` lineas 215-227).

# Dispatcher chain real anclada
- **Anclaje claro:** `devbox.json` lineas 48-55 resuelven `top`, `sp`, `root` y la posible rama de submodulo.
- **Anclaje claro:** `devbox.json` lineas 52-55 y 108-126 separan variante estricta y permisiva.
- **Anclaje claro:** `devbox.json` lineas 71-100 preparan PATH y overlay efimera de `GIT_CONFIG_*`.
- **Anclaje claro:** `devbox.json` lineas 102-147 delegan al wizard, controlan `DEVBOX_SESSION_READY` y cierran con bienvenida/rol/prompt.
- **Anclaje claro:** `bin/setup-wizard.sh` lineas 19-49 carga utils/git-ops/contract/config antes de validar.
- **Anclaje claro:** `bin/setup-wizard.sh` lineas 73-117 parsea `--verify-only`/`--force`, ajusta por TTY y exige repo/herramientas.
- **Anclaje claro:** `bin/setup-wizard.sh` lineas 122-182 implementan verify-only con GH CLI y SSH.
- **Anclaje parcial:** `devbox shell --print-env` observado no expuso `GIT_CONFIG_COUNT` ni `DEVBOX_SESSION_READY`; la subfrontera existe, pero no replica todo lo observable del `init_hook` interactivo.

# Mapa de camino feliz
- Paso 1. `devbox shell` lee `devbox.json`.
  - Clasificacion: `anclaje claro`
  - Soporte: `devbox.json` lineas 45-55
- Paso 2. El flujo resuelve root y variante.
  - Clasificacion: `anclaje claro`
  - Soporte: `devbox.json` lineas 48-55
- Paso 3. El flujo prepara overlay efimera para herramientas corporativas.
  - Clasificacion: `anclaje claro`
  - Soporte: `devbox.json` lineas 71-100
- Paso 4. El flujo localiza y ejecuta `bin/setup-wizard.sh`.
  - Clasificacion: `anclaje claro`
  - Soporte: `devbox.json` lineas 102-126
- Paso 5. El wizard resuelve contrato/profile y decide verify-only o full path.
  - Clasificacion: `anclaje claro`
  - Soporte: `bin/setup-wizard.sh` lineas 24-49, 73-117
- Paso 6. La variante estricta cambia `DEVBOX_SESSION_READY` solo tras verificacion valida.
  - Clasificacion: `anclaje claro`
  - Soporte: `devbox.json` lineas 108-126, `bin/setup-wizard.sh` lineas 122-182
- Paso 7. La subfrontera `print-env` devuelve exports para consumidores internos.
  - Clasificacion: `anclaje claro` para existencia / `anclaje parcial` para correspondencia con toda la sesion interactiva
  - Soporte: `common.sh` lineas 215-227 + corrida segura observada

# Preconditions ancladas
- **Anclaje claro:** repo Git obligatorio via `ensure_repo_or_die` (`lib/core/git-ops.sh` lineas 47-52, `bin/setup-wizard.sh` lineas 116-117).
- **Anclaje claro:** marker + TTY + no skip wizard determinan variante estricta (`devbox.json` lineas 52-55).
- **Anclaje claro:** herramientas requeridas por modo verify-only/full path (`bin/setup-wizard.sh` lineas 97-111).
- **Anclaje claro:** profile config y vendor dir se resuelven por contrato (`bin/setup-wizard.sh` lineas 31-45, `lib/core/contract.sh` lineas 173-279).
- **Anclaje parcial:** Devbox debe poder resolver el entorno del repo para `--print-env`; la dependencia externa existe, pero su detalle viene del runtime de Devbox, no del repo.

# Inputs anclados
- **Anclaje claro:** `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK` y TTY afectan ramas del `init_hook` (`devbox.json` lineas 53-64, 110-116).
- **Anclaje claro:** `--verify-only` y `--force` gobiernan el wizard (`bin/setup-wizard.sh` lineas 73-81).
- **Anclaje claro:** `devtools.repo.yaml` gobierna `vendor_dir` y `profile_file` via `devtools_load_contract` (`lib/core/contract.sh` lineas 198-279).
- **Anclaje claro:** `.devtools/.git-acprc` alimenta el host SSH usado en verify-only (`bin/setup-wizard.sh` lineas 141-151).
- **Anclaje parcial:** `print-env` no expuso explicitamente entradas del `init_hook` interactivo distintas del entorno Devbox base.

# Outputs anclados
- **Anclaje claro:** mensajes de fallo y exito del gate estricto (`devbox.json` lineas 117-147).
- **Anclaje claro:** saludo contextual y rol interactivo (`devbox.json` lineas 139-147).
- **Anclaje claro:** bloque de exports real para `--print-env` observado en copia temporal, incluyendo `DEVBOX_PROJECT_ROOT`, `DEVBOX_ENV_NAME`, `PATH`, `HOST_PATH`.
- **Anclaje parcial:** no quedo localizada una exportacion observable de `DEVBOX_SESSION_READY` a traves de `--print-env`.

# Side effects anclados
- **Side effect central / anclaje claro:** `git config --local --unset alias.$tool` y `chmod +x` en variante permisiva (`devbox.json` lineas 81-91).
- **Side effect central / anclaje claro:** `gh auth status` y `ssh -T` en verify-only (`bin/setup-wizard.sh` lineas 130-173).
- **Side effect secundario / anclaje claro:** `mkdir -p "$(dirname "$MARKER_FILE")"` (`bin/setup-wizard.sh` lineas 113-115).
- **Side effect secundario / anclaje claro:** `lib/core/config.sh` puede fijar `git config --global init.defaultBranch main` (`config.sh` lineas 126-138).
- **Side effect tolerado / seam:** intento de `git submodule sync/update` pese a no existir `.gitmodules` en este repo (`devbox.json` lineas 54-55).

# Invariants anclados
- **Invariant sostenido:** resolver root antes de cargar config/wizard (`devbox.json` lineas 48-55; `setup-wizard.sh` lineas 24-49).
- **Invariant sostenido:** la variante estricta no habilita la ruta lista/contextualizada si falla la verificacion (`devbox.json` lineas 117-123, 133-135).
- **Invariant sostenido:** la resolucion de contrato prioriza el contrato del repo y restringe paths permitidos (`lib/core/contract.sh` lineas 243-279).
- **Invariant en riesgo / parcial:** `print-env` existe como export surface, pero su correspondencia exacta con la sesion interactiva sigue parcial.

# Failure modes anclados
- **Failure mode contractual anclado:** fuera de repo Git -> aborta (`git-ops.sh` lineas 47-52).
- **Failure mode contractual anclado:** falta de herramientas requeridas -> aborta (`setup-wizard.sh` lineas 97-111).
- **Failure mode contractual anclado:** GH CLI no autenticado -> aborta verify-only (`setup-wizard.sh` lineas 130-138).
- **Failure mode contractual anclado:** SSH no valida -> aborta verify-only (`setup-wizard.sh` lineas 153-173).
- **Failure mode contractual anclado:** `common.sh` muere si no puede obtener `print-env` (`common.sh` lineas 215-229).
- **Failure mode parcial:** side effects globales de `config.sh` pueden ocurrir incluso en verify-only; el repo los implementa, pero el contrato futuro debe decidir si se toleran o quedan fuera de promesa.

# Ramas importantes y seams de compatibilidad
- **Rama central:** variante estricta activada hoy por `.devtools/.setup_completed` presente.
- **Rama secundaria:** variante permisiva sin marker o sin TTY.
- **Seam / compatibilidad:** `lib/core/config.sh` admite `profile_file` contractual y rutas legacy (`.devtools/.git-acprc`, `.git-acprc` en raiz).
- **Seam / compatibilidad:** `devbox.json` mantiene intento de submodulo para `.devtools` aunque el repo actual lo trackea como directorio normal.
- **Seam / compatibilidad:** `STARSHIP_CONFIG` apunta a `.starship.toml` ausente; el comportamiento final depende de `starship` o del fallback a `PROMPT`/`PS1`.

# Divergencias entre spec y codigo
- **No hay divergencia fuerte** entre el contrato inicial y el codigo para root resolution, gate estricto, profile resolution y consumer fallback de `print-env`.
- **Tension visible:** la subfrontera `print-env` observada no materializa las mismas huellas del `init_hook` interactivo; por eso el anclaje de equivalencia total queda `parcial`, no `claro`.
- **Tension visible:** la variante permisiva sigue adelante aunque el wizard falle (`devbox.json` linea 125), por lo que el contrato no debe generalizar el gate estricto a todos los modos.

# Superficies reales de cambio
- **Superficie principal:** `devbox.json`
- **Superficies secundarias:** `bin/setup-wizard.sh`, `lib/core/contract.sh`, `lib/core/config.sh`, `lib/promote/workflows/common.sh`
- **Zona de dispersion / riesgo:** interaccion entre `devbox.json` y `bin/setup-wizard.sh` para TTY/marker/gate; side effect global de `config.sh`; diferencia entre shell interactiva y `print-env`

# Unknowns
- **No bloquea:** semantica exacta del prompt cuando falta `.starship.toml`
- **Tensiona:** si `print-env` omite deliberadamente todo el `init_hook` interactivo o solo algunos side effects
- **Puede bloquear una promesa exagerada:** presentar `print-env` como cobertura total de la sesion interactiva

# Evidencia
- `devbox.json` lineas 45-148
- `bin/setup-wizard.sh` lineas 19-182
- `lib/core/git-ops.sh` lineas 47-52, 121-128
- `lib/core/contract.sh` lineas 173-279, 302-305
- `lib/core/config.sh` lineas 27-59, 126-159
- `lib/promote/workflows/common.sh` lineas 215-227
- corrida segura `devbox shell --print-env` en copia temporal del repo
- verificacion de `.devtools/.setup_completed` presente

# Criterio de salida para promover a spec-as-source
- **Listo para promover con reservas**
- Ya tienen anclaje suficiente:
  - entrypoint repo-controlado;
  - gate estricto;
  - resolucion de contrato/profile;
  - consumer fallback de `print-env`.
- Tienen anclaje parcial:
  - equivalencia entre la sesion interactiva completa y `--print-env`;
  - semantica final del prompt.
- No hay conflicto fuerte que obligue a reabrir discovery o spec-first.
- `spec-as-source` debe tratar como gaps/metarreglas:
  - no sobreprometer cobertura de `print-env`;
  - mantener visibles los side effects tolerados;
  - habilitar la derivacion inmediata a `Contract-Driven`.

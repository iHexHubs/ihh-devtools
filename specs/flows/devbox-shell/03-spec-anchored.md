# Flow id

`devbox-shell`

# Intencion contractual de referencia

- Confirmado desde spec-first:
  - la frontera principal es `devbox shell` / `devbox shell --print-env`;
  - la ayuda CLI visible y los exports base forman parte del contrato observable;
  - la sesion contextualizada no debe declararse lista cuando la variante estricta requiere verificacion y esta no pasa;
  - la resolucion del profile file debe venir del contrato repo-local.
- Fuera de alcance de esta fase:
  - modificar el flujo;
  - integrar CI real;
  - activar otras familias metodologicas.

# Entry point real anclado

- Anclaje claro:
  - `devbox.json` define `shell.init_hook`, que es la superficie repo-local que gobierna el flujo.
  - `.devbox/gen/scripts/.hooks.sh` materializa el hook generado ya presente en el repo y refleja la cadena efectiva que Devbox ejecutara.
- Anclaje parcial:
  - el comportamiento interno de Devbox fuera del repo no esta localizado aqui; solo se ancla la parte visible desde `devbox.json` y el hook generado.
- Descartado:
  - tratar `bin/setup-wizard.sh` como entrypoint principal.

# Dispatcher chain real anclada

- Anclaje claro:
  - `devbox shell[--print-env]`
  - `devbox.json` `shell.init_hook`
  - `.devbox/gen/scripts/.hooks.sh`
  - deteccion de `root`, `DT_ROOT`, `DT_BIN` y `candidates`
  - preparacion de `PATH` y `GIT_CONFIG_*`
  - localizacion/ejecucion de `setup-wizard.sh`
  - decision de `DEVBOX_SESSION_READY`
  - rama de mensajes, menu y prompt cuando la sesion queda lista
- Anclaje claro para el profile file:
  - `bin/setup-wizard.sh`
  - `lib/core/contract.sh`
  - `devtools_profile_config_file()`
  - export `DEVTOOLS_WIZARD_RC_FILE`
  - `lib/wizard/step-04-profile.sh`
- Consumidor real anclado:
  - `lib/promote/workflows/common.sh` consume `devbox shell --print-env` y hace `eval` antes de ejecutar `git-cliff`.

# Mapa de camino feliz

- Anclaje claro:
  1. `devbox.json` fija paquetes y `env`, incluyendo `DEVBOX_ENV_NAME=IHH`.
  2. El hook resuelve rutas candidatas y expone `PATH` para scripts corporativos.
  3. El hook publica aliases Git efimeros con `GIT_CONFIG_COUNT`.
  4. El hook calcula `DEVTOOLS_SPEC_VARIANT` usando marker, TTY y `DEVTOOLS_SKIP_WIZARD`.
  5. El hook descubre `setup-wizard.sh`.
  6. Si la variante estricta aplica, deja `DEVBOX_SESSION_READY=0` hasta que `bash "$WIZARD_SCRIPT" $WIZARD_ARGS` retorne exito.
  7. Si queda lista, imprime welcome y habilita rama interactiva de rol/prompt.
- Anclaje claro para automatizacion:
  1. `tests/contracts/devbox-shell/run-contract-checks.sh` importa el entorno via `eval "$(devbox shell --print-env)"`.
  2. Luego exige `bats` y `jq` disponibles antes de correr la suite.
- Anclaje parcial:
  - la presencia exacta de `DEVBOX_PROJECT_ROOT` en la salida proviene de la frontera Devbox observada indirectamente por tests, no de codigo repo-local propio.

# Preconditions ancladas

- Anclaje claro:
  - `devbox.json` debe existir en el repo.
  - el flujo depende de estar dentro de un repo Git para resolver root y contrato.
  - `bin/setup-wizard.sh` debe ser localizable para la rama contextualizada.
- Anclaje claro para verify-only:
  - `bin/setup-wizard.sh` exige `git`, `gh`, `ssh`, `grep`.
- Anclaje parcial:
  - la precondicion "Devbox instalado y operativo" no esta implementada en el repo; solo es condicion externa.

# Inputs anclados

- Anclaje claro:
  - comandos `devbox shell` y `devbox shell --print-env`
  - variables `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `DEVTOOLS_CONTRACT_FILE`, `DEVTOOLS_PROFILE_CONFIG`
  - archivo `devtools.repo.yaml`
  - marker `.devtools/.setup_completed`
  - condicion TTY / no TTY
- Seam / compatibilidad:
  - `.gitmodules` es insumo opcional de una rama legacy del hook, aunque no exista en el repo actual.

# Outputs anclados

- Anclaje claro:
  - ayuda CLI protegida por `tests/contracts/devbox-shell/devbox-shell-contract.bats`
  - salida de `--print-env` consumida por scripts del repo
  - `DEVTOOLS_WIZARD_RC_FILE` exportado por `bin/setup-wizard.sh`
  - mensaje de omision de la ruta lista/contextualizada en la variante estricta fallida
- Anclaje parcial:
  - texto completo y orden total de la salida de Devbox
  - prompt final interactivo

# Side effects anclados

- Anclaje claro:
  - `git submodule sync --recursive`
  - `git submodule update --init --recursive "$DEVTOOLS_PATH"`
  - `git config --local --unset alias.<tool>`
  - `chmod +x` sobre scripts encontrados
  - export de PATH y `GIT_CONFIG_*`
- Anclaje claro en el wizard:
  - posible escritura del archivo de perfiles
  - posible creacion/actualizacion de `.env`
  - posible touch del marker de setup
- Anclaje parcial:
  - llamadas de red reales de `git ls-remote`, `gh auth status` y `ssh -T`

# Invariants anclados

- Anclaje claro:
  - el valor base de `DEVBOX_ENV_NAME` en `devbox.json` es `IHH`
  - `DEVBOX_SESSION_READY` se pone en `0` antes de verificar cuando `DEVTOOLS_SPEC_VARIANT=1`
  - no TTY fuerza `WIZARD_ARGS="--verify-only"`
  - `bin/setup-wizard.sh` resuelve `PROFILE_CONFIG_FILE` mediante `devtools_profile_config_file "$REAL_ROOT"`
  - `lib/wizard/step-04-profile.sh` usa `DEVTOOLS_WIZARD_RC_FILE` como fuente del archivo real
- Divergencia real:
  - el working tree aun contiene `.devtools/.git-acprc`, mientras el contrato resuelto apunta a `.git-acprc` en root.

# Failure modes anclados

- Anclaje claro:
  - `lib/promote/workflows/common.sh` aborta si no logra obtener entorno de Devbox para `git-cliff`
  - `bin/setup-wizard.sh` sale con error si faltan herramientas requeridas
  - `bin/setup-wizard.sh` sale con error en verify-only si falla `gh auth status` o la comprobacion SSH
  - el hook deja la sesion no lista y emite mensaje de omision cuando la variante estricta no se satisface
- Anclaje parcial:
  - exit codes exactos del runtime Devbox completo

# Ramas importantes y seams de compatibilidad

- Seam / compatibilidad:
  - el hook sigue intentando bootstrap de submodulo `.devtools` aunque el repo actual no tiene `.gitmodules`
  - la busqueda de scripts usa rutas redundantes y anidadas para tolerar layouts legacy
  - existe marker y profile file legacy dentro de `.devtools/`
- Anclaje claro:
  - `DEVTOOLS_SPEC_VARIANT` es el seam principal entre ruta tolerante y gate estricto
  - la rama no TTY y la presencia del marker fuerzan `--verify-only`

# Divergencias entre spec y codigo

- Divergencia real:
  - contrato aprobado: el profile file debe resolverse por `devtools.repo.yaml` hacia `.git-acprc` en root;
  - realidad observable del repo: existe `.devtools/.git-acprc` legacy y no existe `.git-acprc` root en este snapshot.
- Divergencia real:
  - la promesa contractual central esta bien anclada, pero parte de la evidencia de `DEVBOX_PROJECT_ROOT` viene de tests existentes y no de una corrida nueva en este run.
- Sin divergencia relevante:
  - el gate de readiness y el uso de `DEVTOOLS_WIZARD_RC_FILE` si estan sostenidos por codigo localizado.

# Superficies reales de cambio

- Superficies principales:
  - `devbox.json`
  - `bin/setup-wizard.sh`
  - `lib/core/contract.sh`
  - `lib/wizard/step-04-profile.sh`
- Superficies secundarias:
  - `.devbox/gen/scripts/.hooks.sh`
  - `tests/contracts/devbox-shell/devbox-shell-contract.bats`
  - `tests/contracts/devbox-shell/run-contract-checks.sh`
  - `lib/promote/workflows/common.sh`
  - `devtools.repo.yaml`
- Zonas de alto riesgo:
  - cualquier cambio que fuerce cobertura falsa de readiness
  - cualquier cambio que vuelva a hardcodear `.devtools/.git-acprc`
  - cualquier cambio que rebaje la frontera principal a un helper interno o a una subfrontera mas comoda

# Unknowns

- No se anclo por corrida nueva el output exacto de `devbox shell --print-env`.
- No se anclaron consumidores externos al flujo principal que pudieran seguir leyendo `.devtools/.git-acprc`.
- No se anclo la rama interactiva completa de rol/prompt ni la salida exacta de welcome.

# Evidencia

- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`
- `lib/wizard/step-04-profile.sh`
- `lib/core/git-ops.sh`
- `lib/core/utils.sh`
- `lib/promote/workflows/common.sh`
- `tests/contracts/devbox-shell/devbox-shell-contract.bats`
- `tests/contracts/devbox-shell/run-contract-checks.sh`
- `devtools.repo.yaml`
- working tree actual: `.devtools/.setup_completed`, `.devtools/.git-acprc`, ausencia de `.gitmodules`

# Criterio de salida para promover a spec-as-source

- Quedo suficientemente anclado:
  - donde vive la frontera principal;
  - donde vive el gate de readiness;
  - donde vive la resolucion contractual del profile file;
  - que consumidores y checks ya dependen de `--print-env`.
- Quedo visible sin ocultarlo:
  - el seam de submodulo/.gitmodules;
  - la persistencia del profile file legacy;
  - la parte no re-ejecutada del runtime.
- La promocion a `spec-as-source` es valida porque ya existe un mapa concreto de superficies, divergencias y riesgos sin necesidad de mezclar implementacion.

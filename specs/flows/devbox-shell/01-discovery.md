# Discovery: `devbox-shell`

## Resumen rápido
- **Estado de discovery:** `lista para promover`
- **Flujo objetivo:** `devbox shell`
- **Trigger real:** ejecución de `devbox shell`, que consume la definición `shell.init_hook` en `devbox.json`
- **Pregunta principal:** qué hace realmente el repo al abrir `devbox shell`, por dónde entra, qué decisiones toma, qué toca y cuándo considera lista la sesión
- **Respuesta corta actual:** el flujo observado entra por `devbox.json` en `shell.init_hook`, resuelve la raíz del workspace, prepara `.devtools`, PATH y aliases efímeros, localiza `bin/setup-wizard.sh` y usa su resultado para decidir si la sesión queda `ready/contextualizada`. El wizard resuelve root/contrato, decide entre `verify-only` y `full path`, valida autenticación/SSH/Git/perfil y puede persistir marker y perfil. Si `DEVBOX_SESSION_READY=1`, el hook imprime bienvenida, ofrece selección de rol en TTY y ajusta el prompt.
- **Unknowns críticos:** bridge exacto dentro del binario `devbox`; éxito real del wizard y de validaciones de red en ejecución viva; seam entre `profile_file: .git-acprc` y el estado persistido observado en `.devtools/.git-acprc`

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- identificador corto y estable para el flujo `devbox shell`
- coincide con el `flow-id` esperado en esta corrida

## 2. Objetivo observable
**Estado:** `confirmada`

**Observado**
- El hook de shell intenta preparar una sesión de desarrollo contextualizada al repo: resuelve root, expone herramientas corporativas por PATH/Git config efímera, ejecuta un gatekeeper (`setup-wizard.sh`) y, si la sesión queda lista, muestra bienvenida, selector de rol y prompt contextualizado.

**Inferido**
- La responsabilidad observable del flujo es dejar al operador dentro de una shell ya contextualizada para trabajar en el repo, no solo abrir una shell vacía.

**No verificado**
- No se ejecutó `devbox shell` de punta a punta en esta corrida, así que el resultado interactivo final se describe desde código y estado del repo, no desde una sesión viva observada.

## 3. Trigger real / entrada real
**Estado:** `parcial`

**Observado**
- El repo define el flujo de shell en [`devbox.json`](/webapps/ihh-devtools/devbox.json) bajo `shell.init_hook`.
- La secuencia principal del flujo está codificada en ese arreglo de comandos.

**Inferido**
- El trigger operativo esperado es ejecutar `devbox shell`, que hace que Devbox consuma `shell.init_hook`.

**No verificado**
- El bridge exacto entre el binario `devbox` y `shell.init_hook` no está implementado en este repo; no se inspeccionó el código fuente de Devbox.

## 4. Pregunta principal
**Estado:** `confirmada`

**Observado**
- La pregunta que guio este discovery fue: cuando el operador abre `devbox shell`, ¿cómo se reconstruye la shell del repo, qué handoffs ocurren y qué condiciones marcan la sesión como lista o no lista?

**Inferido**
- La pregunta también exige separar el flujo principal del wizard de consumers secundarios como `devbox shell --print-env`.

**No verificado**
- Ninguno adicional relevante para esta sección.

## 5. Frontera del análisis
**Estado:** `confirmada`

**Incluye**
- `devbox.json` en la sección `shell.init_hook`
- `bin/setup-wizard.sh`
- dependencias directas del wizard: `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/utils.sh`, `lib/wizard/step-01-auth.sh`, `step-02-ssh.sh`, `step-03-config.sh`, `step-04-profile.sh`
- estado persistido del repo que altera el flujo: `devtools.repo.yaml`, `.devtools/.setup_completed`, `.devtools/.git-acprc`, `.env`

**Excluye**
- implementación interna del binario `devbox`
- ejecución real de red/autenticación/SSH/GitHub
- consumers secundarios como `lib/promote/workflows/common.sh` que usan `devbox shell --print-env`
- fases posteriores al discovery

**Observado**
- Esta frontera basta para reconstruir el flujo observable del repo.

**No verificado**
- No se abrieron flujos no llamados desde `shell.init_hook`.

## 6. Entry point
**Estado:** `confirmada`

- **Entry point principal:** `devbox.json -> shell.init_hook`
- **Path relevante:** [`devbox.json`](/webapps/ihh-devtools/devbox.json)
- **Activador inmediato:** invocación externa de `devbox shell`

**Observado**
- El repo define explícitamente la lógica principal del flujo en `shell.init_hook`, incluyendo preparación de root, variante, submodule sync/update, alias efímeros, gatekeeper, bienvenida y prompt.

**Inferido**
- Aunque `bin/setup-wizard.sh` concentra gran parte del comportamiento, no es el entrypoint principal: recibe el handoff desde `shell.init_hook`.

**Alternativas descartadas**
- `lib/promote/workflows/common.sh` no es entrypoint de este flujo; consume `devbox shell --print-env` en otro contexto.
- `bin/setup-wizard.sh` es un handoff principal, no la entrada inicial del comando.

## 7. Dispatcher chain
**Estado:** `confirmada`

- `devbox shell -> devbox.json/shell.init_hook -> búsqueda de setup-wizard.sh -> bin/setup-wizard.sh`
- `bin/setup-wizard.sh -> lib/core/git-ops.sh/detect_workspace_root`
- `bin/setup-wizard.sh -> lib/core/contract.sh/devtools_load_contract + devtools_profile_config_file`
- `bin/setup-wizard.sh -> verify-only o full path`
- `full path -> lib/wizard/step-01-auth.sh/run_step_auth -> step-02-ssh.sh/run_step_ssh -> step-03-config.sh/run_step_git_config -> step-04-profile.sh/run_step_profile_registration`
- `si DEVBOX_SESSION_READY=1 -> mensajes de bienvenida -> selector de rol -> configuración de prompt`

**Observado**
- Esta cadena sale directamente de `devbox.json` y del cuerpo de `bin/setup-wizard.sh`.

**No verificado**
- No se verificó el orden de ejecución real dentro del runtime de Devbox; se usa la secuencia declarada por el repo.

## 8. Camino feliz
**Estado:** `parcial`

**Observado**
1. `shell.init_hook` resuelve `top`, `sp`, `root_guess` y `root`, luego fija `DEVTOOLS_PATH=.devtools`, `DT_ROOT`, `DT_BIN` y `DEVTOOLS_SPEC_VARIANT`.
2. Si no está en la variante estricta (`DEVTOOLS_SPEC_VARIANT != 1`), intenta `git submodule sync/update --init --recursive .devtools`, ignorando fallos.
3. Emite aviso de versión de devtools usando metadata local y, opcionalmente, `git ls-remote`.
4. Prepara `candidates`, exporta `PATH` con `root/bin` y `DT_BIN`, limpia aliases previos y registra aliases efímeros en memoria para scripts `git-*`.
5. Busca `setup-wizard.sh` en `candidates`; en este repo encuentra `bin/setup-wizard.sh`.
6. Ajusta `DEVBOX_SESSION_READY`: si está en variante estricta arranca en `0`; si no, arranca en `1`.
7. Ejecuta `setup-wizard.sh` con `--verify-only` si detecta marker o si no hay TTY.
8. Si la variante estricta recibe éxito del wizard, marca la sesión como lista; si falla, deja la sesión no lista y emite mensaje de omisión de la ruta lista/contextualizada.
9. Si `DEVBOX_SESSION_READY=1`, imprime bienvenida, sugiere `devbox run backend`, ofrece selector de rol en TTY y configura Starship o un prompt de fallback.

**Inferido**
- En el estado actual del repo, el camino feliz más probable en una shell interactiva normal entra por la variante estricta porque existe `.devtools/.setup_completed`.
- En ese camino, el wizard probablemente usa `--verify-only` y evita rehacer el setup completo salvo que se fuerce.

**No verificado**
- No se observó una ejecución real del selector de rol ni de Starship.
- No se confirmó si el wizard retorna éxito en este entorno concreto.

## 9. Ramas importantes
**Estado:** `confirmada`

- **Rama `DEVTOOLS_SPEC_VARIANT`:**
  - `1` si existe `"$DT_ROOT/.setup_completed"`, hay TTY y no está `DEVTOOLS_SKIP_WIZARD=1`
  - `0` en los demás casos
- **Rama `DEVTOOLS_SKIP_WIZARD`:**
  - si vale `1`, evita el gatekeeper del wizard
- **Rama `DEVTOOLS_SKIP_VERSION_CHECK`:**
  - si vale `1`, omite el aviso de versión
- **Rama `WIZARD_ARGS`:**
  - `--verify-only` si existe marker o si no hay TTY
- **Rama `DEVBOX_SESSION_READY`:**
  - en variante estricta depende del retorno del wizard
  - fuera de variante estricta, el wizard se tolera con `|| true`
- **Rama de prompt y menú:**
  - solo ocurre si `DEVBOX_SESSION_READY=1`
  - selección de rol solo si hay TTY

**Observado**
- Todas estas ramas están explícitas en `devbox.json` y `bin/setup-wizard.sh`.

**No verificado**
- No se midió cuál de estas ramas se activa en una corrida real fuera del estado estático actual del repo.

## 10. Side effects
**Estado:** `parcial`

**Observado**
- Exporta variables y PATH en la sesión de shell.
- Carga aliases Git efímeros usando `GIT_CONFIG_COUNT`.
- Puede ejecutar `git submodule sync/update` sobre `.devtools`.
- Puede invocar `git ls-remote` para aviso de versión.
- `setup-wizard.sh` en full path puede:
  - abrir/login con `gh`
  - generar o seleccionar llaves SSH
  - cargar `ssh-agent`
  - subir llaves a GitHub
  - escribir config global/local de Git
  - actualizar `origin` a SSH
  - crear o completar archivo de perfil
  - crear `.env`
  - tocar marker de setup
- En verify-only consulta `gh auth status` y ejecuta `ssh -T`.

**Inferido**
- Parte de esos side effects son de red o de sistema de usuario y pueden ser materiales fuera del repo.

**No verificado**
- No se observaron side effects runtime en esta corrida; se listan desde código.

## 11. Inputs
**Estado:** `confirmada`

**Obligatorios o contextuales observados**
- comando externo `devbox shell`
- repo Git válido (`ensure_repo_or_die`)
- archivos/config del repo: `devbox.json`, `devtools.repo.yaml`
- estado local: `.devtools/.setup_completed`, `.devtools/.git-acprc`, `.env`
- entorno/TTY: `-t 0 && -t 1`

**Variables de entorno observadas**
- `DEVTOOLS_SKIP_WIZARD`
- `DEVTOOLS_SKIP_VERSION_CHECK`
- `DEVTOOLS_SPEC_VARIANT`
- `DEVTOOLS_CONTRACT_FILE`, `DEVTOOLS_VENDOR_DIR`, `DEVTOOLS_PROFILE_CONFIG` (vía contrato/override)
- `DEVTOOLS_ALLOW_ABSOLUTE_PATHS`
- `DEVTOOLS_WIZARD_MODE`

**Dependencias observadas**
- `git`
- `gh`
- `ssh`
- `grep`
- en full path interactivo también `gum`, `ssh-keygen`, `ssh-add`

## 12. Outputs
**Estado:** `parcial`

**Observado**
- salida en consola con:
  - blindaje de entorno
  - root detectado
  - avisos de versión
  - mensajes del wizard
  - advertencias si no hay `setup-wizard.sh`
  - mensajes de éxito o fallo de la ruta lista/contextualizada
  - bienvenida del proyecto y sugerencia `devbox run backend`
- export de `DEVBOX_ENV_NAME` y función `devx` si hay selección de rol
- prompt Starship o prompt fallback

**Inferido**
- El resultado principal visible para el operador es una shell contextualizada, o una shell sin la ruta `ready/contextualizada` si el gatekeeper falla en variante estricta.

**No verificado**
- No se observó un exit code final del flujo `devbox shell` en vivo.

## 13. Preconditions
**Estado:** `confirmada`

**Observado**
- estar dentro de un repo Git
- tener `devbox.json`
- tener disponibles dependencias mínimas del wizard según el modo
- para la variante estricta útil del repo actual:
  - `.devtools/.setup_completed`
  - `bin/setup-wizard.sh`
- para verificar SSH/perfil:
  - `gh` autenticado o capacidad de autenticarse
  - acceso a llaves SSH y/o capacidad de generarlas

**Inferido**
- Para alcanzar la experiencia completa de shell contextualizada, el entorno debe permitir prompts interactivos y acceso de red hacia GitHub.

**No verificado**
- No se validó conectividad real ni autenticación viva en esta corrida.

## 14. Error modes
**Estado:** `parcial`

**Observado**
- Si falta repo Git, `ensure_repo_or_die` aborta el wizard.
- Si faltan herramientas requeridas, el wizard aborta con error crítico.
- En verify-only:
  - si `gh auth status` falla, el wizard retorna error
  - si `ssh -T` no da patrón de éxito esperado, el wizard retorna error
- En variante estricta:
  - si el wizard falla, `DEVBOX_SESSION_READY` queda `0` y se omite la ruta lista/contextualizada
- Si no se encuentra `setup-wizard.sh`, el hook avisa y, en variante estricta, también deja la sesión no lista.

**Inferido**
- La rama `git submodule ... .devtools` puede fallar silenciosamente sin bloquear porque está protegida con `|| true`.

**No verificado**
- No se provocaron fallos reales de red, permisos o TTY durante esta corrida.

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Núcleo
- [`devbox.json`](/webapps/ihh-devtools/devbox.json) `shell.init_hook`
- [`bin/setup-wizard.sh`](/webapps/ihh-devtools/bin/setup-wizard.sh)
- [`lib/core/git-ops.sh`](/webapps/ihh-devtools/lib/core/git-ops.sh) `ensure_repo_or_die`, `detect_workspace_root`
- [`lib/core/contract.sh`](/webapps/ihh-devtools/lib/core/contract.sh) `devtools_find_contract_file`, `devtools_load_contract`, `devtools_profile_config_file`
- [`lib/wizard/step-01-auth.sh`](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh) `run_step_auth`
- [`lib/wizard/step-02-ssh.sh`](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh) `run_step_ssh`
- [`lib/wizard/step-03-config.sh`](/webapps/ihh-devtools/lib/wizard/step-03-config.sh) `run_step_git_config`
- [`lib/wizard/step-04-profile.sh`](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh) `run_step_profile_registration`

### Soporte
- [`lib/core/utils.sh`](/webapps/ihh-devtools/lib/core/utils.sh) `is_tty`
- [`devtools.repo.yaml`](/webapps/ihh-devtools/devtools.repo.yaml)
- [`.devtools/.git-acprc`](/webapps/ihh-devtools/.devtools/.git-acprc)
- [`.devtools/.setup_completed`](/webapps/ihh-devtools/.devtools/.setup_completed)
- scripts `bin/git-*.sh` localizados por el hook para aliases efímeros

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `parcial`

**Hecho confirmado**
- El hook intenta `git submodule sync/update --init --recursive .devtools`, pero en este repo no existe `.gitmodules` ni `.devtools` como submódulo; `.devtools` está trackeado como directorio normal.

**Indicio fuerte**
- La búsqueda de scripts revisa rutas anidadas como `"$DT_ROOT/$DEVTOOLS_PATH"` y `"$DT_ROOT/$DEVTOOLS_PATH/bin"`, lo que sugiere compatibilidad con layouts previos o alternos.

**Sospecha**
- Hay un seam entre el contrato actual (`profile_file: .git-acprc`, que `devtools_profile_config_file` resuelve en `./.git-acprc`) y el estado persistido observado en `.devtools/.git-acprc`. El repo actual conserva el archivo en `.devtools`, lo que sugiere transición o tolerancia de compatibilidad.

## 17. Unknowns
**Estado:** `confirmada`

- No se verificó el runtime interno del binario `devbox`; el trigger externo se infiere desde la convención de `devbox.json`.
- No se observó una corrida viva de `devbox shell`, así que no hay evidencia directa del retorno real del wizard ni del estado final de la shell.
- No se verificó si el mismatch `profile_file` vs `.devtools/.git-acprc` es intencional, accidental o pendiente de migración.
- No se verificó si la rama `DEVTOOLS_SPEC_VARIANT=0` sigue siendo relevante en clones actuales.
- No se verificó la rama `DEVTOOLS_SKIP_WIZARD=1`.
- No se verificó la experiencia interactiva completa de `gum choose`, `ssh-add`, login web o cambio de `origin` a SSH.

## 18. Evidencia
**Estado:** `confirmada`

- `path:` [`devbox.json`](/webapps/ihh-devtools/devbox.json)
- `función/handler:` `shell.init_hook`
- `path:` [`bin/setup-wizard.sh`](/webapps/ihh-devtools/bin/setup-wizard.sh)
- `función/handler:` `ensure_repo_or_die`, `detect_workspace_root`, `devtools_load_contract`, `devtools_profile_config_file`, `run_step_auth`, `run_step_ssh`, `run_step_git_config`, `run_step_profile_registration`
- `path:` [`lib/core/git-ops.sh`](/webapps/ihh-devtools/lib/core/git-ops.sh)
- `path:` [`lib/core/contract.sh`](/webapps/ihh-devtools/lib/core/contract.sh)
- `path:` [`lib/core/utils.sh`](/webapps/ihh-devtools/lib/core/utils.sh)
- `path:` [`lib/wizard/step-01-auth.sh`](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh)
- `path:` [`lib/wizard/step-02-ssh.sh`](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh)
- `path:` [`lib/wizard/step-03-config.sh`](/webapps/ihh-devtools/lib/wizard/step-03-config.sh)
- `path:` [`lib/wizard/step-04-profile.sh`](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh)
- `path:` [`devtools.repo.yaml`](/webapps/ihh-devtools/devtools.repo.yaml)
- `path:` [`.devtools/.git-acprc`](/webapps/ihh-devtools/.devtools/.git-acprc)
- `path:` [`.devtools/.setup_completed`](/webapps/ihh-devtools/.devtools/.setup_completed)
- `corrida/validación:` `bash -n bin/setup-wizard.sh`
- `corrida/validación:` `bash -n lib/wizard/step-01-auth.sh`
- `corrida/validación:` `bash -n lib/wizard/step-02-ssh.sh`
- `corrida/validación:` `bash -n lib/wizard/step-03-config.sh`
- `corrida/validación:` `bash -n lib/wizard/step-04-profile.sh`
- `corrida/validación:` presencia de `devbox.json`, `bin/setup-wizard.sh`, `devtools.repo.yaml`, `.devtools/.setup_completed`

## 19. Validación segura
**Estado:** `confirmada`

**Qué se validó**
- consistencia sintáctica de `bin/setup-wizard.sh` y de los cuatro steps del wizard con `bash -n`
- existencia de los archivos clave que sostienen el relato del flujo
- estado local del repo que altera ramas (`devtools.repo.yaml`, `.devtools/.setup_completed`, `.devtools/.git-acprc`, `.env`)

**Qué quedó confirmado gracias a esa validación**
- el backbone reconstruido es sintácticamente válido en las piezas inspeccionadas
- el repo sí contiene el wizard y el marker que afectan el camino feliz actual

**Qué siguió sin confirmarse**
- ejecución real de red/autenticación/SSH
- resultado final de `devbox shell` en una sesión viva

**Riesgos de ejecutar el flujo real**
- puede abrir login web, tocar Git config global/local, generar/subir llaves, cambiar `origin`, escribir `.env` o marker, y hacer llamadas de red

**Alternativa estática o de baja intervención**
- mantener la validación estática usada aquí como refuerzo suficiente para discovery, sin correr el flujo completo

## 20. Criterio de salida para promover a spec-first
**Estado:** `confirmada`

**Qué quedó suficientemente claro**
- entrypoint y backbone del flujo dentro del repo
- condiciones principales para que la sesión quede lista o no
- papel del wizard y de sus cuatro pasos
- side effects esperables y seams relevantes

**Qué sigue abierto**
- bridge interno de Devbox
- éxito runtime del wizard y de validaciones de red
- seam del archivo de perfil

**Si los unknowns bloquean o no la promoción**
- no bloquean la promoción a `spec-first`, porque ya es posible responder con suficiente precisión por dónde entra el flujo, qué decide, qué toca y dónde termina dentro del repo

**Mínima aclaración adicional necesaria para promover**
- no hace falta reabrir discovery completo; si más adelante hiciera falta, bastaría contrastar en una corrida segura el comportamiento real de la rama interactiva y el uso efectivo de `profile_file`

## 21. Respuesta canónica del discovery
**Estado:** `confirmada`

Cuando pasa `devbox shell`, el flujo entra por `devbox.json` en `shell.init_hook`, resuelve la raíz del workspace y el estado de `.devtools`, prepara PATH y aliases Git efímeros, y delega en `bin/setup-wizard.sh` la verificación o preparación del entorno. Ese wizard decide entre `verify-only` y `full path`, valida repo/credenciales/SSH/Git/perfil y puede persistir marker y perfil. Con ese resultado, el hook decide si `DEVBOX_SESSION_READY` queda activo; si sí, imprime bienvenida, permite elegir rol en TTY y configura el prompt. El corte de evidencia llega hasta esa lógica declarada y al estado local del repo, pero no incluye una ejecución viva del binario `devbox` ni de las operaciones de red.

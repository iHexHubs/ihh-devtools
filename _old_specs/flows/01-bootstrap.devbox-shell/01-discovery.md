# Plantilla: discovery

## Propósito

Describir el flujo real observado sin inventar todavía el contrato.

Actúa como coordinador metodológico estricto de la fase discovery. No eres implementador, no eres arquitecto y no eres solucionador del problema final. Tu función es dirigir a Codex para inspeccionar el repositorio por bloques, auditar la evidencia y consolidar una ficha de flujo real.

Debes trabajar con estas reglas:

1. Analiza un solo flujo a la vez.
2. No implementes nada.
3. No edites nada.
4. No propongas refactors.
5. No propongas tests nuevos.
6. No mezcles discovery con spec-first, spec-anchored ni spec-as-source.
7. No inventes contrato, intención futura ni comportamiento deseado.
8. No conviertas sospechas en hechos.
9. No permitas que Codex se salga del bloque actual.
10. Después de cada respuesta de Codex, separa siempre:

* confirmado
* probable
* sospecha
* descartado
* no sustentado

## Estado actual

* **Bloque actual:** Bloque 7: Minuto 40–45
* **Objetivo del bloque:** cierre con ficha final
* **Pregunta que estamos resolviendo:** cuando el usuario ejecuta `devbox shell` en `/webapps/ihh-devtools`, por dónde entra, qué decide, qué toca y dónde termina la corrida observada

## Hallazgos sustentados

* La entrada local real del flujo está en `devbox.json` -> `shell.init_hook`.
* La ruta principal observada fue: `devbox.json` -> `bin/setup-wizard.sh --verify-only` -> helpers/contrato -> retorno a `devbox.json` -> menú/prompt.
* `.devtools/.setup_completed` cambió materialmente la ruta observada.
* `lib/core/git-ops.sh`, `lib/core/contract.sh`, `devtools.repo.yaml` y `lib/ui/styles.sh` sostienen la ruta como soporte útil.
* La validación efectiva disponible es una PTY corta de `devbox shell` hasta `Selecciona tu Rol:`.

## Hipótesis aún no confirmadas

* La selección final de rol y el `DEVBOX_ENV_NAME` resultante.
* La persistencia externa exacta del chequeo SSH.
* La participación real de `.devtools/.git-acprc` en otras corridas.
* La necesidad actual de algunas compatibilidades heredadas.

## Qué podemos ignorar por ahora

* `devbox.lock`, `.devbox/state.json`, `.devbox/gen/shell.nix` como explicación central.
* `.gitmodules` y `.starship.toml` como piezas efectivas del recorrido principal observado.
* Ramas sin marker, sin TTY, con `skip wizard` o layouts alternos.

## Condición para pasar al siguiente bloque

* No hay siguiente bloque dentro de discovery.
* Discovery queda cerrada y puede promoverse a spec-first si el alcance aceptado es la corrida observada con marker presente.

---

## Flow id

`bootstrap.devbox-shell`

## Objetivo

Reconstruir con evidencia qué ocurre cuando se ejecuta `devbox shell` en `/webapps/ihh-devtools` y hasta dónde llega la corrida observada, sin cerrar por inferencia ramas no verificadas.

**Estado:** confirmada

## Entry point

`devbox.json` -> `shell.init_hook`

**Estado:** confirmada

## Dispatcher chain

`devbox.json / shell.init_hook` -> `bin/setup-wizard.sh --verify-only` -> `lib/core/git-ops.sh` / `lib/core/contract.sh` -> `devtools.repo.yaml` -> retorno a `devbox.json` -> menú/prompt

**Estado:** confirmada

## Camino feliz

`devbox shell` entra a `shell.init_hook`, resuelve root y `.devtools`, intenta `sync/update` del submódulo, arma `PATH` y aliases Git efímeros, encuentra y ejecuta el wizard en `--verify-only`, el wizard valida repo/GH/SSH y vuelve a `devbox.json`, que imprime mensajes finales, muestra el menú de rol y deja la shell interactiva visible.

**Estado:** parcial

## Ramas importantes

* Marker `.devtools/.setup_completed` fuerza `--verify-only`.
* Sin TTY también fuerza `--verify-only`.
* `DEVTOOLS_SKIP_WIZARD` evita ejecutar wizard.
* La resolución de `profile_file` puede afectar el host SSH de chequeo.

**Estado:** parcial

## Side effects

* Intentos de `git submodule sync` y `git submodule update` sobre `.devtools`
* Mutación del entorno de shell: `PATH`, `DEVTOOLS_*`, `GIT_CONFIG_*`
* `chmod +x` sobre scripts detectados
* Chequeos `gh auth status` y `ssh -T git@github.com`
* Publicación del menú interactivo final
* Posible `STARSHIP_CONFIG` en la sesión

**Estado:** parcial

## Inputs

* Comando `devbox shell`
* CWD `/webapps/ihh-devtools`
* `devbox.json`
* Presencia de `.devtools/.setup_completed` para la corrida observada
* TTY interactiva para la corrida observada
* Disponibilidad de `git`, `gh`, `ssh`, `gum`, `starship`
* Estado válido de auth/red para GH y SSH en la ruta saludable observada

**Estado:** parcial

## Outputs

* Banner inicial de devtools
* Carga de herramientas Git efímeras
* Verificación GH/SSH con estado saludable
* Mensajes finales de Devbox
* Menú `Selecciona tu Rol:`
* Shell interactiva visible

No quedó observada con sumisión limpia la salida final posterior a elegir rol.

**Estado:** parcial

## Preconditions

Para la ruta observada:

* repo Git válido
* `devbox.json` presente
* wizard localizable en `bin/setup-wizard.sh`
* marker presente
* TTY disponible
* `gh` autenticado
* SSH a `github.com` funcional

**Estado:** parcial

## Error modes

Codificados y sostenidos por lectura, pero no ejecutados en la corrida validada:

* no estar en repo válido
* faltar herramientas requeridas
* fallo de `gh auth status`
* fallo del chequeo SSH

**Estado:** parcial

## Archivos y funciones involucradas

**Núcleo**

* `devbox.json`
* `bin/setup-wizard.sh`
* `.devtools/.setup_completed`

**Soporte útil**

* `lib/core/git-ops.sh`

  * `git_get`
  * `ensure_repo_or_die`
  * `detect_workspace_root`
* `lib/core/contract.sh`

  * `devtools_load_contract`
  * `devtools_profile_config_file`
* `devtools.repo.yaml`
* `lib/ui/styles.sh`

  * `ui_step_header`
  * `ui_success`
  * `ui_info`
  * `ui_spinner`

**Estado:** confirmada

## Unknowns

* Selección final de rol
* Valor final de `DEVBOX_ENV_NAME`
* Persistencia externa exacta
* Activación real de ramas sin marker / sin TTY / `skip wizard` / layouts alternos
* Necesidad actual de compatibilidades heredadas
* Participación efectiva de `.devtools/.git-acprc` en otra corrida

**Estado:** abierta

## Sospechas de legacy / seams de compatibilidad

* Compat multi-layout en `devbox.json`
* Tratamiento de `profile_file` con defaults legacy en `lib/core/contract.sh`
* Wrapper de compatibilidad explícito `ensure_local_tracking_branch` en `lib/core/git-ops.sh`
* Fallback de parser en `lib/core/contract.sh`

Todo esto queda como sospecha o seam de compatibilidad, no como legacy activo demostrado.

**Estado:** abierta

## Evidencia

* Lectura directa de `devbox.json`
* Lectura directa de `bin/setup-wizard.sh`
* Lectura directa de `lib/core/git-ops.sh`
* Lectura directa de `lib/core/contract.sh`
* Lectura directa de `devtools.repo.yaml`
* Lectura directa de `lib/ui/styles.sh`
* `devbox shell --help`
* `devbox shell --print-env`
* PTY corta de `devbox shell` hasta `Selecciona tu Rol:`

**Estado:** confirmada

## Criterio de salida para promover a spec-first

Queda listo para spec-first **si el alcance aceptado** es la corrida observada con marker presente. En ese alcance ya hay:

* entry point
* dispatcher chain
* camino principal
* decisiones relevantes
* side effects principales
* inputs/outputs principales
* unknowns explícitos

No queda listo para una promoción cerrada si el nuevo trabajo exigiera cubrir también:

* variantes sin marker
* variantes sin TTY
* `skip wizard`
* layouts alternos
* cierre limpio post-selección de rol

**Estado:** parcial

---

### Confirmado

* `devbox.json / shell.init_hook` es la entrada local real.
* La cadena observada fue `devbox.json` -> `bin/setup-wizard.sh --verify-only` -> helpers/contrato -> retorno a `devbox.json` -> menú/prompt.
* `.devtools/.setup_completed` decidió la ruta observada.
* Hay side effects reales antes del menú: `submodule sync/update`, cambios de entorno, `chmod +x`, chequeos GH/SSH.
* La validación efectiva disponible es PTY corta hasta `Selecciona tu Rol:`.

### Probable

* El CLI externo de Devbox descubre `devbox.json` por búsqueda desde el cwd.
* La selección final de rol ajusta `DEVBOX_ENV_NAME` y termina de fijar el prompt.
* `.devtools/.git-acprc` puede influir en otras corridas donde el `profile_file` efectivo sí apunte a ese archivo.

### Sospecha

* La búsqueda multi-layout responde a compatibilidades históricas y no sólo a robustez.
* El manejo de `profile_file` conserva rutas heredadas todavía toleradas.
* El parser/fallback de contrato y algunos wrappers existen como seams de compatibilidad más que como núcleo vigente.

### Descartado

* `devbox.lock`, `.devbox/state.json` y `.devbox/gen/shell.nix` como explicación central del flujo.
* `.gitmodules` y `.starship.toml` como piezas efectivas del recorrido principal observado.
* `devbox.json.scripts` como entry point de `devbox shell`.

### No sustentado

* La selección final de rol con sumisión limpia.
* El valor final de `DEVBOX_ENV_NAME` tras esa selección.
* La persistencia externa exacta del chequeo SSH.
* La activación real de ramas sin marker, sin TTY, con `skip wizard` o layouts alternos.
* La necesidad actual de algunas compatibilidades heredadas.

---

**Regla final:**
Discovery solo queda bien hecho si esta plantilla permite responder con evidencia a la pregunta:
**“Cuando pasa X, ¿por dónde entra, qué decide, qué toca y dónde termina?”**

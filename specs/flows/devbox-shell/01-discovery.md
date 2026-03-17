# Discovery: `devbox-shell`

## Resumen rapido
- **Estado de discovery:** `parcial`
- **Flujo objetivo:** entrada a shell de desarrollo con `devbox shell`
- **Trigger real:** ejecucion de `devbox shell` desde terminal dentro de `/webapps/ihh-devtools`
- **Pregunta principal:** que hace realmente el sistema y que ocurre en el flujo cuando el usuario entra a este repo y ejecuta `devbox shell`
- **Respuesta corta actual:** Observado: el flujo reconstruible llega con evidencia hasta `devbox.json`, el hook generado en `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh` y el estado persistido actual del repo. Parcial: el entrypoint externo es el binario `devbox`, pero en este discovery no se observo una corrida completa de ese binario; se infiere que `devbox shell` materializa o reutiliza `.devbox/gen/scripts/.hooks.sh` y ejecuta ese hook antes de entregar la shell. El hook resuelve root, intenta bootstrap de `.devtools`, carga aliases efimeros de Git, busca y ejecuta `setup-wizard.sh`, y solo habilita la sesion contextualizada si el gate del wizard queda satisfecho. El corte de evidencia no llega a una corrida completa con red, credenciales o cambios globales.
- **Unknowns criticos:** verify-only actual; efecto de `git submodule update` sin `.gitmodules`; drift entre `.git-acprc` root y `.devtools/.git-acprc`; comportamiento real de `starship`; ramas no verificadas `DEVTOOLS_SKIP_WIZARD`, no TTY, fallo GH/SSH y ruta sin marker.

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- Identificador corto y especifico para el flujo de entrada por `devbox shell`.

## 2. Objetivo observable
**Estado:** `confirmada`

Describir que hace el sistema al abrir una shell de `devbox` dentro de este repo.

- Observado: prepara un entorno de shell con variables, `PATH`, aliases efimeros de Git y un gate de setup/verificacion.
- Observado: intenta dejar la sesion "lista/contextualizada" solo si el wizard o su verificacion pasan.
- Inferido: el objetivo operativo es entregar una shell de trabajo con herramientas corporativas y contexto del repo ya cargados.

## 3. Trigger real / entrada real
**Estado:** `parcial`

- Trigger estudiado: `devbox shell` ejecutado desde terminal con `cwd=/webapps/ihh-devtools`.
- Observado: el repo contiene `devbox.json` con `shell.init_hook` y Devbox ya genero `.devbox/gen/scripts/.hooks.sh`.
- Inferido: el activador inmediato externo es el binario `devbox`, que usa ese hook al levantar la shell.
- No verificado: no se corrio el trigger real completo en esta inspeccion.

## 4. Pregunta principal
**Estado:** `confirmada`

Cuando el usuario entra a `/webapps/ihh-devtools` y ejecuta `devbox shell`, por donde entra el flujo, que decide, que toca y donde termina segun la evidencia disponible.

## 5. Frontera del analisis
**Estado:** `confirmada`

Entra:
- entrypoint real o parcial;
- dispatcher chain;
- camino feliz reconstruido;
- ramas importantes;
- side effects;
- inputs y outputs;
- preconditions;
- error modes;
- nucleo, soporte y ruido probable;
- validacion segura;
- unknowns.

No entra:
- spec-first;
- spec-anchored;
- spec-as-source;
- implementation;
- evaluation;
- review;
- refactors;
- fixes;
- rediseño;
- cambios de comportamiento;
- tests nuevos.

## 6. Entry point
**Estado:** `parcial`

- Entry point externo principal: binario `devbox` invocado como `devbox shell`.
  - Estado: `parcial`.
  - Motivo: no se observo directamente el binario, pero el repo muestra la configuracion que ese binario consume y el hook ya generado por Devbox.
- Entry point interno mejor sustentado: `shell.init_hook` en `devbox.json`, reflejado en `.devbox/gen/scripts/.hooks.sh`.
  - Estado: `confirmada`.
  - Paths: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`.
  - Motivo: es el primer bloque de logica del repo que explica decisiones, side effects y handoffs del flujo.

Alternativas descartadas:
- `Taskfile.yaml`: no dispara `devbox shell`; solo define tareas del repo.
- `README.md`: describe metodo, no actua como entrada runtime.
- `bin/devtools`: participa en otros flujos, no en la entrada base del shell.

## 7. Dispatcher chain
**Estado:** `parcial`

- Parcial, inferido/observado:
  - `devbox shell` -> `devbox.json:shell.init_hook` -> `.devbox/gen/scripts/.hooks.sh` -> busqueda de `setup-wizard.sh` -> `bin/setup-wizard.sh` -> `lib/core/*` y `lib/wizard/step-*.sh` -> decision `DEVBOX_SESSION_READY` -> bienvenida/menu/prompt si la sesion queda lista.

Cadena interna confirmada desde el repo:
- `devbox.json` -> `.devbox/gen/scripts/.hooks.sh` -> `bin/setup-wizard.sh` -> `lib/core/git-ops.sh`
- `bin/setup-wizard.sh` -> `lib/core/contract.sh`
- `bin/setup-wizard.sh` -> `lib/core/config.sh`
- `bin/setup-wizard.sh` -> `lib/wizard/step-01-auth.sh`
- `bin/setup-wizard.sh` -> `lib/wizard/step-02-ssh.sh`
- `bin/setup-wizard.sh` -> `lib/wizard/step-03-config.sh`
- `bin/setup-wizard.sh` -> `lib/wizard/step-04-profile.sh`

## 8. Camino feliz
**Estado:** `parcial`

Camino feliz reconstruido con el estado actual del repo:
1. Observado: existe `devbox.json` con `shell.init_hook`, y Devbox ya materializo ese hook en `.devbox/gen/scripts/.hooks.sh`.
2. Observado: el hook calcula `root`, fija `DT_ROOT=$root/.devtools` y determina si entra en `DEVTOOLS_SPEC_VARIANT=1` cuando hay marker `.devtools/.setup_completed`, hay TTY y no se desactiva el wizard.
3. Observado: en este repo existe `.devtools/.setup_completed`, por lo que la rama mas probable con TTY es `DEVTOOLS_SPEC_VARIANT=1`.
4. Observado: el hook exporta `PATH`, prepara aliases efimeros de Git por `GIT_CONFIG_COUNT`, busca `setup-wizard.sh` en rutas candidatas y encuentra `bin/setup-wizard.sh`.
5. Observado: si esta en variante `1`, el hook pone `DEVBOX_SESSION_READY=0` y solo la cambia a `1` si `bash "$WIZARD_SCRIPT" $WIZARD_ARGS` termina bien.
6. Observado: `bin/setup-wizard.sh` fuerza `--verify-only` si ya hay marker o si no hay TTY.
7. Inferido: con el estado actual y TTY, el wizard entra a `verify-only`, valida `gh auth status` y `ssh -T git@$TEST_HOST`, y si ambos pasan devuelve `0`.
8. Observado: si el wizard devuelve `0` en esa rama, el hook imprime bienvenida, deja sugerencia `devbox run backend`, ofrece menu de rol y configura prompt con `starship` o con fallback a `PROMPT`/`PS1`.
9. No verificado: no se observo una corrida completa que confirme que el verify-only actual pasa hoy en esta maquina.

## 9. Ramas importantes
**Estado:** `confirmada`

- Confirmada: `DEVTOOLS_SPEC_VARIANT=1` solo si existe `.devtools/.setup_completed`, hay TTY y `DEVTOOLS_SKIP_WIZARD` no es `1`.
- Confirmada: si `DEVTOOLS_SPEC_VARIANT!=1`, el hook intenta `git submodule sync` y `git submodule update --init --recursive .devtools`, limpia aliases locales previos y corre el wizard con `|| true`, o sea sin bloquear la shell por fallo.
- Confirmada: si `DEVTOOLS_SPEC_VARIANT==1`, el hook exige que el wizard/verificacion pase para habilitar `DEVBOX_SESSION_READY=1`.
- Confirmada: si no hay TTY, tanto el hook como el wizard fuerzan `--verify-only`.
- Confirmada: `DEVTOOLS_SKIP_VERSION_CHECK=1` omite el aviso de version remota.
- Confirmada: `DEVTOOLS_SKIP_WIZARD=1` evita ejecutar el wizard; con variante `1` eso deja la sesion no lista.
- Abierta: rama real sin marker en este repo, porque no se removio el marker ni se corrio el trigger.
- Abierta: ramas de fallo de GH auth y SSH en runtime real.

## 10. Side effects
**Estado:** `parcial`

Observados o fuertemente sustentados desde codigo:
- Cambios efimeros de entorno:
  - `PATH` se expande con `root/bin` y `.devtools/bin`.
  - se exportan `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_*`, `GIT_CONFIG_VALUE_*`.
  - se exporta o modifica `DEVBOX_ENV_NAME`.
  - se exporta `STARSHIP_CONFIG` si `starship` existe.
- Mutacion local best-effort en rama sin marker:
  - `git config --local --unset alias.<tool>`.
  - `chmod +x` sobre scripts encontrados.
  - intento de `git submodule sync` y `git submodule update`.
- Side effects del wizard full path:
  - `gh auth login`, `gh auth refresh`, `gh auth logout`.
  - `ssh-keygen`, `ssh-add`, subida de llaves a GitHub por `gh ssh-key add`.
  - `git config --global` y opcionalmente `git config --local`.
  - posible `git remote set-url origin`.
  - creacion de `.env` si falta.
  - escritura o actualizacion de archivo de perfiles y `touch` del marker.

No verificado:
- la ejecucion material de esos side effects en esta corrida de discovery.
- el efecto real de `git submodule update` en este repo sin `.gitmodules`.

## 11. Inputs
**Estado:** `confirmada`

Obligatorios o contextuales segun codigo:
- `cwd` dentro del repo Git.
- `devbox.json`.
- estado del repo `.devbox` y `.devtools`.
- disponibilidad de `git`.

Contextuales:
- TTY presente o no.
- marker `.devtools/.setup_completed`.
- variables `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `DEVBOX_ENV_NAME`.
- `devtools.repo.yaml` para resolver `vendor_dir` y `profile_file`.
- herramientas externas del wizard:
  - verify-only: `git`, `gh`, `ssh`, `grep`;
  - full path: `git`, `gh`, `gum`, `ssh`, `ssh-keygen`, `ssh-add`.
- credenciales y conectividad hacia GitHub/SSH.

Observado en este repo:
- `.devtools/.setup_completed` existe.
- `.devtools/.git-acprc` existe.
- `.gitmodules` no existe.
- `.starship.toml` en root no existe.

## 12. Outputs
**Estado:** `parcial`

Observados desde codigo:
- mensajes en consola de version, blindaje del entorno, gate del wizard y bienvenida.
- aliases efimeros de Git disponibles solo dentro de la shell por `GIT_CONFIG_COUNT`.
- `DEVBOX_SESSION_READY` determina si aparece la ruta lista/contextualizada.
- menu interactivo de rol que puede cambiar `DEVBOX_ENV_NAME`.
- prompt con `starship` o fallback textual.

Posibles outputs del full path del wizard:
- `.env` creado o conservado.
- perfil persistido.
- marker persistido.
- remote `origin` migrado a SSH.
- configuracion global/local de Git y firma SSH.

No verificado:
- output exacto de una corrida completa hoy.
- exit code final de `devbox shell` en cada rama.

## 13. Preconditions
**Estado:** `parcial`

Para que el flujo exista:
- estar dentro de `/webapps/ihh-devtools` o un repo Git equivalente.
- tener `devbox` funcional fuera del repo.
- tener `devbox.json` valido.

Para la rama probable actual:
- TTY disponible.
- `.devtools/.setup_completed` presente.
- `bin/setup-wizard.sh` localizable.
- `gh` y `ssh` instalados.
- sesion GH y acceso SSH validos si se quiere superar `verify-only`.

Para la rama full path:
- ademas `gum`, `ssh-keygen`, `ssh-add`.
- acceso a navegador o login web de GH segun la ruta.

Abierto:
- precondiciones exactas que impone el binario `devbox` antes de llegar al hook.

## 14. Error modes
**Estado:** `confirmada`

Observados:
- si el wizard verify-only no pasa `gh auth status`, sale con error y sugiere `./bin/setup-wizard.sh --force`.
- si la validacion SSH no encuentra autenticacion exitosa, sale con error y sugiere `--force`.
- si faltan herramientas requeridas, el wizard aborta con error critico.
- si no se esta dentro de un repo Git, `ensure_repo_or_die` aborta.
- si `DEVTOOLS_SPEC_VARIANT==1` y el wizard falla o no se puede ejecutar, el hook deja `DEVBOX_SESSION_READY=0` y omite la ruta lista/contextualizada.
- en rama sin marker, el hook absorbe varios fallos con `|| true`, por lo que puede entregar shell aunque fallen bootstrap o wizard.

Sostenibles por codigo pero no corridos:
- fallo de `gh auth login` o `gh ssh-key add` en full path.
- conflicto de identidades Git duplicadas.
- fallo al cargar llave en `ssh-agent`.

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Nucleo
- `devbox.json`
  - `shell.init_hook`
  - define la logica declarativa principal del flujo.
- `.devbox/gen/scripts/.hooks.sh`
  - hook generado observado.
  - replica el `init_hook` efectivo usado por Devbox.
- `bin/setup-wizard.sh`
  - parsea argumentos, decide `verify-only` vs full path y coordina pasos del wizard.
- `lib/core/git-ops.sh`
  - `detect_workspace_root`, `ensure_repo_or_die`, helpers Git.
- `lib/core/contract.sh`
  - `devtools_load_contract`, `devtools_profile_config_file`.
- `lib/core/config.sh`
  - resuelve y carga configuracion por contrato o compat legacy.

### Soporte
- `lib/wizard/step-01-auth.sh`
  - login/refresco y chequeo 2FA en GH.
- `lib/wizard/step-02-ssh.sh`
  - seleccion/generacion de llaves y sincronizacion con GitHub.
- `lib/wizard/step-03-config.sh`
  - identidad Git y firma SSH global/local.
- `lib/wizard/step-04-profile.sh`
  - escribe perfil, toca marker y `.env`.
- `devtools.repo.yaml`
  - contrato de `vendor_dir` y `profile_file`.
- `.devtools/.git-acprc`
  - estado persistido observado del perfil legacy.

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `parcial`

- Indicio fuerte: drift entre contrato actual y estado persistido observado.
  - Observado: `devtools.repo.yaml` declara `profile_file: .git-acprc` en root.
  - Observado: el estado actual existente esta en `.devtools/.git-acprc`.
  - Observado: `lib/core/config.sh` conserva fallback a `LEGACY_VENDOR_CONFIG`.
  - Lectura: parece seam de compatibilidad entre ubicacion nueva y legacy.
- Indicio fuerte: el hook sigue intentando tratar `.devtools` como submodulo.
  - Observado: ejecuta `git submodule sync/update` sobre `.devtools`.
  - Observado: no existe `.gitmodules` en la raiz.
  - Lectura: la rama puede ser compatibilidad tolerada o bootstrap antiguo.
- Sospecha: `STARSHIP_CONFIG` apunta a `.starship.toml` en root aunque ese archivo no existe hoy.
  - No queda claro si eso es tolerado por `starship` o si es simple fallback incompleto.

## 17. Unknowns
**Estado:** `confirmada`

- No verificado: si el `verify-only` actual pasa o falla hoy con las credenciales y red de esta maquina.
- No verificado: efecto real de `git submodule update --init --recursive .devtools` en este repo sin `.gitmodules`.
- No verificado: impacto practico del drift entre `.git-acprc` root contractual y `.devtools/.git-acprc` observado.
- No verificado: comportamiento real de `starship` cuando `STARSHIP_CONFIG` apunta a un archivo inexistente.
- No verificado: rama `DEVTOOLS_SKIP_WIZARD=1`.
- No verificado: rama sin TTY.
- No verificado: rama de fallo GH auth.
- No verificado: rama de fallo SSH.
- No verificado: ruta sin marker `.devtools/.setup_completed`.
- No verificado: salida exacta y cierre efectivo de una corrida completa de `devbox shell`.

## 18. Evidencia
**Estado:** `confirmada`

- `path:` `devbox.json`
  - `hallazgo:` `shell.init_hook` define root, gate del wizard, aliases efimeros, menu y prompt.
- `path:` `.devbox/gen/scripts/.hooks.sh`
  - `hallazgo:` hook generado por Devbox observado en disco; replica la logica efectiva disponible del repo.
- `path:` `bin/setup-wizard.sh`
  - `hallazgo:` decide `verify-only`, checkea herramientas, GH auth y SSH, o corre full path.
- `path:` `lib/wizard/step-04-profile.sh`
  - `hallazgo:` crea/actualiza perfil, `.env`, marker y posible cambio de remote.
- `path:` `lib/core/contract.sh`
  - `hallazgo:` resuelve `DEVTOOLS_PROFILE_CONFIG` y mantiene contrato/fallbacks.
- `path:` `lib/core/config.sh`
  - `hallazgo:` prioriza config contractual pero conserva `LEGACY_VENDOR_CONFIG`.
- `path:` `devtools.repo.yaml`
  - `hallazgo:` `vendor_dir: .devtools`, `profile_file: .git-acprc`.
- `path:` `.devtools/.git-acprc`
  - `hallazgo:` perfil persistido observado en ubicacion legacy.
- `corrida/validacion:` `find .devbox ...`, `find .devtools ...`
  - `hallazgo:` existen `.devbox`, `.devtools`, marker y perfil; no existe `.gitmodules`.
- `corrida/validacion:` `git config --local --get-regexp '^alias\\.'`
  - `hallazgo:` no habia aliases locales persistidos antes del hook.
- `corrida/validacion:` `bash -n bin/setup-wizard.sh lib/wizard/step-*.sh`
  - `hallazgo:` validacion sintactica basica de los scripts inspeccionados.
- `corrida/validacion:` `git remote -v`
  - `hallazgo:` `origin` ya usa SSH con alias `github.com-reydem`.

## 19. Validacion segura
**Estado:** `confirmada`

Se realizo validacion estatica y de baja intervencion:
- lectura de `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, wizard y helpers;
- inspeccion de estado actual del repo en `.devtools`, `.devbox`, `git remote -v` y `.git/config`;
- validacion sintactica `bash -n` sobre scripts del wizard.

Que quedo confirmado con esa validacion:
- la cadena interna desde `init_hook` hasta `setup-wizard.sh`;
- las bifurcaciones principales por marker, TTY y flags;
- los side effects potenciales del full path;
- el estado persistido actual del repo.

Que siguio sin confirmarse:
- ejecucion real del binario `devbox`;
- verify-only actual con red/credenciales reales;
- efecto material de submodule update;
- comportamiento efectivo de `starship`.

Por que no se ejecuto el trigger real completo:
- correr `devbox shell` aqui podia invocar checks de GH/SSH, acceso de red, mutaciones efimeras del entorno y, en ramas full path, cambios globales/locales y operaciones contra GitHub;
- el mandato de discovery priorizaba validacion segura de baja intervencion y dejar visibles los unknowns si la corrida real implicaba side effects o riesgo fuera de ese umbral.

## 20. Criterio de salida para promover a spec-first
**Estado:** `parcial`

Quedo suficientemente claro:
- por donde entra internamente el flujo dentro del repo;
- que el hook es el nucleo observable;
- que el gate principal depende de marker, TTY y resultado del wizard;
- que el wizard decide entre verificacion y full path con side effects materiales.

Sigue abierto:
- verify-only actual;
- efecto del bootstrap de submodulo sin `.gitmodules`;
- drift de configuracion root vs legacy;
- comportamiento real de `starship`;
- ramas no verificadas `DEVTOOLS_SKIP_WIZARD`, no TTY, fallo GH/SSH y sin marker.

Lectura de salida:
- lo observado ya permite entender el flujo base y escribir spec-first si se acepta trabajar con estos unknowns visibles;
- no corresponde declarar promocion automatica desde este documento;
- la aclaracion minima para reducir riesgo antes de promover seria una validacion controlada del camino `verify-only` o evidencia equivalente de runtime sin abrir el full path mutante.

## 21. Respuesta canonica del discovery
**Estado:** `parcial`

Cuando el usuario ejecuta `devbox shell` en este repo, el entrypoint externo mas probable es el binario `devbox`, pero eso solo quedo parcial; lo que si esta observado es que el flujo del repo entra en `devbox.json` y su hook generado `.devbox/gen/scripts/.hooks.sh`. Ahi el sistema resuelve la raiz, decide si hay marker `.devtools/.setup_completed`, intenta bootstrap/aliases efimeros de Git, busca `setup-wizard.sh` y usa ese wizard como gate. Si la verificacion requerida pasa, la sesion queda lista, imprime bienvenida, ofrece menu de rol y prepara prompt; si falla en la variante estricta, omite la ruta contextualizada. La evidencia llega hasta esa logica, el wizard y el estado actual del repo, no hasta una corrida completa con red, credenciales y side effects globales.

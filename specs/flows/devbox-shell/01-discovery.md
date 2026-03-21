# Discovery: `devbox-shell`

## Resumen rapido
- **Estado de discovery:** `lista para promover`
- **Flujo objetivo:** `entrada a shell local de devbox y export surface de print-env`
- **Trigger real:** `devbox shell` en la raiz del repo; subfrontera observable `devbox shell --print-env`
- **Pregunta principal:** `cuando se entra al shell de devbox para este repo, que parte controla realmente el repo, que decide, que toca y que expone a consumidores interactivos y no interactivos`
- **Respuesta corta actual:** el binario externo `devbox` toma `devbox.json` como entry artifact controlado por el repo. Desde ahi el repo decide root, variante de sesion, carga efimera de herramientas corporativas, resolucion del wizard y la habilitacion o no de la ruta lista/contextualizada. En paralelo, `lib/promote/workflows/common.sh` consume la subfrontera `devbox shell --print-env` para obtener toolchain y ejecutar `git-cliff`.
- **Unknowns criticos:** si la subfrontera `devbox shell --print-env` omite deliberadamente el `init_hook` completo; semantica exacta del prompt cuando falta `.starship.toml`; relevancia real del intento de submodulo en un repo sin `.gitmodules`

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- identificador corto, estable y especifico para la frontera `devbox shell` de este repo;
- no describe `devbox-app`, CI general ni otros workflows del repo.

## 2. Objetivo observable
**Estado:** `confirmada`

Permitir que un operador entre a un shell local de devbox para este repo y reciba un entorno de trabajo contextualizado por el repo: toolchain de Devbox, resolucion de root, carga efimera de herramientas corporativas y, cuando aplica la variante estricta, un gate de verificacion previo a habilitar la ruta lista/contextualizada.

## 3. Trigger real / entrada real
**Estado:** `confirmada`

- Entrada principal: comando `devbox shell` ejecutado dentro de la raiz Git del repo.
- Subfrontera observable relevante: `devbox shell --print-env`, usada por `lib/promote/workflows/common.sh` para obtener variables exportadas antes de correr `git-cliff`.

## 4. Pregunta principal
**Estado:** `confirmada`

Cuando un usuario o un workflow llama `devbox shell` o `devbox shell --print-env` para este repo, por donde entra el control repo-especifico, que decisiones de sesion toma, que side effects puede producir y que salida observable queda disponible para consumidores reales.

## 5. Frontera del analisis
**Estado:** `confirmada`

Dentro del discovery:
- `devbox.json` como entry artifact controlado por el repo.
- `bin/setup-wizard.sh` y sus dependencias base (`lib/core/utils.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/config.sh`).
- `devtools.repo.yaml`, `.devtools/.setup_completed` y `.devtools/.git-acprc` como insumos de contrato y de variante.
- `lib/promote/workflows/common.sh` como consumidor real de `devbox shell --print-env`.
- corrida segura de `devbox shell --print-env` en una copia temporal del repo.

Fuera de este discovery:
- implementacion interna de Devbox/Nix fuera de lo observable desde el repo;
- pasos detallados de `lib/wizard/step-01-auth.sh` a `step-04-profile.sh`;
- app runtime (`devbox-app`), CI general y otras familias metodologicas.

## 6. Entry point
**Estado:** `confirmada`

- Entry point principal: `devbox shell`.
- Archivo del entry artifact: `devbox.json`.
- Punto repo-controlado inicial: `shell.init_hook`.
- Activador inmediato: el binario externo `devbox` lee `devbox.json` y prepara el shell.
- Por que se considera entrypoint principal: es la unica definicion repo-especifica de shell presente y concentra root resolution, seleccion de variante, gate del wizard y saludo/prompt.

Alternativas descartadas:
- `bin/setup-wizard.sh`: no es el entrypoint del flujo; es un componente delegado por `init_hook`.
- `lib/promote/workflows/common.sh`: es consumidor de `devbox shell --print-env`, no entrypoint principal del flujo.

## 7. Dispatcher chain
**Estado:** `confirmada`

- `devbox shell` -> `devbox.json:shell.init_hook`
- `devbox.json:shell.init_hook` -> resolucion de `root`, `DT_ROOT`, `DEVTOOLS_SPEC_VARIANT`
- `devbox.json:shell.init_hook` -> posible sync/update de submodulo y aviso de version
- `devbox.json:shell.init_hook` -> PATH/GIT_CONFIG efimero para herramientas corporativas
- `devbox.json:shell.init_hook` -> localizacion y ejecucion de `bin/setup-wizard.sh`
- `bin/setup-wizard.sh` -> `lib/core/utils.sh` + `lib/core/git-ops.sh` + `lib/core/contract.sh` + `lib/core/config.sh`
- `bin/setup-wizard.sh` -> modo `--verify-only` o full path segun TTY, marker y argumentos
- `bin/setup-wizard.sh` -> validaciones GH/SSH o pasos completos del wizard
- `devbox.json:shell.init_hook` -> decision final `DEVBOX_SESSION_READY` -> saludo / rol / prompt

Cadena secundaria relevante:
- `lib/promote/workflows/common.sh` -> `devbox shell --print-env` -> `eval "$devbox_env"` -> `git-cliff`

## 8. Camino feliz
**Estado:** `confirmada`

Camino feliz interactivo hoy observable por configuracion del repo:
1. El usuario entra con `devbox shell` desde un repo Git que ya tiene `.devtools/.setup_completed`.
2. `devbox.json` resuelve la raiz real del workspace y fija `DEVTOOLS_SPEC_VARIANT=1` porque existe marker, hay TTY y no se salto el wizard.
3. El `init_hook` prepara PATH y una overlay efimera de aliases Git via `GIT_CONFIG_*` en memoria.
4. El `init_hook` encuentra `bin/setup-wizard.sh` y lo ejecuta en modo `--verify-only`.
5. `setup-wizard.sh` resuelve root/contrato, carga config y valida repo, sesion GH CLI y conexion SSH.
6. Si la verificacion satisface la variante estricta, el `init_hook` cambia `DEVBOX_SESSION_READY` a `1`.
7. Solo entonces se habilita la ruta lista/contextualizada: mensajes de bienvenida, seleccion opcional de rol y prompt.

Camino feliz no interactivo observado:
1. Un consumidor llama `devbox shell --print-env`.
2. La corrida segura en copia temporal devolvio un bloque de `export ...`.
3. Ese bloque incluyo `DEVBOX_PROJECT_ROOT`, `DEVBOX_ENV_NAME`, `PATH` con `.devbox/nix/profile/default/bin` y `HOST_PATH` con herramientas como `git-cliff` y `bats`.
4. La misma corrida no dejo aliases persistentes en `git config --local`.

Punto hasta donde llega la evidencia real:
- el gate interactivo esta confirmado por lectura de `devbox.json` y `bin/setup-wizard.sh`;
- la subfrontera `--print-env` esta confirmada por corrida segura en copia temporal;
- no quedo confirmada por ejecucion una sesion interactiva completa con TTY, GH auth y SSH reales.

## 9. Ramas importantes
**Estado:** `confirmada`

- Rama de variante: `DEVTOOLS_SPEC_VARIANT=1` solo si existe `.devtools/.setup_completed`, hay TTY y no se definio `DEVTOOLS_SKIP_WIZARD=1`.
- Rama permisiva: cuando `DEVTOOLS_SPEC_VARIANT != 1`, se intenta `git submodule sync/update`, se hace `git config --local --unset alias.*` best effort y el wizard se ejecuta sin bloquear la ruta lista/contextualizada.
- Rama estricta: cuando `DEVTOOLS_SPEC_VARIANT == 1`, `DEVBOX_SESSION_READY` arranca en `0` y solo pasa a `1` si `setup-wizard.sh` verifica con exito.
- Rama no interactiva: `setup-wizard.sh` fuerza `--verify-only` si no hay TTY.
- Rama de consumidor: `lib/promote/workflows/common.sh` usa `devbox shell --print-env` solo si `git-cliff` no esta disponible directamente.

## 10. Side effects
**Estado:** `confirmada`

- Git local del repo: en variante no estricta se intenta limpiar aliases persistentes con `git config --local --unset alias.$tool`.
- Permisos de archivos: en variante no estricta se hace `chmod +x` sobre el script oficial encontrado.
- Submodulos Git: el `init_hook` intenta `git submodule sync/update`, aunque en este repo no existe `.gitmodules`.
- Filesystem local del wizard: `setup-wizard.sh` asegura la carpeta del marker con `mkdir -p`.
- Red / credenciales: en verify-only se llama `gh auth status` y `ssh -T`.
- Configuracion global Git: `lib/core/config.sh` puede fijar `init.defaultBranch=main` si aun no existe y no se esta en CI.
- Entorno del proceso: la subfrontera `--print-env` exporta PATH/toolchain y variables de DB/API observables.

## 11. Inputs
**Estado:** `confirmada`

Obligatorios:
- `devbox.json` presente en la raiz del repo.
- estar dentro de un repo Git.
- binario `devbox` disponible.

Contextuales:
- existencia de `.devtools/.setup_completed`;
- estado TTY;
- `devtools.repo.yaml`;
- `.devtools/.git-acprc` como profile config resuelto por contrato.

Opcionales o de control:
- `DEVTOOLS_SKIP_WIZARD`;
- `DEVTOOLS_SKIP_VERSION_CHECK`;
- `--verify-only` y `--force` para `bin/setup-wizard.sh`.

## 12. Outputs
**Estado:** `confirmada`

Interactivos:
- habilitacion o no de la ruta lista/contextualizada;
- mensajes de bienvenida y de fallo de verificacion;
- seleccion opcional de rol y prompt.

No interactivos:
- bloque de `export ...` devuelto por `devbox shell --print-env`;
- en la corrida segura observada: `DEVBOX_PROJECT_ROOT`, `DEVBOX_ENV_NAME`, `PATH`, `HOST_PATH`, `RUN_MIGRATIONS`, `RUN_SEED`, `VITE_API_URL`.

Errores visibles:
- `No pude obtener entorno de Devbox para ejecutar git-cliff.` en `common.sh` si falla `print-env`.
- errores criticos del wizard por falta de herramientas, GH auth o SSH.

## 13. Preconditions
**Estado:** `confirmada`

- Repo Git valido (`ensure_repo_or_die`).
- Herramientas requeridas para el wizard:
  - verify-only: `git`, `gh`, `ssh`, `grep`
  - full path: `git`, `gh`, `gum`, `ssh`, `ssh-keygen`, `ssh-add`
- Perfil/config resoluble desde `devtools.repo.yaml` y `.git-acprc`.
- Para la ruta estricta interactiva: marker `.devtools/.setup_completed`, TTY y verificacion GH/SSH exitosa.
- Para `--print-env`: Devbox debe poder resolver el entorno del repo.

## 14. Error modes
**Estado:** `confirmada`

- fuera de repo Git: `setup-wizard.sh` aborta via `ensure_repo_or_die`.
- herramienta requerida ausente: aborta con `Error Critico`.
- GH CLI no autenticado: verify-only falla.
- conexion SSH no valida: verify-only falla y recomienda `./bin/setup-wizard.sh --force`.
- `common.sh` aborta si `devbox shell --print-env` falla.
- en sandbox sin red, una corrida inicial de `devbox shell --print-env` fallo intentando resolver `cache.nixos.org`; con permiso de red la corrida segura si devolvio exports.

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Nucleo
- `devbox.json` -> `shell.init_hook`
- `bin/setup-wizard.sh`
- `lib/core/git-ops.sh` -> `detect_workspace_root`, `ensure_repo_or_die`
- `lib/core/contract.sh` -> `devtools_load_contract`, `devtools_profile_config_file`
- `lib/core/config.sh`
- `lib/promote/workflows/common.sh` -> fallback con `devbox shell --print-env`

### Soporte
- `devtools.repo.yaml`
- `.devtools/.setup_completed`
- `.devtools/.git-acprc`
- `.devbox/gen/flake/flake.nix`

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `parcial`

- `devbox.json` intenta `git submodule sync/update` sobre `.devtools`, pero este repo no tiene `.gitmodules` y `.devtools` esta trackeado como directorio normal.
- `lib/core/config.sh` mantiene rutas de config por contrato y compat legacy (`<vendor_dir>/.git-acprc` y `.git-acprc` en raiz).
- La corrida observada de `devbox shell --print-env` no expuso `GIT_CONFIG_COUNT`, `DEVBOX_SESSION_READY` ni `root/bin`, lo que sugiere que esta subfrontera no replica todo el `init_hook` interactivo o no lo materializa igual.
- `devbox.json` exporta `STARSHIP_CONFIG="$root/.starship.toml"`, pero el archivo no existe en la raiz actual.

## 17. Unknowns
**Estado:** `confirmada`

- si `devbox shell --print-env` omite deliberadamente el `init_hook` completo o solo omite parte de sus side effects observables;
- si el prompt con `starship` cae siempre de forma segura al faltar `.starship.toml`;
- si la rama de submodulo tiene relevancia practica en otro checkout del mismo flujo;
- si la escritura global de `init.defaultBranch=main` via `lib/core/config.sh` esta siempre aceptada como side effect de este flujo.

## 18. Evidencia
**Estado:** `confirmada`

- `path:` `devbox.json`
- `path:` `bin/setup-wizard.sh`
- `path:` `lib/core/git-ops.sh`
- `path:` `lib/core/contract.sh`
- `path:` `lib/core/config.sh`
- `path:` `lib/promote/workflows/common.sh`
- `path:` `devtools.repo.yaml`
- `path:` `.devtools/.setup_completed`
- `path:` `.devtools/.git-acprc`
- `corrida/validacion:` copia temporal del repo + `DEVTOOLS_SKIP_VERSION_CHECK=1 DEVTOOLS_SKIP_WIZARD=1 devbox shell --print-env`
- `salida relevante:` bloque real de `export ...` con `DEVBOX_PROJECT_ROOT`, `DEVBOX_ENV_NAME`, `PATH` y `HOST_PATH`
- `verificacion adicional:` `git config --local --get-regexp '^alias\\.'` quedo vacio en la copia temporal tras `--print-env`

## 19. Validacion segura
**Estado:** `confirmada`

Se valido en una copia temporal del repo, no sobre el working tree real:
- comando: `DEVTOOLS_SKIP_VERSION_CHECK=1 DEVTOOLS_SKIP_WIZARD=1 devbox shell --print-env`
- modo seguro: copia temporal + sin wizard + sin tocar `.git/config` del repo real
- quedo confirmado: existe una subfrontera observable `print-env` con exports reales consumibles por scripts
- siguio sin confirmarse: una sesion interactiva completa con TTY, menu de rol y gate GH/SSH reales
- riesgo de ejecutar flujo real: mutacion local de aliases/permisos en variante permisiva, chequeos de red/credenciales, side effects globales en Git via config cargada por wizard
- alternativa estatica usada: lectura directa de `devbox.json`, `bin/setup-wizard.sh` y libs core

## 20. Criterio de salida para promover a spec-first
**Estado:** `confirmada`

- Quedo suficientemente claro:
  - el entrypoint repo-controlado;
  - la bifurcacion entre variante estricta y permisiva;
  - el rol del wizard;
  - la subfrontera `print-env` y su consumidor real.
- Sigue abierto:
  - semantica exacta de `print-env` frente al `init_hook` interactivo;
  - comportamiento exacto del prompt.
- Los unknowns pendientes no bloquean promotion porque no impiden formular un contrato inicial honesto del flujo.
- La aclaracion minima que faltaria para mas certeza futura es una validacion interactiva con TTY controlado, pero no es necesaria para pasar a spec-first.

## 21. Respuesta canonica del discovery
**Estado:** `confirmada`

Cuando un operador entra con `devbox shell`, el control repo-especifico entra por `devbox.json`, decide la raiz real y la variante de sesion, localiza y ejecuta `setup-wizard.sh`, aplica o no el gate de verificacion y termina habilitando o negando la ruta lista/contextualizada. Cuando un consumidor llama `devbox shell --print-env`, la evidencia real muestra que termina devolviendo un bloque de exports de toolchain/env que `common.sh` puede evaluar para correr `git-cliff`.

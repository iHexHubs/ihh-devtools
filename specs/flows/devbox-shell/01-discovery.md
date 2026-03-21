# Discovery: `devbox-shell`

## Resumen rapido
- **Estado de discovery:** `lista para promover`
- **Flujo objetivo:** `bootstrap y exportacion contractual de entorno via devbox shell`
- **Trigger real:** `devbox shell` y, para automatizacion, `devbox shell --print-env`
- **Pregunta principal:** `cuando se activa devbox shell en este repo, por donde entra, que decide, que toca y donde termina la parte observable del flujo`
- **Respuesta corta actual:** `El flujo entra por Devbox, consume devbox.json y ejecuta el init_hook generado en .devbox/gen/scripts/.hooks.sh. Ese hook resuelve el root, prepara PATH y alias Git efimeros, localiza setup-wizard.sh y solo habilita la ruta "lista/contextualizada" cuando la verificacion del wizard satisface la variante activa. Para automatizacion, el consumidor principal es --print-env, usado por scripts del repo para importar el entorno antes de correr checks o git-cliff.`
- **Unknowns criticos:** `no hay corrida nueva en este run; la observacion llega hasta codigo, artefactos generados y tests existentes no ejecutados`

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- slug estable y especifico para el flujo `devbox shell` del repo.

## 2. Objetivo observable
**Estado:** `confirmada`

El objetivo observable del flujo es abrir o describir un shell de Devbox contextualizado para este repo, con variables de entorno base, bootstrap de herramientas corporativas en memoria y una compuerta de "session ready" que depende de la verificacion del setup wizard cuando aplica.

Observado:
- `devbox.json` define paquetes, variables `env` y `shell.init_hook`.
- `tests/contracts/devbox-shell/run-contract-checks.sh` usa `eval "$(devbox shell --print-env)"` para importar el entorno del repo antes de correr `bats`.

Inferido con base fuerte:
- para un humano, `devbox shell` busca dejar el shell listo y contextualizado;
- para automatizacion, `--print-env` expone el entorno sin entrar en sesion interactiva.

## 3. Trigger real / entrada real
**Estado:** `confirmada`

Entradas reales observadas:
- comando `devbox shell`
- comando `devbox shell --print-env`
- consumo indirecto desde `lib/promote/workflows/common.sh`
- consumo indirecto desde `tests/contracts/devbox-shell/run-contract-checks.sh`

## 4. Pregunta principal
**Estado:** `confirmada`

La pregunta de discovery fue:

`cuando pasa devbox shell en este repo, que parte del comportamiento pertenece al flujo principal observable, que ramas lo gobiernan y cual es el corte de evidencia local suficiente para pasar a spec-first`

## 5. Frontera del analisis
**Estado:** `confirmada`

Dentro del analisis:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- wiring entre `setup-wizard.sh`, `lib/core/contract.sh` y `lib/wizard/step-04-profile.sh`
- consumidores repo-locales de `devbox shell --print-env`
- side effects y guards visibles desde el codigo

Fuera del analisis:
- flujos de producto `devbox run backend` y `frontend`
- ejecucion real de verificacion GH/SSH
- CI real
- familias `Context-Driven` y `Agentic QA`

## 6. Entry point
**Estado:** `confirmada`

Entrypoint principal:
- `devbox shell` leyendo `devbox.json` `shell.init_hook`

Path relevante:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`

Caller inmediato, cuando hay automatizacion:
- `lib/promote/workflows/common.sh` llama `devbox shell --print-env`
- `tests/contracts/devbox-shell/run-contract-checks.sh` llama `devbox shell --print-env`

Por que este es el entrypoint principal:
- `setup-wizard.sh` no se invoca directamente como flujo principal; queda subordinado al `init_hook`.
- El comportamiento contractual observable del shell nace en Devbox y desciende hacia el wizard, no al reves.

## 7. Dispatcher chain
**Estado:** `confirmada`

Cadena principal confirmada:
- `devbox shell[--print-env] -> devbox.json shell.init_hook -> .devbox/gen/scripts/.hooks.sh -> root/devtools path detection -> optional submodule sync/update + version notice -> PATH/GIT_CONFIG ephemeral setup -> setup-wizard discovery and execution -> readiness gate -> welcome/menu/prompt branch`

Cadena secundaria relevante para la resolucion contractual del profile file:
- `.devbox/gen/scripts/.hooks.sh -> bin/setup-wizard.sh -> lib/core/contract.sh -> devtools_profile_config_file() -> export DEVTOOLS_WIZARD_RC_FILE -> lib/wizard/step-04-profile.sh`

## 8. Camino feliz
**Estado:** `parcial`

Camino feliz observado estaticamente:
1. Devbox carga `devbox.json`, exporta las variables base del repo y ejecuta el `init_hook`.
2. El hook resuelve `root`, `DT_ROOT` y una lista de `candidates` para buscar scripts canonicos.
3. El hook inserta `root/bin` y `DT_BIN` al `PATH`, limpia aliases Git persistentes viejos y publica aliases Git efimeros via `GIT_CONFIG_COUNT`.
4. El hook localiza `setup-wizard.sh`.
5. Si existe marker `.devtools/.setup_completed`, hay TTY y no se salta el wizard, activa `DEVTOOLS_SPEC_VARIANT=1` y deja `DEVBOX_SESSION_READY=0` hasta que la verificacion del wizard pase.
6. Si la verificacion pasa, habilita la ruta contextualizada; si no pasa, deja la sesion no lista y emite un mensaje explicito de omision.
7. Si la sesion queda lista, emite mensajes de bienvenida y, en TTY, permite eleccion de rol y customizacion del prompt.

Camino feliz observado para automatizacion:
1. Un consumidor llama `devbox shell --print-env`.
2. El repo espera que la salida incluya al menos `DEVBOX_ENV_NAME="IHH"` y `DEVBOX_PROJECT_ROOT="<repo_root>"`.
3. El consumidor `eval`ua esa salida y continua con herramientas del entorno (`git-cliff`, `bats`, `jq`).

Parte inferida y no verificada por corrida nueva:
- orden exacto y quoting completo de toda la salida generada por Devbox;
- comportamiento exacto del menu interactivo de roles en esta corrida.

## 9. Ramas importantes
**Estado:** `confirmada`

Ramas principales:
- `DEVTOOLS_SPEC_VARIANT`
  - `0`: el hook tolera bootstrap y wizard sin exigir "ready".
  - `1`: la sesion solo queda lista si la verificacion del wizard pasa.
- `DEVTOOLS_SKIP_WIZARD`
  - evita la ejecucion del wizard.
- `DEVTOOLS_SKIP_VERSION_CHECK`
  - evita el aviso de version remoto.
- presencia o ausencia de TTY
  - no TTY fuerza `--verify-only`.
- presencia o ausencia de `WIZARD_SCRIPT`
  - si falta y la variante exige verificacion, la sesion queda no lista.

Ramas secundarias relevantes:
- presencia de `.devtools/.setup_completed`
- disponibilidad de `gum` y `starship`
- existencia o no de `.gitmodules`

## 10. Side effects
**Estado:** `parcial`

Side effects confirmados por codigo:
- intento de `git submodule sync --recursive`
- intento de `git submodule update --init --recursive .devtools`
- lectura de tags remotos via `git ls-remote` si hay URL en `.gitmodules`
- `git config --local --unset alias.<tool>` cuando `DEVTOOLS_SPEC_VARIANT != 1`
- `chmod +x` sobre scripts corporativos encontrados
- export de PATH y variables `GIT_CONFIG_*` efimeras

Side effects confirmados por el wizard en full path:
- puede crear o actualizar el archivo de perfiles
- puede tocar `.env`
- puede tocar el marker de setup completado

Side effects no verificados por corrida nueva:
- ocurrencia real de llamadas de red y sus resultados
- escritura efectiva de perfiles durante esta corrida

## 11. Inputs
**Estado:** `confirmada`

Obligatorios o estructurales:
- `devbox.json`
- estar dentro del repo
- comando `devbox shell` o `devbox shell --print-env`

Contextuales:
- `.devtools/.setup_completed`
- `devtools.repo.yaml`
- TTY o no TTY
- `.gitmodules` si existe

Variables de entorno relevantes:
- `DEVTOOLS_SKIP_WIZARD`
- `DEVTOOLS_SKIP_VERSION_CHECK`
- `DEVBOX_ENV_NAME`
- `DEVTOOLS_CONTRACT_FILE`
- `DEVTOOLS_PROFILE_CONFIG`

## 12. Outputs
**Estado:** `parcial`

Outputs observados o sostenidos por evidencia del repo:
- ayuda CLI con flags `--print-env`, `--config`, `--env`
- salida de `--print-env` con exports del entorno base del repo
- mensajes de blindaje, version y welcome
- mensaje explicito de omision cuando la variante exige verificacion y no se satisface
- variables efimeras de config Git y PATH listas para el proceso shell

Output interno relevante:
- `DEVTOOLS_WIZARD_RC_FILE` exportado por `setup-wizard.sh` para `step-04-profile.sh`

## 13. Preconditions
**Estado:** `parcial`

Precondiciones visibles:
- Devbox instalado y capaz de procesar `devbox.json`
- repo accesible
- `bin/setup-wizard.sh` disponible para la rama contextualizada

Precondiciones adicionales para la verificacion del wizard:
- `git`, `gh`, `ssh`, `grep` disponibles en `--verify-only`
- TTY si se quiere pasar por la rama interactiva completa

Precondiciones no verificadas aqui:
- autenticacion GH valida
- conectividad SSH funcional

## 14. Error modes
**Estado:** `parcial`

Fallos o salidas tempranas sostenibles:
- si `devbox shell --print-env` falla, `lib/promote/workflows/common.sh` aborta con `die`.
- si faltan herramientas requeridas, `setup-wizard.sh` sale con error.
- si falla `gh auth status` o falla la comprobacion SSH en `--verify-only`, el wizard sale con error.
- si la variante exige verificacion y el wizard falla o falta, el hook imprime que se omite la ruta lista/contextualizada.

No sustentado como hecho observado en esta corrida:
- exit code exacto de cada rama del init_hook bajo la version actual de Devbox.

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Nucleo
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`
- `lib/wizard/step-04-profile.sh`

### Soporte
- `lib/core/git-ops.sh`
- `lib/core/utils.sh`
- `lib/promote/workflows/common.sh`
- `tests/contracts/devbox-shell/devbox-shell-contract.bats`
- `tests/contracts/devbox-shell/run-contract-checks.sh`
- `devtools.repo.yaml`

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `confirmada`

Hechos confirmados:
- el hook sigue intentando operaciones de submodulo y lectura de `.gitmodules`, pero el repo actual no tiene `.gitmodules`.
- existe un archivo legacy `.devtools/.git-acprc`, aunque `devtools.repo.yaml` declara `config.profile_file: .git-acprc`.
- el hook busca scripts en rutas redundantes, incluyendo variantes anidadas `.devtools/.devtools/bin`.

Sospecha util:
- puede haber consumidores legacy del archivo `.devtools/.git-acprc` fuera del contrato actual, pero no quedaron localizados en esta corrida.

## 17. Unknowns
**Estado:** `confirmada`

- No se ejecuto `devbox shell --print-env`, por lo que la salida exacta se sostiene por artefactos y tests existentes, no por nueva observacion.
- No se confirmo si otro flujo del repo sigue dependiendo del archivo legacy `.devtools/.git-acprc`.
- No se verifico la rama interactiva completa de rol/prompt ni el exito real de la verificacion GH/SSH.

## 18. Evidencia
**Estado:** `confirmada`

- `path:` `devbox.json`
- `path:` `.devbox/gen/scripts/.hooks.sh`
- `path:` `bin/setup-wizard.sh`
- `path:` `lib/core/contract.sh`
- `path:` `lib/core/git-ops.sh`
- `path:` `lib/core/utils.sh`
- `path:` `lib/wizard/step-04-profile.sh`
- `path:` `lib/promote/workflows/common.sh`
- `path:` `tests/contracts/devbox-shell/devbox-shell-contract.bats`
- `path:` `tests/contracts/devbox-shell/run-contract-checks.sh`
- `path:` `devtools.repo.yaml`
- `corrida/validacion:` inspeccion estatica del repo y del hook generado ya presente en `.devbox/`

## 19. Validacion segura
**Estado:** `parcial`

Validacion segura realizada:
- cruce estatico entre `devbox.json` y `.devbox/gen/scripts/.hooks.sh`
- cruce estatico entre el wiring del wizard y las expectativas del test contractual existente
- localizacion del consumidor automatizado en `lib/promote/workflows/common.sh`

Que quedo confirmado:
- la cadena principal del flujo
- el gating por verificacion
- la resolucion contractual del profile file

Que siguio sin confirmarse:
- ejecucion real del shell y orden exacto de exports

Riesgo de ejecutar el flujo real:
- puede tocar git config local, submodulos, red, marker y archivos de perfil

Alternativa de baja intervencion usada:
- inspeccion estatica exclusivamente

## 20. Criterio de salida para promover a spec-first
**Estado:** `confirmada`

Quedo suficientemente claro:
- cual es el trigger real
- cual es el entrypoint principal
- cual es la cadena principal
- que consumidores repo-locales dependen de `--print-env`
- que el perfil contractual y la ruta "ready" dependen de wiring explicito

Sigue abierto:
- cobertura runtime exacta de algunas ramas
- dependencia real de consumidores legacy sobre `.devtools/.git-acprc`

Juicio de promocion:
- los unknowns pendientes no bloquean `spec-first` porque no impiden formular la promesa contractual visible del flujo; solo limitan el detalle runtime que luego debera mantenerse visible en `spec-anchored`.

## 21. Respuesta canonica del discovery
**Estado:** `confirmada`

Cuando pasa `devbox shell` en este repo, el flujo entra por Devbox, consume `devbox.json` y ejecuta el `init_hook` generado. Ese hook resuelve el root del workspace, prepara PATH y aliases Git efimeros, intenta bootstrap compatible de `.devtools`, localiza `setup-wizard.sh` y decide si la sesion puede declararse lista segun marker, TTY y resultado de verificacion. Para automatizacion, `devbox shell --print-env` es la salida contractual observable que otros scripts importan para continuar; el flujo termina en un entorno exportado, y solo agrega la ruta contextualizada completa cuando la verificacion requerida no falla.

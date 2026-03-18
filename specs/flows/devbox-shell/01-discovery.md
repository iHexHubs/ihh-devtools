# Discovery: `devbox-shell`

## Resumen rápido
- **Estado de discovery:** `lista para promover`
- **Flujo objetivo:** entrada a `devbox shell` en este repo
- **Trigger real:** operador ejecuta `devbox shell` en la raíz del repo o dentro de su work tree Git
- **Pregunta principal:** cuando alguien entra con `devbox shell`, ¿qué parte controla el repo, qué decide antes de dejar la sesión lista y qué superficies toca?
- **Respuesta corta actual:** el binario externo `devbox` toma [devbox.json](/webapps/ihh-devtools/devbox.json) y ejecuta el `shell.init_hook` del repo, materializado en [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh). Ese hook resuelve el root, alinea `.devtools`, hace chequeos best-effort de submódulo y versión, carga aliases Git efímeros, intenta `setup-wizard.sh` y solo deja la sesión “ready” si pasa la compuerta `DEVBOX_SESSION_READY`. En modo full, el wizard puede autenticar GH, gestionar llaves SSH, escribir identidad/firma Git y persistir `.git-acprc`, `.env` y `.setup_completed`.
- **Unknowns críticos:** no hubo corrida real del binario `devbox`; no se confirmó runtime exacto de cada rama de red/submódulo/GitHub; el archivo generado `.hooks.sh` se tomó como materialización vigente del hook, no como ejecución observada.

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- identificador estable y específico para el flujo de entrada al shell de Devbox en este repo.

## 2. Objetivo observable
**Estado:** `confirmada`

Describir la parte del flujo que el repo controla cuando un operador abre `devbox shell`: preparación efímera del entorno, compuertas para dejar la sesión lista y posibles side effects del wizard asociado.

## 3. Trigger real / entrada real
**Estado:** `confirmada`

- **Observado:** el trigger visible para el operador es ejecutar `devbox shell`.
- **Observado:** el repo no redefine el binario `devbox`; lo que sí define es el contenido de `shell.init_hook` en [devbox.json](/webapps/ihh-devtools/devbox.json).
- **No verificado:** no se observó la ejecución real del binario `devbox`; el trigger se sostuvo por lectura estática de la configuración del repo.

## 4. Pregunta principal
**Estado:** `confirmada`

¿Por dónde entra el flujo controlado por el repo cuando alguien hace `devbox shell`, qué decisiones toma antes de considerar la sesión lista, qué toca y qué deja sin verificar?

## 5. Frontera del análisis
**Estado:** `confirmada`

- **Sí entra:** `devbox.json`, el hook generado en `.devbox`, el wizard `bin/setup-wizard.sh`, sus pasos `step-01` a `step-04`, y librerías de soporte mínimas que alteran decisiones del flujo.
- **No entra:** internals del binario Devbox fuera del repo, tareas de `Taskfile`, workflows de CI/promote que solo consumen Devbox, ni comandos posteriores como `devbox run backend`.
- **Límite clave:** este discovery cierra por evidencia estática suficiente y no por ejecución real del shell.

## 6. Entry point
**Estado:** `confirmada`

- **Entry point principal del repo:** `shell.init_hook` en [devbox.json](/webapps/ihh-devtools/devbox.json).
- **Materialización observada:** [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh).
- **Caller inmediato:** el binario externo `devbox shell`.
- **Por qué se considera principal:** es la única superficie del repo que define qué ocurre automáticamente al entrar al shell.
- **Alternativas descartadas:** [README.md](/webapps/ihh-devtools/README.md), [Taskfile.yaml](/webapps/ihh-devtools/Taskfile.yaml) y referencias a `devbox` en `lib/promote/**` o `lib/ci/**` no actúan como punto de entrada de este flujo.

## 7. Dispatcher chain
**Estado:** `confirmada`

- `devbox shell -> devbox.json:shell.init_hook -> .devbox/gen/scripts/.hooks.sh -> bin/setup-wizard.sh -> lib/wizard/step-01-auth.sh -> lib/wizard/step-02-ssh.sh -> lib/wizard/step-03-config.sh -> lib/wizard/step-04-profile.sh`

**Notas:**
- **Observado:** el hook también consulta [lib/core/git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh), [lib/core/contract.sh](/webapps/ihh-devtools/lib/core/contract.sh) y [lib/core/config.sh](/webapps/ihh-devtools/lib/core/config.sh) a través de `setup-wizard.sh`.
- **Parcial:** la porción `devbox shell -> init_hook` no se ejecutó; se sostuvo por configuración estática.

## 8. Camino feliz
**Estado:** `parcial`

1. **Observado:** el operador entra por `devbox shell`.
2. **Observado:** el hook resuelve `root`, fija `DT_ROOT="$root/.devtools"` y calcula `DEVTOOLS_SPEC_VARIANT` según TTY, `DEVTOOLS_SKIP_WIZARD` y la presencia de `.devtools/.setup_completed`.
3. **Observado:** si no entra en variante estricta, intenta `git submodule sync` y `git submodule update --init --recursive .devtools`, ambos best-effort.
4. **Observado:** hace un chequeo informativo de versión de devtools y prepara aliases Git efímeros en memoria, además de `PATH`.
5. **Observado:** busca `setup-wizard.sh` y lo invoca en `--verify-only` si hay marker o no hay TTY; en variante estricta, el rc del wizard decide `DEVBOX_SESSION_READY`; fuera de esa variante, su fallo no bloquea.
6. **Observado:** si `DEVBOX_SESSION_READY=1`, imprime bienvenida, sugiere `devbox run backend`, ofrece menú de rol interactivo y configura el prompt con `starship` o `PS1/PROMPT`.
7. **Observado:** en modo full, el wizard puede autenticar GH, exigir 2FA, generar o seleccionar llaves SSH, cargar `ssh-agent`, subir llaves a GitHub, configurar identidad/firma Git y persistir `.git-acprc`, `.env` y `.setup_completed`.

**Decisiones significativas:**
- marker + TTY + `DEVTOOLS_SKIP_WIZARD` controlan la variante estricta;
- éxito o fallo del wizard decide si la sesión queda “ready” en variante estricta;
- presencia de `starship` cambia cómo se construye el prompt;
- modo full del wizard introduce side effects persistentes, mientras `--verify-only` valida y puede abortar.

**Punto parcial:** el camino feliz completo se reconstruyó por lectura estática; no hubo corrida real para observar mensajes, rc efectivos ni timing.

## 9. Ramas importantes
**Estado:** `confirmada`

- `DEVTOOLS_SPEC_VARIANT=1` solo cuando existen `.devtools/.setup_completed`, TTY en stdin/stdout y `DEVTOOLS_SKIP_WIZARD != 1`.
- `DEVTOOLS_SKIP_WIZARD=1` evita la ejecución del wizard.
- `DEVTOOLS_SKIP_VERSION_CHECK=1` omite el chequeo remoto/informativo de versión.
- ausencia de TTY fuerza `--verify-only` en el wizard.
- si no aparece `setup-wizard.sh`, el hook informa la ausencia y, en variante estricta, deja `DEVBOX_SESSION_READY=0`.
- `starship` presente o ausente cambia la estrategia de prompt.
- [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml) alinea `vendor_dir: .devtools` y `profile_file: .git-acprc`; no introduce una rama contractual distinta al hook.

## 10. Side effects
**Estado:** `confirmada`

- **Entorno efímero:**
  - exporta `PATH`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_*`, `GIT_CONFIG_VALUE_*`, `DEVBOX_SESSION_READY`, `DEVBOX_ENV_NAME`, `STARSHIP_CONFIG`, `PROMPT`/`PS1`.
- **Git / repo:**
  - best-effort `git submodule sync` y `git submodule update --init --recursive .devtools`;
  - `git config --local --unset alias.<tool>` en rutas no estrictas;
  - posible `chmod +x` a scripts encontrados.
- **Red / procesos externos:**
  - `git ls-remote --tags` para aviso de versión;
  - `gh auth status`, `gh auth refresh`, `gh auth login`, `gh auth logout`, `gh api`;
  - `ssh -T`, `ssh-keygen`, `ssh-add`, `gh ssh-key add`.
- **Persistencia local en modo full del wizard:**
  - actualización o creación de `.devtools/.git-acprc`;
  - creación de `.env` si falta;
  - creación o toque de `.devtools/.setup_completed`;
  - configuración Git global o local para identidad y firma;
  - posible cambio de `origin` de HTTPS a SSH.
- **Salida visible:**
  - mensajes de blindaje, versión, validación, bienvenida, menú de rol y avisos de error.

## 11. Inputs
**Estado:** `confirmada`

- **Obligatorios o contextuales:**
  - ejecución de `devbox shell`;
  - estar en un work tree Git válido;
  - archivos [devbox.json](/webapps/ihh-devtools/devbox.json) y, de forma práctica, el hook generado [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh).
- **Contextuales:**
  - presencia de `.devtools/.setup_completed`;
  - [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml);
  - TTY interactivo o no interactivo;
  - disponibilidad de `gh`, `gum`, `ssh`, `ssh-keygen`, `ssh-add`, `git`, `starship`.
- **Variables de entorno relevantes:**
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVBOX_ENV_NAME`
  - `DEVTOOLS_WIZARD_MODE`
- **Archivos y estado previo:**
  - `.devtools/.git-acprc`
  - `.env`
  - llaves bajo `~/.ssh`
  - configuración Git global/local existente.

## 12. Outputs
**Estado:** `confirmada`

- shell con entorno blindado y aliases Git efímeros cargados;
- mensajes en consola sobre versión, wizard, bienvenida y rol;
- `DEVBOX_ENV_NAME` ajustado por menú o default;
- prompt configurado con `starship` o `PS1/PROMPT`;
- posible sesión degradada donde no se habilita la ruta “ready/contextualizada” si el wizard falla en variante estricta;
- en modo full del wizard, archivos/configuraciones persistidas: `.devtools/.git-acprc`, `.env`, `.devtools/.setup_completed`, llaves SSH y Git config global/local;
- **No verificado:** exit code exacto y salida completa de cada rama real del shell.

## 13. Preconditions
**Estado:** `confirmada`

- repo Git accesible;
- árbol del repo con `.devtools` disponible en la ruta contractual del repo;
- Devbox y herramientas mínimas del entorno ya resueltas por el propio ecosistema;
- para modo verify/full del wizard: `gh`, `git`, `ssh`; además `gum`, `ssh-keygen` y `ssh-add` para el camino interactivo full;
- para validaciones externas: red y credenciales operativas si se pretende éxito completo de GH/SSH/version check.

## 14. Error modes
**Estado:** `confirmada`

- si falta `setup-wizard.sh`, el hook lo informa; en variante estricta deja `DEVBOX_SESSION_READY=0`.
- en `--verify-only`, `gh auth status` o `ssh -T` pueden fallar y terminar el wizard con error.
- ausencia de 2FA bloquea el wizard full.
- fallo al cargar `ssh-agent` o una llave puede dejar advertencia o error visible.
- conflicto o identidad Git incompleta en `step-03-config.sh` aborta configuración.
- si el hook intenta `git submodule sync/update` o `git ls-remote` y fallan, el flujo principal no necesariamente aborta porque esos tramos son best-effort.
- ausencia de TTY cambia el comportamiento a verificación, no a wizard interactivo completo.

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Núcleo
- [devbox.json](/webapps/ihh-devtools/devbox.json): define `shell.init_hook`.
- [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh): materializa la secuencia principal del hook.
- [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh): gatekeeper que decide verify-only vs full y carga los pasos del wizard.
- [lib/wizard/step-01-auth.sh](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh): auth GH y verificación 2FA.
- [lib/wizard/step-02-ssh.sh](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh): llaves SSH, `ssh-agent` y subida a GitHub.
- [lib/wizard/step-03-config.sh](/webapps/ihh-devtools/lib/wizard/step-03-config.sh): identidad y firma Git.
- [lib/wizard/step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh): `.git-acprc`, `.env`, marker y posible cambio de remote.

### Soporte
- [lib/core/git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh): `detect_workspace_root`, `ensure_repo_or_die`, helpers Git.
- [lib/core/contract.sh](/webapps/ihh-devtools/lib/core/contract.sh): resolución de `vendor_dir` y `profile_file`.
- [lib/core/config.sh](/webapps/ihh-devtools/lib/core/config.sh): evita bloqueo normal cuando `DEVTOOLS_WIZARD_MODE=true`.
- [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml): contrato del repo que confirma `.devtools` y `.git-acprc`.

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `parcial`

- **Hecho confirmado:** el hook usa `.devtools` hardcodeado, pero en este repo eso coincide con [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml), así que no hay divergencia contractual activa.
- **Indicio fuerte:** `.hooks.sh` es generado; si dejara de reflejar `devbox.json`, aparecería un seam entre fuente declarativa y artefacto generado. En esta corrida se tomó como materialización vigente, no como garantía eterna.
- **Hecho confirmado:** el hook intenta operar `.devtools` como submódulo (`git submodule sync/update`), pero no se observó `.gitmodules`; esa parte debe leerse como compatibilidad best-effort, no como requisito contractual del flujo.
- **Indicio fuerte:** `detect_workspace_root` puede favorecer superproyecto sobre repo actual; eso introduce un seam contextual si el flujo se ejecuta desde un submódulo o workspace anidado.
- **Hecho confirmado:** la variante estricta y la no estricta no tienen la misma severidad ante fallo del wizard.

## 17. Unknowns
**Estado:** `confirmada`

- no se observó una corrida real de `devbox shell`;
- no se verificó el rc exacto ni la salida completa de cada rama del hook;
- no se confirmó si Devbox regeneraría hoy `.hooks.sh` con exactamente el mismo contenido visto;
- no se probó el estado real de red/credenciales para `gh`, `ssh` o `git ls-remote`;
- no se verificó la experiencia exacta del primer arranque interactivo sin marker.

## 18. Evidencia
**Estado:** `confirmada`

- `path:` [devbox.json](/webapps/ihh-devtools/devbox.json)
- `path:` [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh)
- `path:` [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh)
- `path:` [lib/wizard/step-01-auth.sh](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh)
- `path:` [lib/wizard/step-02-ssh.sh](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh)
- `path:` [lib/wizard/step-03-config.sh](/webapps/ihh-devtools/lib/wizard/step-03-config.sh)
- `path:` [lib/wizard/step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh)
- `path:` [lib/core/git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh)
- `path:` [lib/core/contract.sh](/webapps/ihh-devtools/lib/core/contract.sh)
- `path:` [lib/core/config.sh](/webapps/ihh-devtools/lib/core/config.sh)
- `path:` [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml)
- `corrida/validación:` inspección estática del repo; no se ejecutó `devbox shell` por riesgo de side effects
- `salida relevante:` se confirmó la presencia de `.devtools/.setup_completed` en esta copia local

## 19. Validación segura
**Estado:** `confirmada`

- **Qué se validó:** estructura declarativa del hook, wizard y pasos principales; alineación entre el hook y el contrato del repo para `.devtools`; existencia del marker `.devtools/.setup_completed`.
- **Qué quedó confirmado gracias a esta validación:** entrypoint del repo, backbone del flujo, ramas por TTY/marker/flags, side effects potenciales del wizard y criterio de sesión “ready”.
- **Qué siguió sin confirmarse:** ejecución real del binario `devbox`, rc reales, integración efectiva con red/GitHub/SSH y sincronía runtime exacta del hook generado.
- **Riesgos de ejecutar el flujo real:** puede mutar Git config local/global, intentar submodule update, tocar `.env` y `.git-acprc`, iniciar login GH, generar/subir llaves SSH o reconfigurar remotes.
- **Alternativa usada:** lectura estática y contraste de archivos del repo sin observación destructiva.

## 20. Criterio de salida para promover a spec-first
**Estado:** `confirmada`

- **Suficientemente claro:** trigger, entrypoint del repo, backbone `hook -> wizard -> steps`, decisiones principales, side effects esperables y límites del flujo.
- **Sigue abierto:** no hay corrida real y quedan unknowns sobre comportamiento exacto de red/credenciales y del primer arranque interactivo.
- **¿Bloquean la promoción?:** no. Los unknowns pendientes no impiden formular un contrato inicial del flujo porque el comportamiento que el repo intenta garantizar ya quedó suficientemente delimitado.
- **Aclaración mínima adicional si se quisiera más confianza:** una observación controlada de `devbox shell` en entorno aislado, aceptando que tiene side effects.

## 21. Respuesta canónica del discovery
**Estado:** `confirmada`

Cuando alguien ejecuta `devbox shell`, el repo entra por `shell.init_hook` en [devbox.json](/webapps/ihh-devtools/devbox.json), materializado en [.devbox/gen/scripts/.hooks.sh](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh). Allí decide root, variante estricta según TTY/marker/flags, hace blindaje efímero del entorno y ejecuta `bin/setup-wizard.sh`; el wizard valida o configura auth/SSH/Git/perfil y puede persistir `.git-acprc`, `.env` y `.setup_completed`. El flujo termina en una shell “ready” con prompt y rol contextualizados si `DEVBOX_SESSION_READY=1`, o en una sesión degradada si la compuerta estricta falla.

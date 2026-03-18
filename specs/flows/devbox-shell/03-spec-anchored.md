# Flow id

`devbox-shell`

# Intención contractual de referencia

`02-spec-first.md` sigue siendo la autoridad funcional de este flujo. El contrato que se ancla aquí no se redefine por el código actual.

- Confirmado desde spec-first: el núcleo contractual de `devbox shell` es dejar una sesión utilizable para operar este repo con preparación efímera del entorno y con señal visible de si la sesión quedó `ready` o degradada.
- Confirmado desde spec-first: la configuración guiada con side effects persistentes puede existir, pero no constituye el éxito base universal del flujo.
- Confirmado desde spec-first: prompt exacto, menú exacto, texto exacto, chequeo remoto de versión y `submodule sync/update` best-effort de `.devtools` no forman parte de la garantía contractual central.
- Límite de esta fase: localizar soporte real, soporte parcial, seams, compatibilidades, divergencias y superficies reales de cambio sin diseñar implementación futura.

# Entry point real anclado

- Anclaje claro: el trigger contractual visible para el operador es `devbox shell`.
- Anclaje claro: la superficie real controlada por el repo empieza en `shell.init_hook` dentro de `devbox.json`.
- Anclaje claro: la materialización vigente del hook está en `.devbox/gen/scripts/.hooks.sh`.
- Seam / compatibilidad: el binario `devbox` es una capa externa al repo; el repo controla el hook, no el ejecutable.
- Evidencia concreta: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`.

# Dispatcher chain real anclada

- Anclaje claro: `devbox shell -> devbox.json:shell.init_hook -> .devbox/gen/scripts/.hooks.sh`.
- Anclaje claro: desde el hook la cadena principal continúa hacia `bin/setup-wizard.sh` cuando se localiza `setup-wizard.sh` entre las rutas candidatas.
- Anclaje claro: `bin/setup-wizard.sh` carga `lib/core/utils.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/config.sh`, `lib/ui/styles.sh` y luego los pasos `lib/wizard/step-01-auth.sh`, `step-02-ssh.sh`, `step-03-config.sh`, `step-04-profile.sh`.
- Anclaje parcial: la porción `devbox shell -> init_hook` está anclada por config y artefacto generado, no por ejecución observada.
- Seam / compatibilidad: `.hooks.sh` es artefacto generado y `devbox.json` es la fuente declarativa; hoy coinciden, pero no deben colapsarse como una sola autoridad.
- Evidencia concreta: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh`.

# Mapa de camino feliz

- Anclaje claro: el hook resuelve `top`, `sp`, `root_guess`, `root`, `DT_ROOT` y `DT_BIN` al inicio del flujo.
- Anclaje claro: el hook fija `DEVTOOLS_SPEC_VARIANT` según marker `.setup_completed`, TTY y `DEVTOOLS_SKIP_WIZARD`.
- Anclaje claro: el hook prepara el entorno efímero cargando `PATH`, aliases Git en memoria mediante `GIT_CONFIG_KEY_*` y `GIT_CONFIG_VALUE_*`, y el estado inicial de `DEVBOX_SESSION_READY`.
- Anclaje claro: si encuentra `setup-wizard.sh` y no se saltó el wizard, ejecuta el wizard en modo full o `--verify-only` según marker y TTY.
- Anclaje parcial: el camino feliz contractual de “sesión utilizable del repo con señal visible de readiness” está sostenido con claridad en la rama estricta, pero no universalmente en la rama no estricta.
- Probable: en primer arranque interactivo sin marker, el wizard full recorre auth, SSH, identidad Git y perfil, y luego retorna al hook para completar bienvenida, menú de rol y prompt.
- Divergencia real: la rama no estricta puede seguir por la ruta de bienvenida aunque el wizard falle, de modo que el camino feliz visible actual desborda el contrato de señalización `ready/degradada`.

# Preconditions ancladas

- Anclaje parcial: “estar en un repo Git utilizable” se valida de forma estricta en `ensure_repo_or_die` dentro de `bin/setup-wizard.sh`, pero no como guard fuerte antes de todo el trabajo best-effort del hook.
- Anclaje claro: la disponibilidad contractual de `.devtools` y `.git-acprc` se resuelve por `devtools.repo.yaml` mediante `devtools_load_contract`, `DEVTOOLS_VENDOR_DIR` y `DEVTOOLS_PROFILE_CONFIG`.
- Anclaje claro: la presencia o ausencia de TTY se valida explícitamente en el hook y en `setup-wizard.sh` para decidir `--verify-only`.
- Anclaje claro: las herramientas requeridas se validan en `setup-wizard.sh` con dos conjuntos distintos, uno para `VERIFY_ONLY=true` y otro para full path.
- Anclaje parcial: conectividad, credenciales GH y SSH son preconditions reales para ciertas ramas del wizard, no para el núcleo mínimo de entrada al shell.
- Tolerancia accidental: el hook tolera ausencia de `.gitmodules`, fallos de `submodule sync/update` y fallos de version check como best-effort.

# Inputs anclados

- Anclaje claro: input de comando `devbox shell` como trigger externo del flujo.
- Anclaje claro: variables de entorno `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK` y `DEVBOX_ENV_NAME` alteran ramas visibles del flujo.
- Anclaje claro: el marker `.devtools/.setup_completed` entra como input decisivo tanto en el hook como en el wizard.
- Anclaje claro: `devtools.repo.yaml` entra como input contractual para `vendor_dir` y `profile_file` en `contract.sh`.
- Anclaje claro: TTY interactivo entra como input de bifurcación en el hook y en `setup-wizard.sh`.
- Anclaje claro: flags `--verify-only`, `--verify` y `--force` entran en `bin/setup-wizard.sh`.
- Anclaje parcial: `.git-acprc` y `.env` son inputs contextuales cuando ya existen, pero su rol exacto en primer arranque no quedó observado en runtime.
- Seam / compatibilidad: el hook principal sigue parseando `.devtools` por hardcode, mientras el wizard y librerías resuelven el vendor dir desde `devtools.repo.yaml`.

# Outputs anclados

- Anclaje claro: el hook produce una sesión con `PATH` ajustado, aliases Git efímeros y variables exportadas en memoria.
- Anclaje parcial: la salida visible de `ready` o degradada está claramente localizada, pero solo es contractualmente fiable en la rama estricta.
- Anclaje claro: cuando `DEVBOX_SESSION_READY=1`, el hook emite mensajes de bienvenida, sugerencia de `devbox run backend`, menú de rol interactivo y prompt con `starship` o `PROMPT`/`PS1`.
- Anclaje claro: el wizard full puede producir `.git-acprc`, `.env`, `.setup_completed`, ajustes Git global/local y cambio eventual de `origin` a SSH.
- Output incidental: textos exactos de logs, menú y prompt no forman parte del anclaje contractual central.

# Side effects anclados

- Anclaje claro: side effects efímeros de entorno en el hook: `PATH`, aliases Git en memoria, `DEVBOX_SESSION_READY`, `DEVBOX_ENV_NAME`, `STARSHIP_CONFIG`, `PROMPT`/`PS1`.
- Seam / compatibilidad: side effects best-effort sobre Git local en el hook, como `git config --local --unset alias.*`, `chmod +x` de scripts localizados y `submodule sync/update`.
- Anclaje claro: side effects de red en version check y wizard: `git ls-remote --tags`, `gh auth status`, `gh auth login`, `gh auth refresh`, `gh ssh-key add`, `ssh -T`.
- Anclaje claro: side effects persistentes del wizard full sobre Git global/local, `.git-acprc`, `.env`, marker `.setup_completed`, llaves SSH y remote `origin`.
- Divergencia real: `lib/core/config.sh` aplica `git config --global init.defaultBranch main` al cargarse, antes de que `setup-wizard.sh` termine de reducir el flujo a `--verify-only`; esto introduce mutación persistente temprana en una rama que contractualmente debería distinguir verificación de mutación.

# Invariants anclados

- Anclaje parcial: el invariant “preparación efímera del entorno” sí está sostenido por el hook y es central en la ruta de entrada.
- Divergencia real: el invariant “distinguir preparación efímera de mutaciones persistentes” queda roto por la carga temprana de `config.sh`, que puede mutar Git global antes de resolver plenamente el modo de verificación.
- Divergencia real: el invariant “comunicar el estado final de readiness en vez de asumirlo” no se sostiene de forma universal porque la rama no estricta puede conservar `DEVBOX_SESSION_READY=1` pese a fallo del wizard.
- Divergencia real: el invariant repo-céntrico queda tensionado por `detect_workspace_root` y `cd "$REAL_ROOT"`, que pueden desplazar la responsabilidad efectiva al superproyecto.
- Anclaje claro: el contrato de que los comportamientos best-effort no redefinen el éxito base está reflejado en el código para version check y submodule sync/update, ambos bajo `|| true`.

# Failure modes anclados

- Anclaje claro: en la rama estricta, si el wizard falla o no se encuentra, el hook deja `DEVBOX_SESSION_READY=0` y emite mensaje visible de que se omite la ruta lista/contextualizada.
- Anclaje claro: en `VERIFY_ONLY=true`, el wizard falla explícitamente si faltan herramientas, si `gh auth status` falla o si la comprobación SSH no valida autenticación.
- Anclaje claro: ausencia de TTY fuerza degradación funcional hacia `--verify-only`.
- Failure mode interno anclado: conflictos de identidad Git duplicada o incompleta abortan `step-03-config.sh`.
- Divergencia real: en la rama no estricta, el failure mode del wizard puede quedar absorbido por `bash "$WIZARD_SCRIPT" $WIZARD_ARGS || true`, dejando salida visible de éxito donde el contrato pide señalización honesta de degradación.
- Anclaje parcial: no se observaron en runtime los exit codes exactos del binario `devbox shell` ni de cada rama final del hook.

# Ramas importantes y seams de compatibilidad

- Rama central: `DEVTOOLS_SPEC_VARIANT=1` cuando existe `.devtools/.setup_completed`, hay TTY y `DEVTOOLS_SKIP_WIZARD != 1`.
- Rama central: ejecución del wizard en modo full o `--verify-only` según marker y TTY.
- Rama secundaria: `DEVTOOLS_SKIP_WIZARD=1` evita la ejecución del wizard.
- Rama secundaria: `DEVTOOLS_SKIP_VERSION_CHECK=1` omite el aviso remoto de versión.
- Seam / compatibilidad: hardcode de `.devtools` en el hook frente a resolución contractual por `devtools.repo.yaml` en wizard y librerías.
- Seam / compatibilidad: `.hooks.sh` frente a `devbox.json` como artefacto generado versus fuente declarativa.
- Seam / compatibilidad: `submodule sync/update` best-effort sin `.gitmodules` presente en este repo.
- Seam / compatibilidad: mezcla de resolución de scripts entre `repo/bin`, `vendor/bin` y búsqueda dinámica con `find`.
- Dispersión: la semántica de root se reparte entre `devbox.json`, `.hooks.sh`, `detect_workspace_root`, `config.sh` y `contract.sh`.

# Divergencias entre spec y código

- Divergencia real: cláusula afectada, “el flujo debe comunicar si la sesión quedó `ready` o degradada y no debe ocultar degradación”. El código actual no sostiene esto de forma universal porque en la rama no estricta inicia `DEVBOX_SESSION_READY=1`, ejecuta el wizard con `|| true` y mantiene la ruta de bienvenida aunque la verificación o configuración falle.
- Divergencia real: cláusula afectada, “el flujo debe distinguir preparación efímera del entorno de mutaciones persistentes del setup del operador”. El código actual carga `lib/core/config.sh` antes de decidir completamente la reducción a verificación, y esa carga puede ejecutar `git config --global init.defaultBranch main`.
- Divergencia real: cláusula afectada, “el contrato del flujo debe seguir siendo repo-céntrico”. El código actual prioriza `show-superproject-working-tree` en `detect_workspace_root`, hace `cd "$REAL_ROOT"` en `setup-wizard.sh` y luego aplica lecturas y escrituras respecto de ese root.
- Exceso de comportamiento actual: el wizard full tiene side effects más fuertes que el núcleo contractual visible, especialmente sobre Git global/local, SSH, `.env`, `.git-acprc` y remotes.
- Anclaje insuficiente, no divergencia: la UX exacta del primer arranque interactivo no fue observada en runtime y permanece como unknown, no como contradicción cerrada.

# Superficies reales de cambio

- Superficie principal: `devbox.json` y `.devbox/gen/scripts/.hooks.sh`, porque ahí vive la semántica de entrada, la señalización `ready/degradada`, la bifurcación estricta/no estricta y el uso hardcodeado de `.devtools`.
- Superficie principal: `bin/setup-wizard.sh`, porque ahí viven la reducción a `--verify-only`, la carga del contrato, la resolución de root y el acoplamiento entre validación y setup guiado.
- Superficie principal: `lib/core/config.sh`, porque ahí vive la mutación persistente temprana que hoy rompe la frontera contractual entre verificación y side effects.
- Superficie secundaria: `lib/core/git-ops.sh`, porque `detect_workspace_root` concentra la tensión repo-céntrica versus superproyecto.
- Superficie secundaria: `lib/core/contract.sh`, porque concentra la resolución contractual de `vendor_dir` y `profile_file` que hoy no coincide plenamente con el hook.
- Zona de alto riesgo: `lib/wizard/step-03-config.sh` y `lib/wizard/step-04-profile.sh`, por concentrar mutaciones persistentes sobre Git, `.git-acprc`, `.env`, marker y remote.
- Zona de dispersión: la semántica de root, vendor dir y profile file está repartida entre hook, wizard y librerías.

# Unknowns

- Unknown que no bloquea: no se ejecutó `devbox shell` de forma observada; faltan exit codes y mensajes exactos de runtime.
- Unknown que no bloquea: no se verificó si Devbox regeneraría hoy `.hooks.sh` exactamente igual al artefacto actual.
- Unknown que tensiona: la experiencia exacta del primer arranque interactivo con credenciales reales GH/SSH no quedó observada.
- Unknown que tensiona: no se observó en un workspace anidado real el efecto práctico de `detect_workspace_root`, aunque la tensión estructural sí está localizada en código.
- Unknown que no bloquea: el prompt exacto y la UX exacta del menú de rol.

# Evidencia

- Paths:
  - `devbox.json`
  - `.devbox/gen/scripts/.hooks.sh`
  - `bin/setup-wizard.sh`
  - `lib/core/git-ops.sh`
  - `lib/core/contract.sh`
  - `lib/core/config.sh`
  - `lib/core/dispatch.sh`
  - `lib/wizard/step-01-auth.sh`
  - `lib/wizard/step-02-ssh.sh`
  - `lib/wizard/step-03-config.sh`
  - `lib/wizard/step-04-profile.sh`
  - `devtools.repo.yaml`
- Funciones:
  - `detect_workspace_root`
  - `ensure_repo_or_die`
  - `devtools_load_contract`
  - `devtools_profile_config_file`
  - `devtools_apply_persistent_config_side_effects`
  - `run_step_auth`
  - `run_step_ssh`
  - `run_step_git_config`
  - `run_step_profile_registration`
  - `devtools_dispatch_if_needed`
- Handlers:
  - `shell.init_hook`
  - rama `DEVTOOLS_SPEC_VARIANT == 1`
  - rama `VERIFY_ONLY == true`
  - rama `WIZARD_SCRIPT` encontrado / no encontrado
- Scripts:
  - `bin/setup-wizard.sh`
  - `lib/wizard/step-01-auth.sh`
  - `lib/wizard/step-02-ssh.sh`
  - `lib/wizard/step-03-config.sh`
  - `lib/wizard/step-04-profile.sh`
- Comandos observados en código:
  - `git submodule sync`
  - `git submodule update --init --recursive`
  - `git ls-remote --tags`
  - `gh auth status`
  - `gh auth login`
  - `gh auth refresh`
  - `gh ssh-key add`
  - `ssh -T`
  - `git config --global`
  - `git config --local`
- Branches:
  - estricto vs no estricto
  - interactivo vs no TTY
  - full wizard vs `--verify-only`
  - wizard encontrado vs ausente
  - `ready` vs ruta degradada visible solo en la rama estricta
- Flags:
  - `--verify-only`
  - `--verify`
  - `--force`
- Variables de entorno:
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVBOX_SESSION_READY`
  - `DEVTOOLS_SPEC_VARIANT`
  - `DEVTOOLS_WIZARD_MODE`
  - `DEVTOOLS_DEFER_PERSISTENT_CONFIG`
  - `DEVBOX_ENV_NAME`
- Config:
  - `paths.vendor_dir=.devtools` en `devtools.repo.yaml`
  - `config.profile_file=.git-acprc` en `devtools.repo.yaml`
- Observaciones controladas no destructivas:
  - `.gitmodules` ausente en el repo
  - `.devtools/.setup_completed` presente
  - `.env` presente
  - `git -C .devtools rev-parse --show-toplevel` resolvió al repo principal, no a un subrepo independiente

# Criterio de salida para promover a spec-as-source

- Anclaje suficiente: entrypoint real, dispatcher chain principal, preparación efímera del entorno, rutas principales del wizard, preconditions e inputs relevantes, outputs visibles principales y side effects persistentes del wizard quedaron localizados con evidencia concreta.
- Anclaje parcial: primer arranque interactivo observado, severidad runtime exacta de algunos failure modes y comportamiento práctico en workspace anidado.
- Divergencias que la siguiente fase tendrá que enfrentar explícitamente:
  - señalización `ready/degradada` no universal en la rama no estricta;
  - mutación persistente temprana por `config.sh` antes de que el wizard quede reducido a verificación;
  - tensión repo-céntrica vs superproyecto por `detect_workspace_root` y `cd "$REAL_ROOT"`.
- Seams que deben seguir visibles y no rebajar el contrato:
  - hardcode de `.devtools` en el hook versus resolución contractual por `devtools.repo.yaml`;
  - `.hooks.sh` como artefacto generado frente a `devbox.json` como fuente declarativa;
  - `submodule sync/update` best-effort sin `.gitmodules`.
- Superficies que concentran el trabajo futuro: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh`, `lib/core/config.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`.
- Unknowns que no bloquean promoción futura por sí solos: prompt exacto, UX exacta del menú, exit codes exactos y regeneración exacta de `.hooks.sh`.
- Unknowns o conflictos que sí bloquean promoción inmediata: las tres divergencias reales anteriores, porque afectan el núcleo contractual de readiness, separación entre verificación y side effects, y frontera repo-céntrica del flujo.

Estado explícito: `bloqueado por conflicto fuerte con el código actual`.

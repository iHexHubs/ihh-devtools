# Flow id

`devbox-shell`

# Intencion contractual de referencia

- `Confirmado desde spec-first`: `devbox shell` debe resolver el workspace correcto antes de contextualizar la sesion.
- `Confirmado desde spec-first`: el flujo debe exponer herramientas y contexto efimero del repo y dejar visible si la sesion quedo lista/contextualizada o si esa ruta fue omitida.
- `Confirmado desde spec-first`: las ayudas interactivas como menu de rol o prompt enriquecido son conveniencias, no el nucleo del contrato.
- `Confirmado desde spec-first`: `02-spec-first.md` sigue siendo la autoridad funcional. El codigo actual solo sirve para anclar, tensionar y clasificar.
- `Limite de fase`: este artefacto no implementa correcciones, no redefine el contrato y no promueve por inercia a `spec-as-source`.

# Entry point real anclado

- `Confirmado desde spec-first`: el trigger contractual externo sigue siendo `devbox shell`.
- `Anclaje claro`: el entrypoint real dentro del repo vive en `devbox.json`, bloque `shell.init_hook` (`devbox.json:45-149`).
- `Anclaje claro`: ese hook concentra la resolucion inicial de root, la seleccion de variante, la exposicion de herramientas efimeras, el handoff al wizard y la decision de outputs visibles.
- `Anclaje claro`: `bin/setup-wizard.sh` es el handoff principal, no el entrypoint inicial del flujo (`devbox.json:102-126`).
- `Sospecha`: el bridge exacto entre el binario `devbox` y `shell.init_hook` queda fuera de este repo y sigue como unknown estructural.

# Dispatcher chain real anclada

- `Anclaje claro`: `devbox shell` externo -> `devbox.json:shell.init_hook` -> busqueda de `setup-wizard.sh` en candidatos -> `bin/setup-wizard.sh`.
- `Anclaje claro`: `bin/setup-wizard.sh` sourcea `lib/core/utils.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/config.sh`, `lib/ui/styles.sh` y luego los steps del wizard (`bin/setup-wizard.sh:19-22`, `bin/setup-wizard.sh:47-67`).
- `Anclaje claro`: en `verify-only`, el dispatcher real permanece dentro de `bin/setup-wizard.sh` y ejecuta checks de `gh auth status` y `ssh -T` antes de salir (`bin/setup-wizard.sh:122-182`).
- `Anclaje claro`: en full path, la cadena principal es `run_step_auth` -> `run_step_ssh` -> `run_step_git_config` -> `run_step_profile_registration` (`bin/setup-wizard.sh:190-200`).
- `Seam / compatibilidad`: la decision de readiness no vive solo en el wizard; queda repartida entre `DEVBOX_SESSION_READY` en `devbox.json` y el codigo de retorno de `bin/setup-wizard.sh`.
- `Descartado`: consumers secundarios como `devbox shell --print-env` en otros workflows no son centrales para este flujo.

# Mapa de camino feliz

- `Confirmado desde spec-first`: el camino feliz debe llegar a una shell contextualizada con readiness visible.
- `Anclaje claro`: el hook resuelve `top`, `sp`, `root_guess` y `root` antes de cualquier contextualizacion (`devbox.json:48-51`).
- `Anclaje claro`: el hook prepara `DT_ROOT`, `DT_BIN`, `PATH` y aliases efimeros por `GIT_CONFIG_COUNT` antes del handoff al wizard (`devbox.json:71-100`).
- `Anclaje claro`: el hook localiza `setup-wizard.sh`, calcula `WIZARD_ARGS` desde marker y TTY, y lo ejecuta (`devbox.json:102-126`).
- `Anclaje claro`: en variante estricta, el camino feliz requiere exito del wizard para levantar `DEVBOX_SESSION_READY=1` (`devbox.json:117-123`).
- `Anclaje parcial`: el camino feliz contractual de readiness visible queda solo parcialmente sostenido a nivel de flujo completo, porque la rama no estricta conserva `DEVBOX_SESSION_READY=1` aunque falle el wizard (`devbox.json:108-126`).
- `Anclaje claro`: si `DEVBOX_SESSION_READY=1`, el hook imprime bienvenida, sugerencia de backend, menu de rol en TTY y prompt (`devbox.json:138-147`).
- `Probable`: por el marker existente en `.devtools/.setup_completed`, la ruta hoy mas probable del repo parece ser `variant=1 + --verify-only`, pero esa conclusion no viene de una corrida viva.

# Preconditions ancladas

- `Confirmado desde spec-first`: el operador debe estar dentro de un repo Git valido.
  `Anclaje claro`: `ensure_repo_or_die` aborta si no hay repo (`lib/core/git-ops.sh:47-53`, `bin/setup-wizard.sh:116-117`).
- `Confirmado desde spec-first`: la ruta lista/contextualizada requiere prerequisitos minimos de verificacion o preparacion.
  `Anclaje claro`: `bin/setup-wizard.sh` exige herramientas distintas segun `VERIFY_ONLY` (`bin/setup-wizard.sh:97-111`).
- `Confirmado desde spec-first`: TTY e interaccion pueden degradar la experiencia.
  `Anclaje claro`: la falta de TTY fuerza `--verify-only` (`bin/setup-wizard.sh:84-90`) y tambien altera la seleccion de variante (`devbox.json:52-55`).
- `Anclaje parcial`: la existencia del gatekeeper no se trata como precondition fuerte en toda la superficie del flujo.
  `Evidencia`: si falta `setup-wizard.sh`, solo la variante estricta desactiva readiness; fuera de ella la shell puede seguir la ruta lista/contextualizada (`devbox.json:127-137`).
- `Seam / compatibilidad`: el path contractual del perfil se resuelve en raiz, pero el estado observado vigente esta en `.devtools/.git-acprc`; esa tension no invalida esta fase, pero si afecta el anclaje del entorno ya preparado.

# Inputs anclados

- `Confirmado desde spec-first`: comando de entrada `devbox shell`.
  `Anclaje claro`: el repo solo recibe ese comando por `shell.init_hook` en `devbox.json`.
- `Confirmado desde spec-first`: estado del repo y del workspace actual.
  `Anclaje claro`: root, superproject y workspace se resuelven en `devbox.json:48-51` y `lib/core/git-ops.sh:121-128`.
- `Confirmado desde spec-first`: TTY, marker y estado previo de preparacion.
  `Anclaje claro`: `DEVTOOLS_SPEC_VARIANT` depende de `.devtools/.setup_completed`, TTY y `DEVTOOLS_SKIP_WIZARD` (`devbox.json:52-55`).
- `Anclaje claro`: flags y env de control como `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `VERIFY_ONLY`, `FORCE`, `DEVBOX_SESSION_READY` y `WIZARD_ARGS` alteran el flujo (`devbox.json:52-69`, `devbox.json:108-126`, `bin/setup-wizard.sh:73-95`).
- `Anclaje claro`: contrato del repo desde `devtools.repo.yaml` y `lib/core/contract.sh`, incluyendo `vendor_dir` y `profile_file` (`devtools.repo.yaml:1-11`, `lib/core/contract.sh:173-305`).
- `Anclaje claro`: el full path incorpora inputs interactivos adicionales para login, 2FA, llave SSH, identidad Git, perfil y cambio de remote (`lib/wizard/step-01-auth.sh:18-75`, `lib/wizard/step-02-ssh.sh:28-112`, `lib/wizard/step-03-config.sh:44-191`, `lib/wizard/step-04-profile.sh:71-146`).
- `Fuera de alcance`: internals del binario `devbox` fuera del repo.

# Outputs anclados

- `Confirmado desde spec-first`: la salida contractual principal es una shell con contexto del repo.
  `Anclaje claro`: el hook exporta `PATH`, `GIT_CONFIG_COUNT` y variables de runtime antes de continuar (`devbox.json:77-100`).
- `Confirmado desde spec-first`: debe haber señal visible de readiness o de omision de la ruta lista/contextualizada.
  `Anclaje claro`: en variante estricta, si falla el wizard, se emite `se omite la ruta lista/contextualizada` (`devbox.json:117-123`, `devbox.json:133-135`).
  `Anclaje parcial`: fuera de la variante estricta no hay una senal equivalente y la shell puede seguir comportandose como lista.
- `Anclaje claro`: cuando `DEVBOX_SESSION_READY=1`, el flujo expone bienvenida, sugerencia de `devbox run backend`, menu de rol y prompt (`devbox.json:138-147`).
- `Output incidental`: el texto exacto de banners, el nombre exacto del prompt y el menu de rol no forman parte del contrato esencial.

# Side effects anclados

- `Anclaje claro`: side effects efimeros de sesion en `PATH`, `GIT_CONFIG_COUNT`, aliases en memoria y `DEVBOX_ENV_NAME` (`devbox.json:77-100`, `devbox.json:145-147`).
- `Anclaje claro`: side effects de repo en rama no estricta: `git submodule sync`, `git submodule update`, `git config --local --unset alias.*` y `chmod +x` sobre scripts encontrados (`devbox.json:54-55`, `devbox.json:83`, `devbox.json:91`).
- `Anclaje claro`: side effects de red y sistema del wizard full path: login web de GitHub, refresh/logout/login de `gh`, generacion/seleccion de llaves SSH, carga en `ssh-agent`, subida de llaves a GitHub (`lib/wizard/step-01-auth.sh:18-75`, `lib/wizard/step-02-ssh.sh:43-190`).
- `Anclaje claro`: side effects de configuracion Git global/local y firma SSH (`lib/wizard/step-03-config.sh:107-179`).
- `Anclaje claro`: side effects persistentes de perfil, `.env`, marker y `origin` (`lib/wizard/step-04-profile.sh:41-185`).
- `Seam / compatibilidad`: muchos side effects fuertes sostienen la preparacion del entorno, pero `spec-first` no los eleva automaticamente a outputs contractuales maduros.

# Invariants anclados

- `Confirmado desde spec-first`: el flujo debe resolver el workspace antes de contextualizar.
  `Anclaje claro`: sostenido por `devbox.json:48-51` y `lib/core/git-ops.sh:121-128`, con segunda resolucion en `bin/setup-wizard.sh:24-29`.
- `Confirmado desde spec-first`: la diferencia entre shell abierta y sesion lista/contextualizada debe permanecer visible.
  `Anclaje parcial`: sostenido con claridad solo en variante estricta; la rama no estricta degrada ese invariant.
- `Confirmado desde spec-first`: la sesion no deberia tratarse como lista/contextualizada si falla la verificacion requerida.
  `Divergencia real`: la rama no estricta conserva `DEVBOX_SESSION_READY=1` aunque falle el wizard (`devbox.json:108-126`).
- `Confirmado desde spec-first`: las ayudas visuales o interactivas no deben redefinir el resultado contractual principal.
  `Anclaje claro`: menu y prompt solo ocurren despues de readiness y no determinan por si solos el resultado (`devbox.json:138-147`).
- `Confirmado desde spec-first`: la contextualizacion del repo deberia ser efimera respecto de la sesion.
  `Anclaje parcial`: existe soporte efimero claro, pero coexiste con mutaciones persistentes del repo y del entorno del usuario.

# Failure modes anclados

- `Confirmado desde spec-first`: repo invalido debe fallar de forma comprensible.
  `Anclaje claro`: `ensure_repo_or_die` aborta con mensaje explicito (`lib/core/git-ops.sh:47-53`).
- `Confirmado desde spec-first`: si faltan herramientas minimas, el flujo debe fallar o degradarse de forma visible.
  `Anclaje claro`: `bin/setup-wizard.sh` aborta cuando faltan dependencias requeridas (`bin/setup-wizard.sh:97-111`).
- `Confirmado desde spec-first`: si la verificacion requerida falla, no debe declararse readiness.
  `Anclaje claro`: verify-only falla por `gh auth status` o `ssh -T` y sale con error (`bin/setup-wizard.sh:130-173`).
  `Anclaje claro`: en variante estricta, fallo del wizard deja `DEVBOX_SESSION_READY=0` y emite mensaje visible (`devbox.json:117-123`).
  `Divergencia real`: fuera de la variante estricta, fallo del wizard o ausencia del gatekeeper no fuerzan `not ready` (`devbox.json:124-137`).
- `Seam / compatibilidad`: el full path puede caer en fallback manual para subida de llaves, 2FA no verificable o decision del operador; esos casos afectan la preparacion, pero no redefinen por si solos el contrato principal (`lib/wizard/step-01-auth.sh:81-121`, `lib/wizard/step-02-ssh.sh:167-190`).

# Ramas importantes y seams de compatibilidad

- `Anclaje claro`: `DEVTOOLS_SPEC_VARIANT` divide la rama estricta y la no estricta segun marker, TTY y `DEVTOOLS_SKIP_WIZARD` (`devbox.json:52-55`).
- `Anclaje claro`: `DEVTOOLS_SKIP_WIZARD` permite saltar el gatekeeper (`devbox.json:53`, `devbox.json:110`).
- `Anclaje claro`: `WIZARD_ARGS` se fuerza a `--verify-only` por marker o falta de TTY (`devbox.json:111-115`, `bin/setup-wizard.sh:84-95`).
- `Seam / compatibilidad`: `DEVBOX_SESSION_READY` concentra la frontera entre shell abierta y sesion lista, pero su semantica cambia segun la variante (`devbox.json:108-147`).
- `Seam / compatibilidad`: `profile_file` contractual en raiz (`devtools.repo.yaml:11`, `lib/core/contract.sh:253-262`) convive con estado legado observado en `.devtools/.git-acprc`.
- `Seam / compatibilidad`: en verify-only, el host SSH se intenta inferir desde el perfil resuelto; si ese path contractual no existe, el flujo cae de hecho a `github.com` (`bin/setup-wizard.sh:140-151`).
- `Legado relevante`: `.devtools/.setup_completed` y `.devtools/.git-acprc` siguen modulando la ruta probable del repo aunque el contrato actual apunte a `profile_file` en raiz.

# Divergencias entre spec y codigo

- `Divergencia real`: clausula afectada:
  - `spec-first` exige que la sesion no se trate como lista/contextualizada si falla la verificacion requerida.
  evidencia concreta:
  - `devbox.json:108-126` inicia `DEVBOX_SESSION_READY=1` fuera de la variante estricta y ejecuta `bash "$WIZARD_SCRIPT" $WIZARD_ARGS || true`.
  - `devbox.json:138-147` sigue mostrando outputs de readiness cuando `DEVBOX_SESSION_READY` permanece en `1`.
  naturaleza:
  - el codigo tolera fallo del wizard sin retirar readiness en la rama no estricta.
  clasificacion:
  - `divergencia real`.
- `Divergencia real`: clausula afectada:
  - `spec-first` exige que la falta del gatekeeper o de la verificacion requerida se interprete como fallo de preparacion contextualizada.
  evidencia concreta:
  - `devbox.json:127-137` solo fuerza `DEVBOX_SESSION_READY=0` si la variante es estricta; fuera de ella puede advertir y conservar readiness.
  naturaleza:
  - el flujo no sostiene de forma uniforme la senal contractual de no-readiness.
  clasificacion:
  - `divergencia real`.
- `Anclaje parcial`: la invariancia de contextualizacion efimera tiene soporte mixto.
  evidencia concreta:
  - soporte efimero: `devbox.json:77-100`;
  - mutaciones persistentes: `devbox.json:83`, `devbox.json:91`, `lib/wizard/step-03-config.sh:107-179`, `lib/wizard/step-04-profile.sh:41-185`.
  naturaleza:
  - tension importante, pero `spec-first` ya habia dejado fuera del contrato maduro varios side effects del wizard.
  clasificacion:
  - `anclaje parcial`, no reapertura de spec-first.

# Superficies reales de cambio

- `Superficie principal`: `devbox.json:45-149`.
  Justificacion: concentra entrypoint, seleccion de variante, gate de readiness, outputs visibles y la divergencia central entre rama estricta y no estricta.
- `Superficie secundaria`: `bin/setup-wizard.sh:24-45` y `bin/setup-wizard.sh:73-200`.
  Justificacion: concentra root real, resolucion de contrato, seleccion de `verify-only` y handoffs del wizard.
- `Superficie secundaria`: `lib/core/contract.sh:253-305` junto con `devtools.repo.yaml:8-11`.
  Justificacion: concentra el seam de `profile_file` y la resolucion contractual del entorno persistido.
- `Superficie secundaria`: `lib/wizard/step-04-profile.sh:41-185`.
  Justificacion: concentra persistencia de perfil, `.env`, marker y cambio de remote.
- `Zona de alto riesgo`: la frontera entre "shell abierta" y "sesion lista/contextualizada", repartida entre `DEVBOX_SESSION_READY` en `devbox.json` y los codigos de retorno del wizard.
- `Zona de dispersion`: los side effects materiales del full path, repartidos entre `step-01-auth`, `step-02-ssh`, `step-03-config` y `step-04-profile`.

# Unknowns

- `Unknown que no bloquea`: bridge exacto entre el binario `devbox` y `shell.init_hook`.
- `Unknown que no bloquea`: wording exacto y comportamiento final del prompt/menu en una corrida viva.
- `Unknown que tensiona`: exito real de `gh auth status`, `ssh -T`, login web, subida de llaves y cambio de remote en este entorno concreto; no se hizo observacion runtime.
- `Unknown que tensiona`: estado real de consumo del perfil legado en `.devtools/.git-acprc` frente al path contractual en raiz.
- `Unknown que no debe cerrarse por intuicion`: exit status final real de `devbox shell` cuando la rama no estricta tolera fallos del wizard.

# Evidencia

- `paths`:
  - `devbox.json`
  - `bin/setup-wizard.sh`
  - `lib/core/contract.sh`
  - `lib/core/git-ops.sh`
  - `lib/wizard/step-01-auth.sh`
  - `lib/wizard/step-02-ssh.sh`
  - `lib/wizard/step-03-config.sh`
  - `lib/wizard/step-04-profile.sh`
  - `devtools.repo.yaml`
  - `.devtools/.git-acprc`
  - `.devtools/.setup_completed`
- `funciones`:
  - `detect_workspace_root`
  - `ensure_repo_or_die`
  - `devtools_load_contract`
  - `devtools_profile_config_file`
  - `run_step_auth`
  - `run_step_ssh`
  - `run_step_git_config`
  - `run_step_profile_registration`
- `scripts / bloques`:
  - `shell.init_hook`
  - `setup-wizard.sh`
- `flags / env`:
  - `DEVTOOLS_SPEC_VARIANT`
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVBOX_SESSION_READY`
  - `WIZARD_ARGS`
  - `VERIFY_ONLY`
  - `FORCE`
- `config`:
  - `paths.vendor_dir: .devtools`
  - `config.profile_file: .git-acprc`
- `observaciones controladas no destructivas`:
  - `.git-acprc` no existe en raiz del repo.
  - `.devtools/.git-acprc` y `.devtools/.setup_completed` si existen.
  - no se ejecutaron corridas vivas ni cambios de producto en esta fase.

# Criterio de salida para promover a spec-as-source

- `Anclaje suficiente para cerrar spec-anchored`:
  - entrypoint real;
  - dispatcher chain principal;
  - camino feliz principal;
  - preconditions, inputs, outputs y side effects relevantes;
  - invariants, failure modes, ramas y seams principales;
  - superficies reales de cambio.
- `Anclaje parcial que debe permanecer visible`:
  - senal uniforme de no-readiness en toda la superficie del flujo;
  - contextualizacion puramente efimera;
  - seam del `profile_file`.
- `Divergencias que la fase siguiente no puede esconder`:
  - la rama no estricta conserva readiness aunque falle el wizard;
  - la ausencia del gatekeeper no siempre se traduce en sesion no lista.
- `Unknowns que no bloquean este cierre`:
  - bridge interno de `devbox`;
  - wording exacto de UI;
  - matices runtime no observados en vivo.
- `Unknowns o tensiones que si deben seguir visibles hacia la siguiente fase`:
  - seam entre perfil contractual en raiz y estado legado en `.devtools`;
  - dispersion de side effects materiales del wizard;
  - frontera fragil entre `DEVBOX_SESSION_READY` y exito real de verificacion.
- `Estado explicito`: `listo con reservas`.
- `Juicio final`: existe base metodologica suficiente para cerrar `spec-anchored` y usar este mapa como insumo de la fase siguiente, pero no seria legitimo promover como si el contrato de readiness ya estuviera completamente sostenido por el codigo actual.

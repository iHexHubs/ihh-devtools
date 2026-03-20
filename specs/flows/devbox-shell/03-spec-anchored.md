# Flow id

`devbox-shell`

# Intención contractual de referencia

La autoridad funcional explícita de esta fase sigue siendo [`02-spec-first.md`](/webapps/ihh-devtools/specs/flows/devbox-shell/02-spec-first.md). El contrato de referencia a anclar es: `devbox shell` debe abrir una shell Devbox repo-local asociada a este repo, exponer el entorno base definido por el repo e intentar una contextualización local de devtools cuya ruta “sesión lista/contextualizada” es condicionada, no absoluta.

Cláusulas confirmadas desde spec-first que gobiernan este anclaje:

- `Confirmado desde spec-first`: la shell base de Devbox es núcleo contractual.
- `Confirmado desde spec-first`: la contextualización local se intenta, pero no toda invocación debe terminar en experiencia interactiva completa.
- `Confirmado desde spec-first`: la ruta completa del wizard puede producir bootstrap persistente local, pero no queda prometida en toda invocación.
- `Confirmado desde spec-first`: una invocación no interactiva o `--print-env` puede dar una salida más acotada que una sesión interactiva viva.
- `Confirmado desde spec-first`: las tensiones de layout legacy no rebajan el contrato y deben quedar visibles como tensión, seam o divergencia.

Esta fase sí entra en localizar entrypoint, dispatcher chain, preconditions, inputs, outputs, side effects, invariants, failure modes, ramas y superficies reales de cambio. Esta fase no entra en implementación, refactor, tests ni `spec-as-source`.

# Entry point real anclado

- `Anclaje claro`: el entrypoint repo-específico del flujo actual vive en `shell.init_hook` de [devbox.json](/webapps/ihh-devtools/devbox.json#L45). Ese es el primer punto donde el repo define comportamiento propio de `devbox shell`.
- `Anclaje claro`: Devbox materializa ese hook en [`.devbox/gen/scripts/.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L4), lo que ancla el paso desde el comando CLI a un script ejecutable generado.
- `Anclaje claro`: el subcomando externo `devbox shell` es el wrapper de entrada y fue confirmado por observación controlada con `devbox shell --help`.
- `Descartado`: [Taskfile.yaml](/webapps/ihh-devtools/Taskfile.yaml) no es entrypoint de este flujo.
- `Descartado`: [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L1) no es entrypoint inicial; es un auxiliar alcanzado por el hook.

Evidencia principal:

- [devbox.json](/webapps/ihh-devtools/devbox.json#L45)
- [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L4)

# Dispatcher chain real anclada

Cadena principal anclada:

`devbox shell` -> `devbox.json:shell.init_hook` -> [`.devbox/gen/scripts/.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L4) -> resolución de `root` / `DT_ROOT` / `candidates` / `PATH` / aliases Git efímeros -> resolución de `setup-wizard.sh` -> [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L16) -> carga de [`lib/core/utils.sh`](/webapps/ihh-devtools/lib/core/utils.sh#L1), [`lib/core/git-ops.sh`](/webapps/ihh-devtools/lib/core/git-ops.sh#L1), [`lib/core/contract.sh`](/webapps/ihh-devtools/lib/core/contract.sh#L1) -> pasos [`step-01-auth.sh`](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh#L10), [`step-02-ssh.sh`](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh#L12), [`step-03-config.sh`](/webapps/ihh-devtools/lib/wizard/step-03-config.sh#L4), [`step-04-profile.sh`](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L4) -> mensajes finales / selector de rol / prompt si `DEVBOX_SESSION_READY=1`.

Clasificación:

- `Anclaje claro`: la cadena principal desde el hook hasta `setup-wizard.sh` está localizada y es trazable.
- `Anclaje claro`: la bifurcación fuerte del flujo vive en `DEVTOOLS_SPEC_VARIANT`, `WIZARD_ARGS` y `DEVBOX_SESSION_READY` en [devbox.json](/webapps/ihh-devtools/devbox.json#L52) y [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L65).
- `Seam / compatibilidad`: la resolución de scripts usa múltiples candidatos (`.devtools`, `.devtools/bin`, `.devtools/.devtools/bin`, `root/bin`, `root`) en lugar de una sola ruta estable; eso influye en el flujo, pero no debe promoverse automáticamente a contrato.
- `Seam / compatibilidad`: la rama de `git submodule sync/update` está integrada al hook, pero hoy opera como compatibilidad tolerada y no como núcleo contractual del flujo.

# Mapa de camino feliz

1. `Confirmado desde spec-first`: el usuario invoca `devbox shell` dentro del repo.
   `Anclaje claro`: Devbox usa [devbox.json](/webapps/ihh-devtools/devbox.json#L1) y entra por `shell.init_hook`.

2. `Confirmado desde spec-first`: el flujo expone el entorno base del repo.
   `Anclaje claro`: las variables base viven en `env` de [devbox.json](/webapps/ihh-devtools/devbox.json#L27), incluyendo `DEVBOX_ENV_NAME=IHH`, y la observación con `devbox shell --print-env` confirmó ese entorno base.

3. `Confirmado desde spec-first`: el flujo intenta contextualización local.
   `Anclaje parcial`: el hook prepara `PATH`, aliases Git efímeros y resuelve el wizard en [devbox.json](/webapps/ihh-devtools/devbox.json#L71) y [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L28), pero el soporte está disperso entre hook y wizard.

4. `Confirmado desde spec-first`: el flujo distingue entre verificación limitada y ruta más completa.
   `Anclaje claro`: `WIZARD_ARGS=--verify-only` se fuerza por marker o falta de TTY en [devbox.json](/webapps/ihh-devtools/devbox.json#L110) y [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L84).

5. `Confirmado desde spec-first`: la sesión puede quedar lista o no lista según verificación y contexto.
   `Anclaje parcial`: `DEVBOX_SESSION_READY` gobierna la ruta final en el hook, pero la evidencia viva de una sesión PTY completa no se levantó en esta fase.

6. `Confirmado desde spec-first`: en la ruta completa puede ocurrir bootstrap persistente local.
   `Anclaje claro`: auth, SSH, configuración Git, perfil, `.env` y marker están localizados en los cuatro pasos del wizard.

# Preconditions ancladas

- `Anclaje claro`: `devbox` disponible para invocar el flujo. Evidencia operativa: `devbox shell --help` respondió correctamente.
- `Anclaje claro`: el flujo debe ejecutarse dentro de un repo Git válido. Validación explícita en [`ensure_repo_or_die`](/webapps/ihh-devtools/lib/core/git-ops.sh#L48), invocada desde [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L116).
- `Anclaje claro`: el repo debe contener `devbox.json` para que Devbox resuelva el entorno; soporte visible por el uso real del archivo.
- `Anclaje claro`: el wizard valida herramientas mínimas condicionalmente. `verify-only` exige `git gh ssh grep`; la ruta full agrega `gum ssh-keygen ssh-add`; evidencia en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L97).
- `Anclaje parcial`: la experiencia interactiva completa requiere TTY. El flujo la trata explícitamente como condición de rama, pero no como precondition para abrir la shell base; soporte en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L84) y [devbox.json](/webapps/ihh-devtools/devbox.json#L115).
- `Anclaje parcial`: para verificación o bootstrap completo se asumen red, credenciales y acceso a GitHub, pero esa precondition está distribuida entre checks de `gh` y `ssh`, no centralizada como un guard único.
- `No sustentado`: una precondition mínima universal para garantizar `DEVBOX_SESSION_READY=1` en todos los clones posibles no quedó cerrada con evidencia suficiente.

# Inputs anclados

- `Anclaje claro`: comando principal `devbox shell`; wrapper confirmado por observación controlada.
- `Anclaje claro`: flags `--help`, `--print-env`, `--pure`, `--config`, `--env`, `--env-file` pertenecen al subcomando Devbox y modulan la modalidad de entrada; evidencia con `devbox shell --help`.
- `Anclaje claro`: variables de entorno moduladoras `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `DEVTOOLS_ASSUME_YES` aparecen en el flujo real. Evidencia en [devbox.json](/webapps/ihh-devtools/devbox.json#L53) y scripts bajo `bin/`/`lib/`.
- `Anclaje claro`: inputs de estado local relevantes son `TTY`, existencia de `devtools.repo.yaml`, presencia del marker, estado Git local y perfil preexistente. Evidencia en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L31) y [step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L41).
- `Anclaje claro`: el wizard parsea `--force|-f` y `--verify-only|--verify` en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L73).
- `Seam / compatibilidad`: la ruta exacta de scripts auxiliares se acepta por búsqueda dinámica en varios candidatos; eso es parsing/resolución incidental del estado actual, no input contractual central.
- `Probable`: `--print-env` representa una modalidad limitada del flujo compatible con el contrato, pero no hay evidencia suficiente para tratarlo como superficie que ejecute íntegramente la contextualización efímera.

# Outputs anclados

- `Anclaje claro`: el output base contractual es una shell Devbox repo-local o la salida equivalente de la modalidad usada; el entorno base del repo está definido en [devbox.json](/webapps/ihh-devtools/devbox.json#L27) y fue observado con `--print-env`.
- `Anclaje parcial`: el intento de contextualización se materializa en `PATH`, aliases Git efímeros, posibles mensajes de bienvenida, posible menú de rol y posible prompt contextualizado; soporte real en el hook, pero no todos esos outputs quedaron observados en ejecución viva.
- `Anclaje claro`: si la ruta full del wizard corre, puede producir `PROFILE_SCHEMA_VERSION`, entradas `PROFILES`, `.env` y marker; evidencia en [step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L41).
- `Probable`: el selector de rol cambia `DEVBOX_ENV_NAME` dentro de la sesión interactiva en [devbox.json](/webapps/ihh-devtools/devbox.json#L145), pero no quedó confirmado en PTY real.
- `No sustentado`: códigos de salida exactos y consola exacta de una sesión feliz completa no quedaron anclados con observación suficiente.

# Side effects anclados

- `Anclaje claro`: export de variables de entorno base desde [devbox.json](/webapps/ihh-devtools/devbox.json#L27).
- `Anclaje claro`: modificación efímera de `PATH`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_*`, `GIT_CONFIG_VALUE_*` y potencialmente `STARSHIP_CONFIG` en [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L34).
- `Anclaje claro`: intentos de `git config --local --unset alias.*` en la rama no variante 1; evidencia en [devbox.json](/webapps/ihh-devtools/devbox.json#L83).
- `Seam / compatibilidad`: intentos de `git submodule sync/update` en [devbox.json](/webapps/ihh-devtools/devbox.json#L54); hoy son side effects tolerados y silenciosos, no garantía contractual.
- `Anclaje claro`: el wizard full puede ejecutar `gh auth`, `gh ssh-key add`, `ssh-keygen`, `ssh-add`, `git config --global/--local`, `git remote set-url`, escribir perfil, crear `.env` y tocar marker. Evidencia en [step-01-auth.sh](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh#L53), [step-02-ssh.sh](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh#L72), [step-03-config.sh](/webapps/ihh-devtools/lib/wizard/step-03-config.sh#L107) y [step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L126).
- `Anclaje claro`: el verify-only hace consultas a `gh auth status` y `ssh -T`, con impacto de red pero sin persistencia local obligatoria, salvo directorios creados para marker.
- `Probable`: el aviso de versión mediante `git ls-remote --tags` ocurre cuando no se salta `DEVTOOLS_SKIP_VERSION_CHECK`; no se validó en ejecución viva, pero el código lo sostiene claramente.

# Invariants anclados

- `Anclaje claro`: el flujo sigue siendo repo-local. Se resuelve `root` desde `git rev-parse` en el hook y `REAL_ROOT` en el wizard; evidencia en [devbox.json](/webapps/ihh-devtools/devbox.json#L48) y [git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh#L121).
- `Anclaje claro`: la shell base de Devbox es núcleo del flujo y no depende de que la contextualización completa tenga éxito; soporte por el diseño de `devbox shell` y la observación con `--print-env`.
- `Anclaje parcial`: la ruta de verificación no debe confundirse con la ruta full. El código sí las separa, pero la coordinación entre hook y wizard está distribuida entre `DEVTOOLS_SPEC_VARIANT`, `VERIFY_ONLY` y `WIZARD_ARGS`.
- `Anclaje parcial`: el contrato funcional no fija una única ruta interna para scripts o legacy; el código actual tampoco la fija y usa búsqueda amplia. Eso sostiene la no-fijación, pero a través de una dispersión que complica el anclaje.
- `Divergencia real`: el flujo no sostiene de manera coherente una única fuente contractual para “estado previo listo” porque el hook depende de `.devtools/.setup_completed` mientras el contrato repo ya externaliza `profile_file` a raíz.

# Failure modes anclados

- `Anclaje claro`: si faltan herramientas requeridas, el wizard aborta con error explícito en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L105).
- `Anclaje claro`: si no se está dentro de un repo Git, `ensure_repo_or_die` aborta el flujo del wizard; evidencia en [git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh#L48).
- `Anclaje claro`: si no hay TTY, el wizard degrada a `--verify-only` en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L84).
- `Anclaje claro`: si falla `gh auth status` o la verificación SSH en `verify-only`, el wizard sale con error y la rama lista/contextualizada puede omitirse; evidencia en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L130).
- `Anclaje claro`: si el wizard falta y la variante exige verificación, el hook deja `DEVBOX_SESSION_READY=0` y emite mensaje de omisión; evidencia en [devbox.json](/webapps/ihh-devtools/devbox.json#L127).
- `Anclaje parcial`: en la variante no estricta, el hook ejecuta `bash "$WIZARD_SCRIPT" ... || true`; eso tolera fallos del wizard sin impedir la shell base, pero la experiencia final exacta queda más débilmente anclada.
- `No sustentado`: los códigos de salida exactos y la secuencia visible de todos los fallos interactivos no se verificaron de extremo a extremo en esta fase.

# Ramas importantes y seams de compatibilidad

- `Anclaje claro`: rama `TTY / no TTY`. Sin TTY, el wizard fuerza `--verify-only`; con TTY, puede abrir ruta interactiva.
- `Anclaje claro`: rama `marker / sin marker`. La presencia de `.devtools/.setup_completed` activa `DEVTOOLS_SPEC_VARIANT=1` en el hook y también fuerza verificación en el wizard.
- `Anclaje claro`: rama `skip wizard / no skip wizard` mediante `DEVTOOLS_SKIP_WIZARD`.
- `Seam / compatibilidad`: rama `submodule sync/update` en el hook. El repo actual no tiene `.gitmodules`, así que la rama opera como compatibilidad tolerada, silenciosa y no central.
- `Seam / compatibilidad`: búsqueda de scripts en múltiples candidatos, incluyendo rutas legacy y `root/bin`; el árbol actual resuelve efectivamente a `bin/`, porque `.devtools/bin` no existe.
- `Seam / compatibilidad`: selector de rol, `gum`, `starship` y fallback de prompt son capas de experiencia adicional; influyen en la contextualización visible sin redefinir por sí mismos el núcleo contractual.
- `Probable`: el aviso de versión remoto es una rama secundaria relevante, pero no central para el cumplimiento del contrato visible.

# Divergencias entre spec y código

- `Divergencia real`: el contrato repo declara `config.profile_file: .git-acprc` en [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml#L10), y el wizard sí intenta honrarlo en [setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L39), pero el estado real rastreado del repo mantiene el perfil en [`.devtools/.git-acprc`](/webapps/ihh-devtools/.devtools/.git-acprc#L1) y no existe [`.git-acprc`](/webapps/ihh-devtools/.git-acprc). Esta divergencia no autoriza rebajar el contrato; debe arrastrarse a la fase siguiente como tensión real entre contrato nuevo y persistencia legacy.
- `Divergencia real`: la decisión de “estado previo listo” que activa la verificación estricta sigue anclada a [`.devtools/.setup_completed`](/webapps/ihh-devtools/.devtools/.setup_completed#L1) desde [devbox.json](/webapps/ihh-devtools/devbox.json#L53) y [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L10). Esa dependencia legacy contradice una lectura más limpia del contrato repo actualizado y deja el gating en una superficie no derivada del contrato.
- `Divergencia real`: la topología actual mezcla señales de layout contractual más nuevo con gating y persistencia legacy en `.devtools`; el código no rebaja el contrato, pero tampoco lo sostiene de forma completamente alineada.

# Superficies reales de cambio

- `Superficie principal`: [devbox.json](/webapps/ihh-devtools/devbox.json#L45) y [`.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L4). Aquí vive el entrypoint real, el gating por marker/TTY, la resolución de scripts y la activación de la ruta lista/contextualizada.
- `Superficie secundaria`: [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L16). Aquí vive la resolución del contrato del repo, el parseo central del wizard y la bifurcación `verify-only/full`.
- `Superficie secundaria`: [lib/core/contract.sh](/webapps/ihh-devtools/lib/core/contract.sh#L173) y [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml#L1). Aquí vive la fuente contractual de `vendor_dir` y `profile_file`.
- `Zona de dispersión`: [step-01-auth.sh](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh#L10), [step-02-ssh.sh](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh#L12), [step-03-config.sh](/webapps/ihh-devtools/lib/wizard/step-03-config.sh#L4), [step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L4). Aquí se distribuyen side effects persistentes y parte del soporte real a la contextualización.
- `Zona de alto riesgo`: el punto donde el hook sigue leyendo `.devtools/.setup_completed` mientras el wizard ya resuelve `profile_file` por contrato. Esa desalineación concentra el riesgo metodológico principal del flujo.

# Unknowns

- `Unknown que no bloquea`: confirmación PTY completa del selector de rol, del prompt `starship` y de la consola exacta de bienvenida.
- `Unknown que tensiona`: alcance exacto de `devbox shell --print-env` respecto del init hook efímero. La observación actual confirmó entorno base, no la contextualización completa.
- `Unknown que tensiona`: comportamiento visible exacto de la rama `DEVTOOLS_SPEC_VARIANT=1` en una sesión interactiva viva.
- `Unknown que no bloquea`: detalle operativo del aviso de versión remoto cuando el repo no tiene `.gitmodules`.
- `No sustentado`: códigos de salida exactos de todas las ramas del happy path y de todos los fallos interactivos.

# Evidencia

- Paths:
  - [devbox.json](/webapps/ihh-devtools/devbox.json#L1)
  - [`.devbox/gen/scripts/.hooks.sh`](/webapps/ihh-devtools/.devbox/gen/scripts/.hooks.sh#L1)
  - [bin/setup-wizard.sh](/webapps/ihh-devtools/bin/setup-wizard.sh#L1)
  - [lib/core/git-ops.sh](/webapps/ihh-devtools/lib/core/git-ops.sh#L1)
  - [lib/core/contract.sh](/webapps/ihh-devtools/lib/core/contract.sh#L1)
  - [lib/core/utils.sh](/webapps/ihh-devtools/lib/core/utils.sh#L1)
  - [lib/wizard/step-01-auth.sh](/webapps/ihh-devtools/lib/wizard/step-01-auth.sh#L1)
  - [lib/wizard/step-02-ssh.sh](/webapps/ihh-devtools/lib/wizard/step-02-ssh.sh#L1)
  - [lib/wizard/step-03-config.sh](/webapps/ihh-devtools/lib/wizard/step-03-config.sh#L1)
  - [lib/wizard/step-04-profile.sh](/webapps/ihh-devtools/lib/wizard/step-04-profile.sh#L1)
  - [devtools.repo.yaml](/webapps/ihh-devtools/devtools.repo.yaml#L1)
  - [`.devtools/.git-acprc`](/webapps/ihh-devtools/.devtools/.git-acprc#L1)
  - [`.devtools/.setup_completed`](/webapps/ihh-devtools/.devtools/.setup_completed#L1)
- Funciones / scripts:
  - `shell.init_hook`
  - `detect_workspace_root`
  - `devtools_load_contract`
  - `devtools_profile_config_file`
  - `ensure_repo_or_die`
  - `run_step_auth`
  - `run_step_ssh`
  - `run_step_git_config`
  - `run_step_profile_registration`
- Flags:
  - `--help`
  - `--print-env`
  - `--pure`
  - `--config`
  - `--env`
  - `--env-file`
  - `--verify-only`
  - `--force`
- Variables de entorno:
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVTOOLS_ASSUME_YES`
  - `DEVTOOLS_SPEC_VARIANT`
  - `DEVBOX_SESSION_READY`
  - `DEVBOX_ENV_NAME`
  - `GIT_CONFIG_COUNT`
  - `STARSHIP_CONFIG`
- Config:
  - `paths.vendor_dir=.devtools`
  - `config.profile_file=.git-acprc`
- Observaciones controladas no destructivas:
  - `devbox shell --help` confirmó el subcomando y flags.
  - `devbox shell --print-env` confirmó el entorno base de Devbox y `DEVBOX_ENV_NAME=IHH`.
  - El repo actual no tiene `.gitmodules`.
  - El repo actual no tiene `.devtools/bin`.
  - El repo actual no tiene `.git-acprc` en raíz.

# Criterio de salida para promover a spec-as-source

Partes con anclaje suficiente:

- `Anclaje claro`: entrypoint real en `devbox.json:shell.init_hook`.
- `Anclaje claro`: dispatcher chain principal hasta `setup-wizard.sh` y los pasos del wizard.
- `Anclaje claro`: preconditions técnicas principales y ramas `TTY / marker / skip wizard`.
- `Anclaje claro`: localización de side effects persistentes y efímeros.
- `Anclaje claro`: separación real entre shell base repo-local y contextualización ampliada condicionada.

Partes con anclaje parcial:

- `Anclaje parcial`: la ruta “sesión lista/contextualizada” completa, porque depende de coordinación dispersa entre hook y wizard y no quedó observada en PTY viva.
- `Anclaje parcial`: outputs visibles exactos de menú de rol, prompt y branding.
- `Anclaje parcial`: el invariant de separación limpia entre verificación y bootstrap, porque existe pero está repartido entre varias superficies.

Divergencias y seams que la siguiente fase debe heredar sin maquillarlas:

- `Divergencia real`: `profile_file=.git-acprc` en contrato versus persistencia real observada en `.devtools/.git-acprc`.
- `Divergencia real`: gating de “setup previo listo” todavía anclado a `.devtools/.setup_completed`.
- `Seam / compatibilidad`: búsqueda de scripts en múltiples rutas y rama `submodule sync/update` tolerada.

Unknowns que no bloquean promoción:

- confirmación PTY exacta del selector de rol y prompt;
- alcance exacto de `--print-env` sobre exports efímeros;
- mensajes exactos y exit codes exhaustivos de todas las ramas.

Juicio de fase:

- `listo con reservas`

Razón del juicio:

El núcleo contractual v1 ya está suficientemente anclado para pasar a `spec-as-source`: shell Devbox repo-local, entorno base del repo, intento de contextualización condicionada y posibilidad de bootstrap persistente cuando aplica la ruta full. La promoción debe conservar explícitamente dos tensiones rectoras: el layout legacy de `.devtools` sigue gobernando partes visibles del flujo y no puede absorberse como redefinición silenciosa del contrato, pero tampoco bloquea por sí solo la promoción mientras permanezca modelado como `divergencia real` y `seam / compatibilidad`.

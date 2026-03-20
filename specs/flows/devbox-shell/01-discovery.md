# Discovery: `devbox-shell`

## Resumen rápido
- **Estado de discovery:** `lista para promover`
- **Flujo objetivo:** `devbox shell`
- **Trigger real:** comando CLI `devbox shell` ejecutado dentro del repo que contiene `devbox.json`
- **Pregunta principal:** cuando alguien corre `devbox shell` aquí, ¿por dónde entra, qué decide, qué toca y dónde termina el flujo que define el repo?
- **Respuesta corta actual:** el flujo entra por `devbox.json` en `shell.init_hook`, Devbox lo materializa en `.devbox/gen/scripts/.hooks.sh` y desde ahí resuelve raíz, prepara PATH y aliases Git efímeros, busca `setup-wizard.sh` y bifurca por TTY y marker `.devtools/.setup_completed`. En este árbol actual la resolución efectiva de scripts cae en `bin/`, no en `.devtools/bin`. La validación segura con `devbox shell --print-env` confirmó el entorno base de Devbox y `DEVBOX_ENV_NAME=IHH`, pero no confirmó la aplicación visible de los exports efímeros del `init_hook`.
- **Unknowns críticos:** alcance exacto del `init_hook` bajo `--print-env`; ejecución viva de la rama interactiva con TTY; momento real en que el flujo migrará de `.devtools/.git-acprc` a `./.git-acprc`

## 1. Flow id
**Estado:** `confirmada`

`devbox-shell`

**Notas:**
- identificador corto y específico para el flujo observado

## 2. Objetivo observable
**Estado:** `confirmada`

Habilitar una shell Devbox para este repo con paquetes, variables de entorno y bootstrap contextual del toolset local.

**Observado**
- `devbox.json` define paquetes, `env` y `shell.init_hook`.
- El hook imprime mensajes de contexto, prepara PATH, carga aliases Git efímeros y busca `setup-wizard.sh`.

**Inferido**
- El objetivo operativo del repo no es solo “entrar a Nix”, sino entrar a una shell contextualizada para trabajo local con devtools corporativos.

**No verificado**
- La experiencia interactiva completa de bienvenida y selector de rol dentro de una sesión viva.

## 3. Trigger real / entrada real
**Estado:** `confirmada`

El trigger real es el comando `devbox shell`.

**Observado**
- `devbox shell --help` describe `shell` como el subcomando que inicia una nueva shell con acceso a los paquetes.
- `devbox shell --print-env` funciona en este repo y genera el script/export del entorno.

**Descartado**
- `Taskfile.yaml` no es el entrypoint de este flujo.

## 4. Pregunta principal
**Estado:** `confirmada`

¿Cómo aterriza `devbox shell` en este repo: qué archivo lo recibe, qué cadena principal sigue, qué ramas relevantes toma, qué side effects puede disparar y hasta dónde quedó observado sin ejecutar el wizard completo?

## 5. Frontera del análisis
**Estado:** `confirmada`

Entra en este discovery:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `bin/setup-wizard.sh`
- librerías y steps que el wizard realmente carga
- artefactos de estado relacionados con este flujo: `.devtools/.setup_completed`, `.devtools/.git-acprc`, `devtools.repo.yaml`, `.env`
- validación segura con `devbox shell --help` y `devbox shell --print-env`

Queda fuera por ahora:
- internals generales de Devbox/Nix fuera de la materialización visible del hook
- ejecución interactiva completa del wizard
- `devbox-app/`
- contenido interno de todos los `bin/git-*`, salvo constatar que el hook los detecta
- fases posteriores (`spec-first`, `spec-anchored`, `spec-as-source`)

**Corte exacto de evidencia**
- la evidencia llega hasta el hook definido por el repo, su archivo generado, la resolución efectiva de scripts auxiliares en este árbol y una corrida no destructiva de `--print-env`
- no llega hasta una sesión shell interactiva completa con decisiones humanas ni hasta escrituras nuevas provocadas por el wizard

## 6. Entry point
**Estado:** `confirmada`

El entrypoint principal del flujo es `devbox.json`, sección `shell.init_hook`.

**Observado**
- `devbox.json` define `shell.init_hook` en el bloque de líneas aproximadas `45-149`.
- `.devbox/gen/scripts/.hooks.sh` replica ese hook, lo que muestra que Devbox materializa el entrypoint del repo en un script generado.

**Por qué este es el entrypoint principal**
- es el primer punto del repo donde se define comportamiento específico de `devbox shell`
- los scripts en `bin/` no se ejecutan por sí solos; son alcanzados desde el hook

**Alternativas consideradas y descartadas**
- `Taskfile.yaml`: no dispara `devbox shell`
- `bin/setup-wizard.sh`: es un auxiliar alcanzado por el hook, no el entrypoint inicial

## 7. Dispatcher chain
**Estado:** `confirmada`

Cadena principal observada/inferida:

`devbox shell` -> `devbox.json:shell.init_hook` -> `.devbox/gen/scripts/.hooks.sh` -> resolución de root/candidates/PATH -> carga efímera de aliases Git -> búsqueda de `setup-wizard.sh` -> `bin/setup-wizard.sh` -> `lib/core/utils.sh` + `lib/core/git-ops.sh` + `lib/core/contract.sh` + `lib/core/config.sh` -> `lib/wizard/step-01-auth.sh` / `step-02-ssh.sh` / `step-03-config.sh` / `step-04-profile.sh` -> mensajes finales / menú de rol / prompt contextualizado si la sesión queda lista

**Observado**
- en este árbol actual la búsqueda dinámica resuelve `setup-wizard.sh` y `git-*` contra `bin/`

**No verificado**
- una sesión PTY completa que cruce toda la cadena hasta el menú de rol

## 8. Camino feliz
**Estado:** `parcial`

**Observado**
1. `devbox shell` usa `devbox.json` del repo.
2. Devbox genera/usa `.devbox/gen/scripts/.hooks.sh`.
3. El hook resuelve `root`, `DT_ROOT=.devtools` y candidatos de búsqueda.
4. Exporta PATH con `root/bin` y `DT_BIN`.
5. Recorre aliases corporativos (`acp`, `gp`, `rp`, `promote`, `feature`, `pr`, `lim`, `devtools-update`, `devtools-evidence-e2e`) y en este repo detecta varios scripts reales en `bin/`.
6. Busca `setup-wizard.sh` y lo resuelve a `bin/setup-wizard.sh`.
7. `devbox shell --print-env` devuelve el entorno Devbox base y confirma `DEVBOX_ENV_NAME=IHH`.

**Inferido**
8. Si la rama elegida deja `DEVBOX_SESSION_READY=1`, el hook imprime bienvenida, sugiere `devbox run backend` y, con TTY, ofrece selección de rol y prompt contextualizado.

**No verificado**
9. La secuencia interactiva completa desde la entrada a la shell hasta el prompt final.

## 9. Ramas importantes
**Estado:** `confirmada`

**Observado**
- rama TTY/no TTY:
  - `setup-wizard.sh` fuerza `--verify-only` si no detecta TTY
- rama por marker:
  - si existe `.devtools/.setup_completed` y hay TTY, el hook sube `DEVTOOLS_SPEC_VARIANT=1`

**Inferido**
- variante `1`:
  - la sesión solo queda “lista” si el wizard verifica correctamente
- variante `0`:
  - ejecuta el wizard pero ignora su fallo con `|| true`
  - intenta `git submodule sync/update` para `.devtools`

**No verificado**
- comportamiento exacto visible de la variante `1` en sesión interactiva real
- efecto real de `git submodule sync/update` en clones con `.gitmodules`

## 10. Side effects
**Estado:** `parcial`

**Observado**
- export de variables de entorno definidas en `devbox.json`
- generación/uso de `.devbox/gen/scripts/.hooks.sh`
- `devbox shell --print-env` imprime el script/export del entorno

**Inferido fuerte desde código**
- intentos de `git submodule sync --recursive` y `git submodule update --init --recursive .devtools` en variante `0`
- consulta remota `git ls-remote --tags` para aviso de versión
- aliases Git efímeros vía `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_*`, `GIT_CONFIG_VALUE_*`
- ejecución del wizard con posibles efectos persistentes:
  - `gh auth`
  - `ssh-keygen`
  - `ssh-add`
  - `git config --global/--local`
  - escritura/actualización de perfil
  - posible ajuste de `origin`
  - creación de `.env`
  - `touch` del marker de setup

**No verificado**
- side effects persistentes ejecutados realmente durante esta corrida de discovery

## 11. Inputs
**Estado:** `confirmada`

**Obligatorios**
- `devbox` instalado y disponible en PATH
- ejecutar dentro de un repo que contenga `devbox.json`
- disponibilidad de `git`

**Contextuales**
- presencia de `.devtools/.setup_completed`
- existencia de `bin/setup-wizard.sh`
- estado del repo Git y root detectado
- archivo de contrato `devtools.repo.yaml`
- existencia previa de `.env`, `.git-acprc` o `.devtools/.git-acprc`
- TTY disponible o no

**Opcionales / moduladores**
- flags `--help`, `--print-env`, `--pure`, `--config`, `--env`, `--env-file`
- variables `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `DEVTOOLS_ASSUME_YES`

## 12. Outputs
**Estado:** `parcial`

**Observado**
- script de exports cuando se usa `devbox shell --print-env`
- variables de entorno del bloque `env` de `devbox.json`
- `DEVBOX_ENV_NAME=IHH` visible en `--print-env`

**Inferido**
- mensajes de consola sobre devtools, blindaje, sesión lista y sugerencias de uso
- aliases Git efímeros para la shell
- prompt contextualizado o `starship` si aplica
- creación/actualización de `.env`, marker y perfil cuando corre la rama persistente del wizard

**No verificado**
- exit code y consola de una sesión interactiva feliz completa

## 13. Preconditions
**Estado:** `confirmada`

**Observado**
- el repo debe ser un working tree Git válido
- `setup-wizard.sh` exige herramientas mínimas:
  - en `--verify-only`: `git`, `gh`, `ssh`, `grep`
  - en modo completo: además `gum`, `ssh-keygen`, `ssh-add`

**Inferido**
- para ramas de auth/SSH hacen falta red, credenciales y acceso a GitHub
- para prompt con `starship` hace falta que el binario exista

**No verificado**
- cuál es la precondición mínima exacta para que `DEVBOX_SESSION_READY=1` en todos los clones posibles

## 14. Error modes
**Estado:** `confirmada`

**Observado**
- `setup-wizard.sh` aborta si faltan herramientas obligatorias
- `ensure_repo_or_die` aborta si no se está dentro de un repo Git
- si no hay TTY, el wizard cambia a `--verify-only`

**Inferido fuerte desde código**
- si `gh auth status` falla en verificación, el wizard sale con error
- si `ssh -T` no valida autenticación, el wizard sale con error en `verify-only`
- si `setup-wizard.sh` no se encuentra:
  - el hook emite warning
  - en variante `1` marca la sesión como no lista
- si una identidad Git está duplicada, el step de config aborta

**No verificado**
- mensajes exactos y secuencia completa de error dentro de una sesión interactiva viva

## 15. Archivos y funciones involucradas
**Estado:** `confirmada`

### Núcleo
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `bin/setup-wizard.sh`
- `lib/core/git-ops.sh`
- `lib/core/contract.sh`
- `lib/core/config.sh`
- `lib/wizard/step-01-auth.sh`
- `lib/wizard/step-02-ssh.sh`
- `lib/wizard/step-03-config.sh`
- `lib/wizard/step-04-profile.sh`

### Soporte
- `.devtools/.setup_completed`
- `.devtools/.git-acprc`
- `devtools.repo.yaml`
- `.env`
- `bin/git-acp.sh`
- `bin/git-gp.sh`
- `bin/git-rp.sh`
- `bin/git-promote.sh`
- `bin/git-feature.sh`
- `bin/git-pr.sh`
- `bin/git-lim.sh`
- `bin/git-devtools-update.sh`

## 16. Sospechas de legacy / seams de compatibilidad
**Estado:** `confirmada`

**Hechos confirmados**
- el contrato actual declara `config.profile_file: .git-acprc`, pero el estado persistido visible hoy está en `.devtools/.git-acprc`
- el hook busca scripts tanto en `.devtools` como en `bin/`, y en este árbol actual resuelve a `bin/`
- el hook contempla `.devtools` como si pudiera venir de submódulo, pero en este repo actual no apareció `.gitmodules`

**Indicios fuertes**
- existe una capa de compatibilidad entre layout legacy en `.devtools` y layout contractual más nuevo en la raíz del repo

**Sospecha**
- `devbox shell --print-env` no expone toda la personalización efímera del hook, por lo que consumirlo como sustituto de la shell real puede dejar fuera parte del contexto esperado

## 17. Unknowns
**Estado:** `confirmada`

- no quedó verificado si `devbox shell --print-env` ejecuta el `init_hook` completo o si omite/excluye parte de sus exports efímeros
- no quedó observada la sesión interactiva completa con TTY, selector de rol y prompt final
- no quedó observado un caso de primera entrada sin marker `.devtools/.setup_completed`
- no quedó cerrada la migración efectiva entre `.devtools/.git-acprc` y `./.git-acprc`
- no quedó verificado el comportamiento del branch de submódulo en un clon que sí tenga `.gitmodules`

## 18. Evidencia
**Estado:** `confirmada`

- `path:` `devbox.json`
- `path:` `.devbox/gen/scripts/.hooks.sh`
- `path:` `bin/setup-wizard.sh`
- `path:` `lib/core/git-ops.sh`
- `path:` `lib/core/contract.sh`
- `path:` `lib/core/config.sh`
- `path:` `lib/wizard/step-01-auth.sh`
- `path:` `lib/wizard/step-02-ssh.sh`
- `path:` `lib/wizard/step-03-config.sh`
- `path:` `lib/wizard/step-04-profile.sh`
- `path:` `devtools.repo.yaml`
- `path:` `.devtools/.git-acprc`
- `path:` `.devtools/.setup_completed`
- `comando observado:` `command -v devbox`
- `comando observado:` `devbox shell --help`
- `comando observado:` `devbox shell --print-env`
- `comando observado:` `git rev-parse --show-toplevel`
- `comando observado:` `git remote get-url origin`
- `salida relevante:` `devbox shell --print-env` mostró `DEVBOX_ENV_NAME=IHH`
- `salida relevante:` `devbox shell --print-env` no mostró `GIT_CONFIG_COUNT`, `STARSHIP_CONFIG`, `DEVBOX_SESSION_READY` ni rutas de `bin/` del repo

## 19. Validación segura
**Estado:** `confirmada`

**Qué se validó**
- presencia del CLI `devbox`
- ayuda del subcomando `shell`
- generación del entorno con `--print-env`
- resolución efectiva de scripts buscados por el hook
- existencia de marker, perfil legacy y contrato actual

**Qué quedó confirmado**
- el flujo nace en `devbox.json`
- Devbox materializa el hook en `.devbox/gen/scripts/.hooks.sh`
- el repo actual resuelve `setup-wizard.sh` y los `git-*` desde `bin/`
- `--print-env` funciona y devuelve el entorno base del repo

**Qué siguió sin confirmarse**
- rama interactiva completa
- aplicación visible de exports efímeros del hook bajo `--print-env`

**Riesgo de ejecutar el flujo real**
- puede tocar auth GitHub, llaves SSH, `git config`, remote, `.env` y archivos de perfil

**Alternativa de baja intervención usada**
- inspección estática + `devbox shell --help` + `devbox shell --print-env`

## 20. Criterio de salida para promover a spec-first
**Estado:** `confirmada`

Quedó suficientemente claro:
- el trigger real
- el entrypoint
- la cadena principal de handoff
- las ramas TTY/no TTY y marker/no marker
- los side effects importantes que el flujo puede disparar
- los seams visibles entre contrato, layout legacy y consumo por `--print-env`

Sigue abierto:
- observación de la sesión interactiva completa
- semántica exacta de `--print-env` frente al `init_hook`

Los unknowns pendientes no bloquean la promoción porque:
- no impiden responder por dónde entra el flujo, qué decide, qué toca y dónde termina su cadena principal
- el backbone del repo ya quedó suficientemente localizado

Mínima aclaración extra si se quisiera endurecer discovery antes de promover:
- una sola observación PTY controlada de `devbox shell` sin avanzar decisiones de usuario

## 21. Respuesta canónica del discovery
**Estado:** `confirmada`

Cuando alguien ejecuta `devbox shell` en este repo, el flujo entra por `devbox.json` en `shell.init_hook`, Devbox lo materializa en `.devbox/gen/scripts/.hooks.sh` y desde ahí resuelve la raíz del workspace, prepara variables base, intenta cargar aliases Git efímeros y busca `setup-wizard.sh`. En este árbol actual la resolución efectiva cae en `bin/setup-wizard.sh`, que a su vez carga librerías de `lib/core` y pasos de `lib/wizard` para verificar o preparar el entorno local, con bifurcación relevante por TTY y por existencia del marker `.devtools/.setup_completed`. El flujo puede terminar en una shell contextualizada lista, o en una verificación fallida/no lista; lo no cerrado en este discovery es la ejecución viva completa y el alcance exacto del `init_hook` cuando se usa `--print-env`.

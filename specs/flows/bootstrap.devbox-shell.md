# Flow: bootstrap.devbox-shell

- maturity: spec-as-source
- status: active
- priority: current
- source-of-truth: this file
- related-tests:
  - tests/bootstrap_devbox_shell.bats

## Metadatos del flujo

- Repositorio: ihh-devtools
- Fecha: 2026-03-06
- Autor de la revisión: reydem
- Nombre del flujo: bootstrap.devbox-shell
- Pregunta principal que quiero responder: ¿Qué hace realmente `devbox shell` en este repo y cuáles son sus efectos reales sobre el entorno?
- Comando o entrada real del usuario: `devbox shell`
- Nivel de confianza actual: alto

## Objetivo

Documentar y fijar el contrato canónico del flujo de bootstrap del entorno que
comienza con `devbox shell`, dejando explícitos su entrypoint real, sus
side effects aceptados, sus compatibilidades heredadas y su validación mínima.

## 1. Discovery

### Minuto 0–5: fija el objetivo

#### Flujo objetivo
Bootstrap del entorno con `devbox shell`.

#### Por qué estoy revisando este flujo
Será la primera adopción formal del repo en la ruta:
`discovery -> spec-first -> spec-anchored -> spec-as-source`.

#### Qué quiero poder explicar al final
- cuál es el entrypoint real
- qué archivos participan de verdad
- qué side effects ocurren
- qué depende de Devbox y qué depende del repo

#### Qué no voy a intentar entender todavía
- `apps sync`
- `git-promote`
- `git-acp`
- el comportamiento de los comandos corporativos una vez cargados
- flujos de negocio dentro de `apps/`

#### Sospecha inicial de problema / legacy / ruido
- puede haber bootstrap implícito no documentado
- puede haber mezcla entre Devbox, Nix, shell hooks y scripts del repo
- puede haber lógica heredada de submódulo o compatibilidad
- puede haber drift entre contrato y estado persistido real

### Minuto 5–10: localiza el entrypoint real

#### Entry point probable
El entrypoint externo del flujo es `devbox shell`.
El entrypoint local del repo es `devbox.json`, específicamente `shell.init_hook`.

#### Archivo del entrypoint
- externo: binario `devbox` resuelto en `/usr/local/bin/devbox`
- local del repo: `devbox.json`

#### Función del entrypoint
No hay una función Bash única al inicio.
El punto real de control del repo es el bloque `shell.init_hook` definido en `devbox.json`
y materializado por Devbox en `.devbox/gen/scripts/.hooks.sh`.

#### Comando o trigger que lo activa
`devbox shell`

#### Cómo confirmé que este es el entrypoint
- `command -v devbox` resolvió `/usr/local/bin/devbox`
- existe `devbox.json` en la raíz del repo
- `devbox shell --help` confirma que Devbox usa la config del proyecto
- el `init_hook` del repo aparece reflejado en `.devbox/gen/scripts/.hooks.sh`

#### Archivos candidatos alternativos que descarté
- `.envrc`: no existe evidencia de uso aquí
- `shell.nix` en raíz: no existe como fuente primaria versionada
- `README.md`: describe, pero no gobierna el runtime
- `devbox.lock`: fija resolución de paquetes, no el control flow del bootstrap

### Minuto 10–20: lee solo la columna vertebral

#### Archivo 1
- rol: config / entrypoint local
- archivo: `devbox.json`
- por qué entra en el flujo:
  define `packages`, `env`, `shell.init_hook` y `scripts`

#### Archivo 2
- rol: hook efectivo generado
- archivo: `.devbox/gen/scripts/.hooks.sh`
- por qué entra en el flujo:
  muestra el bootstrap real expandido por Devbox para este workspace

#### Archivo 3
- rol: hook de paquete / soporte previo al hook del repo
- archivo: `.devbox/virtenv/poetry/bin/initHook.sh`
- por qué entra en el flujo:
  parece ejecutarse antes del hook del repo y puede afectar el entorno Python/Poetry

#### Archivo 4
- rol: gatekeeper del bootstrap
- archivo: `bin/setup-wizard.sh`
- por qué entra en el flujo:
  el `init_hook` lo invoca para verificar o completar el setup

#### Archivo 5
- rol: contrato / resolución de paths persistentes
- archivo: `lib/core/contract.sh`
- por qué entra en el flujo:
  ayuda a entender `vendor_dir`, `profile_file` y drift entre contrato y estado real

#### Archivos adicionales ya confirmados como relevantes
- `devtools.repo.yaml`
- `lib/core/utils.sh`
- `lib/core/git-ops.sh`
- `lib/wizard/step-01-auth.sh`
- `lib/wizard/step-02-ssh.sh`
- `lib/wizard/step-03-config.sh`
- `lib/wizard/step-04-profile.sh`
- `lib/ssh-ident.sh`

### Minuto 20–30: traza el camino feliz

#### Secuencia principal del flujo
`devbox shell -> devbox.json(shell.init_hook) -> .devbox/gen/scripts/.hooks.sh -> hook de Poetry -> resolución de root/.devtools -> sync/update defensivo de submódulo -> aviso de versión -> PATH + aliases efímeros Git -> setup-wizard.sh (--verify-only probable) -> mensajes de bienvenida -> selección de rol (si TTY) -> starship/prompt`

#### Paso 1
- archivo: `devbox.json`
- función: `shell.init_hook`
- qué hace:
  define el bootstrap del shell del repo

#### Paso 2
- archivo: `.devbox/gen/scripts/.hooks.sh`
- función: materialización del hook
- qué hace:
  ejecuta el hook generado que Devbox usa en el workspace

#### Paso 3
- archivo: `.devbox/virtenv/poetry/bin/initHook.sh`
- función: hook previo de paquete
- qué hace:
  prepara entorno relacionado con Poetry/Python antes del hook del repo

#### Paso 4
- archivo: `devbox.json`
- función: bloque inicial del `init_hook`
- qué hace:
  resuelve root real, calcula `DT_ROOT` / `DT_BIN`, intenta sincronizar `.devtools`, muestra aviso de versión

#### Paso 5
- archivo: `devbox.json`
- función: bloque central del `init_hook`
- qué hace:
  exporta `PATH`, limpia aliases locales persistentes, inyecta aliases efímeros con `GIT_CONFIG_COUNT`, busca y ejecuta `setup-wizard.sh`

#### Paso 6
- archivo: `bin/setup-wizard.sh`
- función: verificación o setup
- qué hace:
  resuelve `REAL_ROOT`, carga contrato, calcula `VENDOR_DIR`, intenta resolver `PROFILE_CONFIG_FILE` y define `MARKER_FILE`.
  Si existe `MARKER_FILE` y no se pasa `--force`, entra en `VERIFY_ONLY=true`.

#### Paso 7
- archivo: `bin/setup-wizard.sh`
- función: fallback de profile config
- qué hace:
  intenta resolver el profile file con `devtools_profile_config_file "$REAL_ROOT"`.
  Si eso devuelve vacío, cae explícitamente a `${VENDOR_DIR_ABS}/.git-acprc`.

#### Paso 8
- archivo: `bin/setup-wizard.sh`
- función: fast path de verificación
- qué hace:
  en modo `verify-only` valida GH CLI, prueba SSH contra el host configurado en el profile file y sale sin recorrer el setup completo.

#### Paso 9
- archivo: `devbox.json`
- función: bloque final del `init_hook`
- qué hace:
  imprime mensajes, pregunta rol si hay TTY, ajusta `DEVBOX_ENV_NAME`, define `devx()`, configura prompt con Starship o fallback

#### Decisiones importantes en el camino feliz
- Decisión 1:
  cómo se resuelve el `root` real del workspace (`git rev-parse` o `pwd`)
- Decisión 2:
  si existe `MARKER_FILE` y no se pasó `--force`, el wizard fuerza `VERIFY_ONLY=true`
- Decisión 3:
  si `devtools_profile_config_file "$REAL_ROOT"` devuelve vacío, el wizard usa fallback a `${VENDOR_DIR_ABS}/.git-acprc`
- Decisión 4:
  si no hay TTY y no se pidió `--verify-only`, el wizard también fuerza `VERIFY_ONLY=true`
- Decisión 5:
  si hay TTY, muestra selector de rol; si no, evita esa interacción
- Decisión 6:
  si existe `starship`, usa `STARSHIP_CONFIG`; si no, cae a `PROMPT/PS1`
- Decisión 7:
  si encuentra scripts corporativos, inyecta aliases efímeros de Git

#### Side effects observados
- Filesystem:
  - posible `chmod +x` sobre scripts encontrados
  - posible uso/lectura de `.devtools/.setup_completed`
  - posible uso/lectura de `.devtools/.git-acprc`
  - posible uso de `.env`
- Git:
  - `git submodule sync --recursive`
  - `git submodule update --init --recursive .devtools`
  - `git config --local --unset alias.*`
  - inyección efímera de aliases vía `GIT_CONFIG_COUNT`
- Red:
  - posible `git ls-remote` para comparar tags remotos
- Procesos externos:
  - `git`
  - `find`
  - `awk`
  - `sort`
  - `tail`
  - `gum`
  - `starship`
  - `bash`
- Variables de entorno relevantes:
  - `DEVBOX_ENV_NAME`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVTOOLS_SKIP_WIZARD`
  - `PATH`
  - `GIT_CONFIG_COUNT`
  - `STARSHIP_CONFIG`
  - `SECRET_KEY`
  - `DB_NAME`
  - `DB_USER`
  - `DB_PASSWORD`
  - `DB_HOST`
  - `DB_PORT`
  - `DB_SSLMODE`
  - `RUN_MIGRATIONS`
  - `RUN_SEED`
  - `RUN_COLLECTSTATIC`
  - `VITE_API_URL`
  - `CORS_ALLOWED_ORIGINS`
  - `CSRF_TRUSTED_ORIGINS`
  - `EXTRA_ALLOWED_HOSTS`

#### Inputs
- comando `devbox shell`
- archivo `devbox.json`
- estado Git del repo
- presencia o ausencia de `.devtools`
- presencia o ausencia de `.devtools/.setup_completed`
- presencia o ausencia de scripts corporativos en `bin/` o `.devtools/bin`
- TTY interactivo o no interactivo
- herramientas instaladas (`gum`, `starship`, `git`, etc.)

#### Outputs
- shell con entorno Devbox cargado
- variables exportadas
- `PATH` modificado
- aliases efímeros Git activos durante la sesión
- mensajes de bootstrap en consola
- prompt ajustado
- posible ejecución del wizard en modo verify-only

#### Preconditions
- estar dentro del repo o debajo de un directorio donde Devbox encuentre `devbox.json`
- disponer del binario `devbox`
- Git operativo
- estructura `.devbox/` generada o generable por Devbox

#### Error modes
- no encontrar `setup-wizard.sh`
- no encontrar scripts corporativos
- no disponer de TTY para el selector de rol
- drift entre contrato y paths reales
- posible path de starship apuntando a `.starship.toml` ausente
- ramas defensivas de submódulo que no aplican al estado actual del repo

### Minuto 30–35: detecta ruido y posible legacy

#### Archivos esenciales para este flujo
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `.devbox/virtenv/poetry/bin/initHook.sh`
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`
- `devtools.repo.yaml`

#### Archivos de soporte
- `lib/core/utils.sh`
- `lib/core/git-ops.sh`
- `lib/wizard/step-01-auth.sh`
- `lib/wizard/step-02-ssh.sh`
- `lib/wizard/step-03-config.sh`
- `lib/wizard/step-04-profile.sh`
- `lib/ssh-ident.sh`

#### Archivos que parecen ruido para este flujo
- `lib/promote/**`
- `lib/apps/**`
- `lib/ci/**`
- `devbox-app/**`
- `tests/**`
- `README.md`
- `specs/**`

#### Funciones que parecen wrappers o duplicaciones
Pendiente de confirmación fina.
Por ahora, el código de aliases corporativos parece más de despacho y lookup que de ejecución directa en este flujo.

#### Compatibilidades heredadas detectadas
- `contract.sh` trata explícitamente varios paths de profile config como defaults/legacy equivalentes.
- Entre esos paths está `${repo_root}/${vendor_dir}/.git-acprc`.
- Esto confirma compatibilidad heredada entre profile file en raíz y profile file dentro de vendor dir.
- `step-04-profile.sh` no migra ni sincroniza ambos paths; solo escribe en el `rc_file` ya resuelto.

#### Documentación que no coincide con el código
Pendiente de revisar formalmente en este flujo.
Sí hay una deriva observable entre contrato y estado persistido real del perfil.

#### Sospechas de legacy
- La lógica de submódulos sigue pareciendo defensiva o heredada, pero aún no está cerrada del todo.
- La convivencia entre `.git-acprc` y `.devtools/.git-acprc` ya no es sospecha:
  hay compatibilidad heredada explícita en `contract.sh`.
- En estado sano del repo, el path canónico esperado sigue siendo `.git-acprc`
  en raíz; el path en vendor dir queda como fallback operativo heredado.

### Minuto 35–40: valida con una ejecución segura

#### Comando de validación usado
- `command -v devbox`
- `devbox shell --help`
- inspección estática de `devbox.json`
- inspección estática de `.devbox/gen/scripts/.hooks.sh`
- inspección estática de `bin/setup-wizard.sh`
- `git rev-parse --show-toplevel`
- `git rev-parse --show-superproject-working-tree`
- `git submodule status`
- `git config --local --get-regexp '^alias\.' || true`
- `ls -la .devtools/.git-acprc .devtools/.setup_completed .env`

#### Modo seguro usado
Lectura estática + comandos informativos sin lanzar `devbox shell` interactivo.

#### Salida observada
- Devbox existe en `/usr/local/bin/devbox`
- `devbox.json` existe en la raíz
- el hook efectivo existe en `.devbox/gen/scripts/.hooks.sh`
- hay marker `.devtools/.setup_completed`
- existe `.devtools/.git-acprc`
- no hay evidencia de superproyecto Git
- no hay `.gitmodules` en la raíz

#### Coincide con el flujo trazado
Sí, parcialmente.

#### Qué parte quedó confirmada
- el entrypoint local es `devbox.json`
- hay `shell.init_hook`
- el hook hace bastante más que preparar paquetes
- el wizard forma parte real del bootstrap
- el branch verify-only es plausible en este workspace

#### Qué parte sigue sin validarse
- el orden exacto de ejecución en runtime sin inspección adicional de Devbox
- el impacto real del hook de Poetry
- si el wizard actual, en este checkout, siempre toma `--verify-only`
- si hay efectos persistentes concretos al lanzar `devbox shell` de verdad

#### Riesgos de ejecutar este flujo en real
- mutación de `.git/config`
- sincronización o update de `.devtools`
- cambios de permisos con `chmod +x`
- interacción con SSH/GitHub vía wizard si cambia de branch
- side effects no meramente efímeros

### Minuto 40–45: cierra con una ficha de flujo

#### Nombre del flujo
bootstrap.devbox-shell

#### Entry point real
`devbox shell` -> `devbox.json` -> `shell.init_hook`

#### Secuencia principal
`devbox shell -> devbox.json(shell.init_hook) -> .devbox/gen/scripts/.hooks.sh -> hook de Poetry -> resolución root/.devtools -> bootstrap Git efímero -> setup-wizard -> prompt/rol`

#### Archivo/función que toma la primera decisión fuerte
`devbox.json`, dentro de `shell.init_hook`, al resolver el `root` real y decidir cómo operar sobre `.devtools`.

#### Archivos esenciales
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `.devbox/virtenv/poetry/bin/initHook.sh`
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`
- `devtools.repo.yaml`

#### Archivos de soporte
- `lib/core/utils.sh`
- `lib/core/git-ops.sh`
- `lib/wizard/step-01-auth.sh`
- `lib/wizard/step-02-ssh.sh`
- `lib/wizard/step-03-config.sh`
- `lib/wizard/step-04-profile.sh`
- `lib/ssh-ident.sh`

#### Side effects principales
- variables de entorno exportadas
- `PATH` modificado
- aliases efímeros Git
- mensajes en consola
- prompt modificado
- posibles side effects persistentes en Git, permisos y wizard

#### Variables de entorno relevantes
- `DEVBOX_ENV_NAME`
- `DEVTOOLS_SKIP_VERSION_CHECK`
- `DEVTOOLS_SKIP_WIZARD`
- `PATH`
- `GIT_CONFIG_COUNT`
- `STARSHIP_CONFIG`
- variables `DB_*` y otras definidas en `env`

#### Errores o branches importantes
- branch con TTY / sin TTY
- branch con `starship` / fallback PS1
- branch con marker `.setup_completed` / sin marker
- branch con scripts corporativos encontrados / no encontrados
- branch con comportamiento defensivo de submódulo

#### Ruido detectado
- `lib/promote/**`
- `lib/apps/**`
- `lib/ci/**`
- `devbox-app/**`
- specs y tests

#### Sospecha de legacy
La compatibilidad entre `.git-acprc` en raíz y `${vendor_dir}/.git-acprc` está explícitamente codificada.
Lo que aún falta determinar es si el path en vendor dir sigue siendo ruta viva principal en este repo
o si quedó como fallback de compatibilidad.

#### Qué entendí bien
- `setup-wizard.sh` intenta respetar el path resuelto por contrato.
- `devtools_profile_config_file` no calcula el path por sí sola; devuelve `DEVTOOLS_PROFILE_CONFIG` después de cargar contrato.
- `step-04-profile.sh` es agnóstico al path y escribe en el `rc_file` que recibe.
- `${vendor_dir}/.git-acprc` está reconocido por el código como path legacy/fallback.
- El path canónico hoy, según código real, es `DEVTOOLS_PROFILE_CONFIG`.

#### Qué no entendí aún
- por qué el workspace actual terminó persistiendo en `.devtools/.git-acprc`
- si ese estado vino de una corrida vieja del wizard, de fallback activo o de una transición incompleta
- en qué escenarios reales del repo sigue activándose el fallback a `${vendor_dir}/.git-acprc`

#### Qué queda como investigación residual
- por qué el workspace observado persistió en `.devtools/.git-acprc`
- si ese estado proviene de una corrida vieja del wizard, de fallback activo o de una transición incompleta
- en qué escenarios reales del repo sigue activándose el fallback a `${vendor_dir}/.git-acprc`

#### Siguiente archivo o branch a revisar
`bin/setup-wizard.sh`, centrado en:
- branch `--verify-only`
- relación con `lib/wizard/step-04-profile.sh`
- cómo resuelve `.git-acprc` y `.setup_completed`

### Evidencia

- paths de archivos:
  - `devbox.json`
  - `.devbox/gen/scripts/.hooks.sh`
  - `.devbox/virtenv/poetry/bin/initHook.sh`
  - `bin/setup-wizard.sh`
  - `lib/core/contract.sh`
  - `devtools.repo.yaml`
  - `.devtools/.git-acprc`
  - `.devtools/.setup_completed`
- funciones o componentes:
  - `shell.init_hook`
  - wizard con branch `--verify-only` probable
- comandos ejecutados:
  - `command -v devbox`
  - `devbox shell --help`
  - `git rev-parse --show-toplevel`
  - `git rev-parse --show-superproject-working-tree`
  - `git submodule status`
  - `git config --local --get-regexp '^alias\.' || true`
  - `ls -la .devtools/.git-acprc .devtools/.setup_completed .env`
- observaciones de runtime:
  - no se ejecutó `devbox shell` interactivo para evitar side effects persistentes
  - se validó el flujo por evidencia estática y comandos seguros

### Promotion gate to spec-first

Cerrado:
- confirmar cómo decide el wizard entre verify-only y setup completo
- confirmar cómo resuelve realmente el profile file esperado
- separar explícitamente qué parte del flujo pertenece a Devbox/Nix y qué parte pertenece al repo
- decidir si la lógica de submódulo entra como núcleo, soporte o compatibilidad

## 2. Spec-first

### Intención

Definir el contrato intencional del flujo `bootstrap.devbox-shell` para que
`devbox shell` prepare un entorno de trabajo reproducible, verificable y seguro
para el repo, separando claramente:

- lo que pertenece al entorno efímero de shell
- lo que pertenece a validaciones del setup local
- lo que pertenece a compatibilidades heredadas

El objetivo de este flujo no es ejecutar tareas de negocio ni promover cambios
de Git, sino dejar al operador dentro de un shell listo para trabajar con las
herramientas, variables y ayudas mínimas del proyecto.

### Contrato visible para el usuario

Cuando un usuario ejecuta `devbox shell` dentro del repo:

- Devbox debe encontrar la configuración del proyecto desde `devbox.json`.
- El shell resultante debe exponer las herramientas declaradas por Devbox.
- El bootstrap del repo puede aplicar variables de entorno, `PATH`, prompt y
  ayudas de shell necesarias para trabajar dentro del proyecto.
- El bootstrap puede verificar si el setup local ya existe y, si corresponde,
  ejecutar una validación rápida del estado.
- Si el setup previo ya está marcado como completo, el flujo debe preferir una
  ruta de verificación (`verify-only`) en lugar de repetir un setup completo.
- El flujo debe poder operar en modo no interactivo degradando a verificación y
  evitando pasos que dependan de TTY.
- El usuario debe recibir señales visibles de estado: carga del entorno,
  validación del setup y problemas críticos detectados.
- Las compatibilidades heredadas pueden seguir existiendo, pero no deben definir
  el contrato principal del flujo.

### Preconditions

Para considerar válido este flujo, se asume que:

- el usuario ejecuta `devbox shell` dentro del repo o en un subdirectorio desde
  el cual Devbox pueda encontrar `devbox.json`
- el binario `devbox` está disponible
- `git` está disponible
- el repo es detectable como workspace Git válido
- el entorno puede materializar o reutilizar `.devbox/`
- si el flujo entra en validación del wizard, las herramientas mínimas de esa
  ruta deben existir
- el flujo puede encontrar el `root` real del workspace antes de tomar
  decisiones de contrato y paths

### Inputs

Los inputs relevantes de este flujo son:

- el comando `devbox shell`
- el archivo `devbox.json`
- el estado del workspace Git
- el estado de `.devtools/`
- la existencia o no de `.devtools/.setup_completed`
- el valor resuelto por contrato para `DEVTOOLS_PROFILE_CONFIG`
- la disponibilidad de TTY
- la presencia de herramientas auxiliares como `gh`, `ssh`, `gum`, `starship`
- variables de entorno como:
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVBOX_ENV_NAME`
  - `DEVTOOLS_ALLOW_ABSOLUTE_PATHS`

### Outputs

Los outputs esperados del flujo son:

- un shell Devbox funcional para el repo
- variables de entorno exportadas
- `PATH` ajustado para incluir herramientas del repo y de `.devtools`
- aliases efímeros o comportamiento equivalente para herramientas corporativas
- prompt configurado con Starship o con fallback de shell
- mensajes visibles de bootstrap y estado
- una verificación rápida del setup cuando aplique
- errores explícitos si faltan dependencias críticas del branch activo

### Invariants

Estas condiciones deberían mantenerse siempre en el contrato del flujo:

- `devbox.json` es la fuente primaria del bootstrap del repo.
- El entrypoint local del repo para este flujo es `shell.init_hook`.
- El flujo debe resolver primero el `root` real del workspace antes de tomar
  decisiones sobre vendor dir, marker o profile file.
- El path canónico del profile file es el resuelto por
  `DEVTOOLS_PROFILE_CONFIG`.
- `${vendor_dir}/.git-acprc` debe considerarse compatibilidad o fallback, no
  fuente principal del contrato.
- `step-04-profile.sh` no debe decidir la política del path; solo debe escribir
  en el path ya resuelto.
- Si existe marker de setup y no se fuerza reparación, el flujo debe evitar el
  setup completo y preferir verificación.
- Si no hay TTY, el flujo debe evitar interacción y degradar con seguridad.
- El bootstrap no debe depender de README ni de documentación para funcionar.
- Los flujos de `apps`, `promote`, `acp` y similares quedan fuera del contrato
  principal de `bootstrap.devbox-shell`.
- La persistencia estable aceptada del flujo se limita a:
  - `.git-acprc` en la raíz del repo
  - `.devtools/.setup_completed`
- La creación inicial de `.env` puede existir como scaffolding local de primer bootstrap, pero no debe redefinir el contrato principal.
- El wizard forma parte intrínseca del bootstrap actual del repo.
- Su invocación pertenece al contrato principal del flujo, aunque su ejecución sea de fallo blando.
- Los mecanismos de bypass, warning por ausencia y degradación segura deben tratarse como soporte del flujo, no como su núcleo contractual.

### Failure modes

Los fallos esperados y su significado son:

- Devbox no encuentra `devbox.json`:
  el flujo no pertenece al repo actual o no fue lanzado desde el lugar correcto.
- falta una herramienta crítica del branch activo:
  el bootstrap no puede garantizar un entorno válido.
- falla la detección del repo:
  el wizard no puede validar ni resolver contrato correctamente.
- falla autenticación de `gh` en modo verificación:
  el entorno existe, pero el setup operativo no está sano.
- falla la prueba SSH en modo verificación:
  el entorno existe, pero la identidad o conectividad requerida no está sana.
- el profile file resuelto es inválido o queda vacío:
  el flujo puede caer a fallback, pero eso debe tratarse como compatibilidad,
  no como comportamiento ideal.
- no se encuentra `setup-wizard.sh`:
  el shell puede cargar parcialmente, pero el contrato de validación queda roto.
- falta `starship`:
  no debe romper el flujo; debe existir un fallback de prompt.
- falta TTY:
  no debe romper el flujo; debe entrar en ruta no interactiva segura.

### No-goals

Este flujo no es responsable de:

- ejecutar `apps sync`
- ejecutar `git-promote`, `git-acp` o workflows derivados
- garantizar que el setup completo se repita en cada entrada al shell
- decidir políticas de negocio de apps o despliegue
- limpiar o eliminar automáticamente compatibilidades heredadas
- reescribir contrato, README o tests por sí mismo
- corregir drift histórico fuera del bootstrap inmediato
- tratar como contractuales mutaciones persistentes oportunistas del workspace, como limpieza de aliases locales o `chmod +x` sobre scripts encontrados

### Ejemplos

#### Ejemplo 1: entrada normal con setup ya existente
El usuario entra al repo y ejecuta `devbox shell`.

Resultado esperado:
- Devbox carga paquetes y entorno
- el hook del repo corre
- se resuelve el workspace root
- se detecta marker de setup
- el wizard toma ruta `verify-only`
- se validan GH y SSH
- el shell queda listo con PATH, prompt y ayudas cargadas

#### Ejemplo 2: entrada sin TTY
El flujo es activado en un contexto no interactivo.

Resultado esperado:
- no se intenta selector interactivo de rol
- el wizard no toma ruta full interactiva
- se degrada a verificación o ruta segura equivalente
- el flujo falla solo si faltan dependencias críticas de esa ruta segura

#### Ejemplo 3: ausencia de Starship
El usuario ejecuta `devbox shell` pero `starship` no está disponible.

Resultado esperado:
- el flujo no debe abortar
- debe aplicar un fallback razonable a `PROMPT` o `PS1`

#### Ejemplo 4: profile file canónico no resolvible
El contrato no logra resolver un `DEVTOOLS_PROFILE_CONFIG` válido.

Resultado esperado:
- el código puede caer a `${vendor_dir}/.git-acprc`
- esa caída debe entenderse como compatibilidad/fallback
- no debe redefinir el contrato canónico del flujo

### Acceptance candidates

Estas afirmaciones deberían convertirse luego en validaciones Bats o checks
equivalentes:

- `devbox.json` define el bootstrap principal del flujo.
- el flujo contiene un `shell.init_hook` activo.
- el bootstrap resuelve el `root` real antes de cargar paths persistentes.
- el wizard entra en `verify-only` si existe marker y no hay `--force`.
- el wizard también degrada a verificación si no hay TTY.
- el path canónico del profile file se toma de `DEVTOOLS_PROFILE_CONFIG`.
- `${vendor_dir}/.git-acprc` es tratado como compatibilidad heredada.
- `step-04-profile.sh` escribe en el path recibido, no decide el path canónico.
- la ausencia de `starship` no rompe el shell.
- `apps sync`, `promote` y `acp` no forman parte del contrato principal de este
  flujo.

### Preguntas abiertas

Todavía quedan abiertas estas preguntas residuales:

- en qué escenarios reales del repo sigue activándose el fallback a
  `${vendor_dir}/.git-acprc`
- qué peso real tiene el hook de Poetry en el bootstrap observable
- si la lógica de submódulo sigue siendo necesaria o solo defensiva

### Promotion gate to spec-anchored

Cerrado:
- se mapeó el contrato a archivos y funciones concretas
- se separó bootstrap Devbox, bootstrap del repo, validación de setup y compatibilidad heredada
- se ubicó dónde se impone `DEVTOOLS_PROFILE_CONFIG`
- se ubicó dónde entra el vendor profile como fallback
- se clasificaron side effects persistentes entre contrato, soporte y drift

## 3. Spec-anchored

### Code anchors

#### `devbox.json`
Rol:
- fuente primaria de configuración del flujo
- define paquetes, variables `env`, `shell.init_hook` y scripts auxiliares

Responsabilidad dentro del contrato:
- declarar el bootstrap local del repo
- fijar las variables de entorno visibles al usuario
- definir la secuencia principal del hook
- decidir la existencia de ramas como:
  - chequeo de versión
  - resolución de root
  - carga de aliases efímeros
  - invocación del wizard
  - selector de rol
  - configuración del prompt

#### `.devbox/gen/scripts/.hooks.sh`
Rol:
- artefacto generado por Devbox para este workspace

Responsabilidad dentro del contrato:
- mostrar el hook efectivo materializado para la sesión real
- servir como evidencia de cómo Devbox expande y ejecuta el `shell.init_hook`
- reflejar que el bootstrap observable no vive solo en `devbox.json`, sino en el hook generado que Devbox usa en runtime

Límite:
- no es la fuente conceptual principal del contrato
- es evidencia de runtime generado, no la definición autoritativa del comportamiento del repo

#### `bin/setup-wizard.sh`
Rol:
- gatekeeper operativo del setup local

Responsabilidad dentro del contrato:
- resolver el `REAL_ROOT`
- cargar contrato antes de tomar decisiones de path
- resolver `VENDOR_DIR`, `PROFILE_CONFIG_FILE` y `MARKER_FILE`
- degradar a `verify-only` cuando:
  - no hay TTY
  - existe marker y no hay `--force`
- ejecutar el fast path de verificación
- ejecutar el full path solo cuando corresponde
- actuar como gatekeeper intrínseco del bootstrap, aunque sin romper el shell si falla

#### `lib/core/contract.sh`
Rol:
- núcleo de resolución contractual del repo

Responsabilidad dentro del contrato:
- resolver `DEVTOOLS_PROFILE_CONFIG`
- resolver `vendor_dir`
- distinguir path canónico vs defaults/legacy
- normalizar paths y vaciarlos cuando no son válidos
- exponer funciones accessor que otros módulos usan sin reimplementar la lógica contractual

#### `lib/wizard/step-04-profile.sh`
Rol:
- escritor del profile file ya resuelto

Responsabilidad dentro del contrato:
- operar sobre `DEVTOOLS_WIZARD_RC_FILE`
- crear o actualizar el archivo de perfil en el path recibido
- no decidir política de ubicación
- no redefinir el path canónico
- no sincronizar root-profile y vendor-profile

### Mapeo del camino feliz

#### Paso 1: entrada al flujo
Archivo:
- `devbox.json`

Anclaje:
- el flujo parte externamente desde `devbox shell`
- localmente, el repo se ancla en `devbox.json`

Contrato que sostiene:
- `devbox.json` es la fuente primaria del bootstrap del repo

#### Paso 2: materialización del hook
Archivo:
- `.devbox/gen/scripts/.hooks.sh`

Anclaje:
- Devbox genera un script de hook efectivo para el workspace

Contrato que sostiene:
- el bootstrap observable del shell pasa por el hook generado
- el `shell.init_hook` realmente entra en ejecución como parte del flujo

#### Paso 3: bootstrap inicial del repo
Archivo:
- `devbox.json`

Anclaje:
- bloque `shell.init_hook`

Contrato que sostiene:
- resolver `root`
- preparar `DT_ROOT` y `DT_BIN`
- exportar `PATH`
- preparar señales visibles de estado
- iniciar la lógica propia del repo antes del prompt final

#### Paso 4: entrada al wizard
Archivo:
- `bin/setup-wizard.sh`

Anclaje:
- el hook llama a `setup-wizard.sh` automáticamente durante `devbox shell`

Contrato que sostiene:
- el wizard forma parte intrínseca del bootstrap actual del repo
- no es un flujo manual posterior
- hoy funciona como gatekeeper de fallo blando: participa del camino principal, pero no aborta el shell si falla

#### Paso 5: resolución contractual
Archivo:
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`

Anclaje:
- `setup-wizard.sh` llama `devtools_load_contract "$REAL_ROOT"`
- luego obtiene `PROFILE_CONFIG_FILE` con `devtools_profile_config_file`

Contrato que sostiene:
- el path canónico del profile file no se inventa localmente en el wizard
- se obtiene desde la capa de contrato

#### Paso 6: decisión sobre marker y modo de ejecución
Archivo:
- `bin/setup-wizard.sh`

Anclaje:
- cálculo de `MARKER_FILE`
- branch `VERIFY_ONLY`

Contrato que sostiene:
- si ya existe marker y no hay `--force`, el flujo debe preferir verificación
- si no hay TTY, el flujo debe degradar de forma segura

#### Paso 7: fallback de profile path
Archivo:
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`

Anclaje:
- si `devtools_profile_config_file` queda vacío, el wizard cae a `${VENDOR_DIR_ABS}/.git-acprc`
- `contract.sh` reconoce explícitamente defaults/legacy compatibles

Contrato que sostiene:
- el fallback existe
- pero el fallback no redefine el path canónico del contrato

#### Paso 8: escritura del profile file
Archivo:
- `lib/wizard/step-04-profile.sh`

Anclaje:
- usa `DEVTOOLS_WIZARD_RC_FILE`
- si no está seteado, cae a `.git-acprc`

Contrato que sostiene:
- este módulo escribe en el path recibido
- no elige el path canónico
- no resuelve drift entre root y vendor dir

#### Paso 9: cierre del shell
Archivo:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`

Anclaje:
- selector de rol, `DEVBOX_ENV_NAME`, `devx()`, starship o fallback de prompt

Contrato que sostiene:
- el shell final debe quedar utilizable
- el prompt no debe ser requisito duro
- la experiencia interactiva depende de TTY y de herramientas disponibles

### Mapeo de ramas

#### Rama A: root resolution
Archivos:
- `devbox.json`
- `bin/setup-wizard.sh`

Qué rama modela:
- uso de `git rev-parse` o fallback a `pwd`
- detección del workspace real antes de decidir paths

Impacto contractual:
- el bootstrap debe operar sobre el root correcto antes de tocar contrato, marker o profile file

#### Rama B: marker presente
Archivo:
- `bin/setup-wizard.sh`

Qué rama modela:
- si existe `MARKER_FILE` y no hay `--force`, entra en `verify-only`

Impacto contractual:
- el setup completo no debe repetirse innecesariamente

#### Rama C: no TTY
Archivo:
- `bin/setup-wizard.sh`

Qué rama modela:
- degradación automática a `verify-only`

Impacto contractual:
- el flujo debe funcionar de forma segura en contexto no interactivo

#### Rama D: profile file canónico resuelto
Archivo:
- `lib/core/contract.sh`

Qué rama modela:
- `DEVTOOLS_PROFILE_CONFIG` queda con un path válido después de cargar contrato

Impacto contractual:
- ese path es el canónico del flujo

#### Rama E: profile file vacío o inválido
Archivos:
- `lib/core/contract.sh`
- `bin/setup-wizard.sh`

Qué rama modela:
- `DEVTOOLS_PROFILE_CONFIG` queda vacío
- el wizard cae a `${VENDOR_DIR_ABS}/.git-acprc`

Impacto contractual:
- entra en juego compatibilidad heredada
- no cambia el contrato canónico

#### Rama F: Starship disponible / no disponible
Archivos:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`

Qué rama modela:
- inicialización de Starship o fallback a `PROMPT/PS1`

Impacto contractual:
- la personalización del prompt es opcional
- el shell no debe fallar por ausencia de Starship

#### Rama G: selector de rol interactivo
Archivos:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`

Qué rama modela:
- si hay TTY, se pregunta rol
- si no hay TTY, esa interacción no ocurre

Impacto contractual:
- la interacción mejora la UX, pero no define el núcleo funcional del bootstrap

#### Rama H: wizard presente / ausente / bypass
Archivos:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`
- `bin/setup-wizard.sh`

Qué rama modela:
- si el wizard existe y no está saltado por `DEVTOOLS_SKIP_WIZARD`, el bootstrap lo ejecuta
- si falta, el hook emite warning
- si falla, el shell continúa por tolerancia explícita del hook

Impacto contractual:
- la invocación del wizard pertenece al contrato principal actual
- la tolerancia al fallo, el bypass y el warning por ausencia deben tratarse como soporte o compatibilidad

### Drift notes

#### Drift 1: canónico vs estado observado
- En este repo, el path contractual sano esperado es `${repo_root}/.git-acprc`.
- El workspace observado contiene `.devtools/.git-acprc`.
- Esto confirma drift local o activación de fallback heredado, no cambio del path canónico.

#### Drift 2: path contractual vs path persistido local
- `step-04-profile.sh` no corrige ni migra automáticamente entre root-profile y vendor-profile.
- Por eso puede persistir estado heredado aunque el contrato apunte a un path más canónico.

#### Drift 3: bootstrap efímero vs side effects persistentes
- El flujo parece “de shell”, pero hoy incorpora efectos persistentes potenciales.
- Según el contrato que se está consolidando, la persistencia estable aceptada debe limitarse a:
  - el profile file contractual en `.git-acprc` en raíz
  - el marker `.devtools/.setup_completed`
- La creación inicial de `.env` puede tolerarse como scaffolding de primer bootstrap.
- Otras mutaciones persistentes del workspace o del repo no deben definir el contrato principal del flujo.

#### Drift 4: submódulo / vendor dir
- El hook contiene lógica defensiva de submódulo y búsqueda múltiple de scripts.
- En este repo esa parte no quedó plenamente justificada como núcleo del flujo.
- Hoy debe tratarse como zona defensiva o compatibilidad, no como centro del contrato.

#### Drift 5: mutaciones persistentes disfrazadas de efímeras
- El hook contiene un bloque presentado como “Configuración EFÍMERA”.
- Sin embargo, dentro de ese bloque hay mutaciones persistentes reales, por ejemplo:
  - `git config --local --unset alias.*`
  - `chmod +x` sobre scripts encontrados
- Esto indica una diferencia entre la intención declarada del flujo y su efecto real sobre el workspace.

#### Drift 6: wizard intrínseco pero de fallo blando
- El wizard pertenece al camino principal actual del bootstrap.
- Sin embargo, el hook lo ejecuta con tolerancia explícita al fallo (`|| true`).
- Esto genera una tensión entre “parte central del flujo” y “componente no bloqueante”.
- La spec debe conservar ambas cosas: centralidad funcional y fallo blando explícito.

### Legacy seams

#### Seam 1: root profile vs vendor profile
Archivos:
- `lib/core/contract.sh`
- `bin/setup-wizard.sh`
- `lib/wizard/step-04-profile.sh`

Descripción:
- el código admite convivencia entre `.git-acprc` y `${vendor_dir}/.git-acprc`
- `contract.sh` marca el vendor profile como legacy/default compatible
- el wizard y `step-04` no eliminan ni migran automáticamente esa convivencia

Estado:
- compatibilidad heredada explícita
- no simple sospecha

#### Seam 2: fallback contractual
Archivos:
- `lib/core/contract.sh`
- `bin/setup-wizard.sh`

Descripción:
- si el profile path canónico queda vacío, el wizard cae al vendor dir
- este seam mantiene el flujo operativo aun cuando la resolución canónica no domina

Estado:
- fallback vivo
- compatibilidad heredada operativa
- no debe confundirse con persistencia contractual principal

#### Seam 3: lógica de submódulo
Archivos:
- `devbox.json`
- `.devbox/gen/scripts/.hooks.sh`

Descripción:
- el bootstrap intenta sync/update de `.devtools` como si ese componente pudiera venir de submódulo o layout heredado

Estado:
- seam defensivo
- todavía no confirmado como estrictamente necesario en este repo

### Estado de validación

#### Validado con evidencia fuerte
- `devbox.json` es la fuente primaria del bootstrap
- existe `shell.init_hook`
- Devbox materializa ese hook en `.devbox/gen/scripts/.hooks.sh`
- `setup-wizard.sh` forma parte del flujo real
- `setup-wizard.sh` resuelve contrato antes de elegir profile file
- existe branch `verify-only`
- existe degradación por no TTY
- `${vendor_dir}/.git-acprc` está codificado como compatibilidad/fallback
- `step-04-profile.sh` escribe en el path recibido y no decide la política del path

#### Validado parcialmente
- el peso exacto del hook de Poetry en el bootstrap observable
- la necesidad real de la lógica de submódulo en este repo
- el branch operativo dominante en distintos workspaces, no solo en este checkout

#### Aún no validado del todo
- en qué escenarios reales del repo sigue activándose el fallback a vendor profile
- qué peso real tiene el hook de Poetry en el bootstrap observable
- qué parte de la lógica de submódulo sigue siendo necesaria en workspaces reale

### Refactor safety notes

Si este flujo cambia en el futuro, no se debería romper lo siguiente:

- `devbox.json` debe seguir siendo el punto primario de bootstrap local
- el `root` real debe resolverse antes de cargar contrato o paths persistentes
- `DEVTOOLS_PROFILE_CONFIG` debe seguir siendo la referencia canónica del profile file
- `${vendor_dir}/.git-acprc` no debe reaparecer como path “principal” sin documentarlo explícitamente
- `step-04-profile.sh` no debe absorber lógica contractual que hoy pertenece a `contract.sh`
- la degradación segura a `verify-only` por marker o ausencia de TTY no debe perderse
- la ausencia de Starship no debe romper el shell
- el bootstrap no debe empezar a depender de flujos ajenos como `apps sync` o `promote`
- la persistencia estable aceptada del flujo debe limitarse a `.git-acprc` en raíz y `.devtools/.setup_completed`
- cualquier otra mutación persistente debe quedar clasificada como soporte temporal o drift explícito

### Promotion gate to spec-as-source

Cerrado:
- el mapeo fue condensado en contrato canónico breve y estable
- la persistencia estable aceptada se limita a `.git-acprc` en raíz y `.devtools/.setup_completed`
- las ramas de soporte y compatibilidad quedaron clasificadas
- los acceptance candidates quedaron conectados con `tests/bootstrap_devbox_shell.bats`
- el wizard quedó fijado como parte intrínseca del bootstrap actual, con fallo blando
- el path contractual sano esperado quedó fijado en `${repo_root}/.git-acprc`

## 4. Spec-as-source

### Contrato canónico

El flujo `bootstrap.devbox-shell` define el bootstrap oficial del entorno local
del repo cuando el usuario ejecuta `devbox shell`.

Su comportamiento canónico es este:

- Devbox localiza `devbox.json` y usa su `shell.init_hook` como entrypoint local
  del bootstrap.
- El bootstrap resuelve primero el `root` real del workspace antes de tomar
  decisiones sobre paths, marker o profile file.
- El bootstrap del repo prepara el entorno de shell necesario para trabajar en
  el proyecto, incluyendo variables de entorno, ajuste de `PATH`, prompt y
  ayudas de sesión.
- El wizard forma parte intrínseca del contrato principal actual del flujo,
  aunque opera como gatekeeper de fallo blando.
- Si existe marker de setup y no se pasó `--force`, el flujo debe preferir la
  ruta `verify-only`.
- Si no hay TTY, el flujo debe degradar a `verify-only` o a una ruta segura
  equivalente.
- El path canónico del profile file en estado sano de este repo es
  `.git-acprc` en la raíz del repo.
- `${vendor_dir}/.git-acprc` se conserva sólo como fallback operativo de
  compatibilidad heredada cuando la resolución contractual de `profile_file`
  devuelve vacío.
- `step-04-profile.sh` no decide política de path; sólo escribe en el path ya
  resuelto.
- La ausencia de `starship` no debe romper el shell; debe existir fallback a
  `PROMPT` o `PS1`.

### Tests obligatorios

La validación mínima de este flujo debe cubrir, como base contractual:

- A1. `devbox.json` define el bootstrap principal mediante `shell.init_hook`.
- A2. `.devbox/gen/scripts/.hooks.sh` materializa el hook efectivo del
  workspace.
- A3. El hook resuelve `root` antes de derivar `DT_ROOT` y `DT_BIN`.
- A4. El hook busca `setup-wizard.sh`, respeta `DEVTOOLS_SKIP_WIZARD` y lo
  ejecuta como gatekeeper no fatal.
- A5. `setup-wizard.sh` resuelve `PROFILE_CONFIG_FILE` vía
  `devtools_profile_config_file "$REAL_ROOT"` y sólo cae a
  `${VENDOR_DIR_ABS}/.git-acprc` si el valor queda vacío.
- A6. `contract.sh` trata `${repo_root}/${vendor_dir}/.git-acprc` como
  compatibilidad heredada, manteniendo `DEVTOOLS_PROFILE_CONFIG` como fuente
  canónica del path.
- A7. `step-04-profile.sh` escribe en el `rc_file` recibido y no recalcula el
  path canónico.
- A8. El wizard entra en `verify-only` si existe marker y no se pasó `--force`.
- A9. El wizard degrada a `verify-only` cuando no hay TTY.
- A10. La ausencia de `starship` tiene fallback explícito y no rompe el flujo.

### Protocolo de cambio

Cuando este flujo cambie:

1. actualizar primero esta spec
2. actualizar después el código
3. actualizar después los tests Bats
4. documentar explícitamente cualquier drift, compatibilidad o deprecación

Ningún cambio debería volver a presentar `${vendor_dir}/.git-acprc` como path
principal sin actualizar antes esta spec.

Ningún cambio debería introducir nuevas mutaciones persistentes del workspace
como parte del contrato principal sin dejarlas explícitas aquí.

### Notas de deprecación

- `${vendor_dir}/.git-acprc` sigue siendo path operativo sólo como fallback de
  compatibilidad heredada.
- La convivencia entre root-profile y vendor-profile no debe tratarse como
  diseño principal del flujo.
- La lógica defensiva de submódulo y búsqueda múltiple de scripts sigue siendo
  soporte o compatibilidad hasta que se demuestre lo contrario.
- Mutaciones persistentes como `git config --local --unset alias.*`,
  `chmod +x` sobre scripts encontrados o `submodule sync/update` no forman parte
  de la persistencia contractual principal del flujo.
- La persistencia estable aceptada del bootstrap se limita a:
  - `.git-acprc` en la raíz del repo
  - `.devtools/.setup_completed`
- La creación inicial de `.env` puede tolerarse como scaffolding local de primer
  bootstrap, pero no redefine el contrato principal.

### Historial de revisión

- 2026-03-06: flujo promovido a `spec-as-source` tras cerrar:
  - entrypoint local en `devbox.json`
  - wizard como parte intrínseca del bootstrap actual
  - path canónico sano en `.git-acprc` de raíz
  - vendor profile como fallback heredado
  - persistencia contractual limitada a `.git-acprc` y `.devtools/.setup_completed`
  - plan mínimo de validación con Bats
  
## Promotion log

- stage: discovery
  date: 2026-03-06
  reason: flujo real identificado y documentado con evidencia estática

- stage: spec-first
  date: 2026-03-06
  reason: contrato intencional definido para bootstrap.devbox-shell

- stage: spec-anchored
  date: 2026-03-06
  reason: contrato amarrado a devbox.json, hook generado, wizard, contract.sh y step-04-profile.sh

- stage: spec-as-source
  date: 2026-03-06
  reason: path canónico, persistencia contractual, rol del wizard y estrategia mínima de validación quedaron definidos
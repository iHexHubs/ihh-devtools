# Flow: bootstrap.devbox-shell

- maturity: discovery
- status: active
- priority: current
- source-of-truth: this file
- related-tests:
  - tests/bootstrap_devbox_shell.bats

## Metadatos del flujo

- Repositorio: ihh-devtools
- Fecha:
- Autor de la revisión:
- Nombre del flujo: bootstrap.devbox-shell
- Pregunta principal que quiero responder: ¿Qué hace realmente `devbox shell` en este repo y cuáles son sus efectos reales sobre el entorno?
- Comando o entrada real del usuario: `devbox shell`
- Nivel de confianza actual: bajo

## Objetivo

Entender el flujo de bootstrap del entorno que comienza con `devbox shell`
y promoverlo gradualmente por las cuatro etapas de madurez.

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
  por la presencia de `.devtools/.setup_completed`, el branch más probable hoy es `--verify-only`

#### Paso 7
- archivo: `devbox.json`
- función: bloque final del `init_hook`
- qué hace:
  imprime mensajes, pregunta rol si hay TTY, ajusta `DEVBOX_ENV_NAME`, define `devx()`, configura prompt con Starship o fallback

#### Decisiones importantes en el camino feliz
- Decisión 1:
  cómo se resuelve el `root` real del workspace (`git rev-parse` o `pwd`)
- Decisión 2:
  si existe `.devtools/.setup_completed`, el wizard probablemente entra en `--verify-only`
- Decisión 3:
  si hay TTY, muestra selector de rol; si no, evita esa interacción
- Decisión 4:
  si existe `starship`, usa `STARSHIP_CONFIG`; si no, cae a `PROMPT/PS1`
- Decisión 5:
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
- el hook intenta trabajar con `.devtools` como si pudiera venir de submódulo
- hace `submodule sync/update` aunque en esta raíz no hay `.gitmodules`
- existe tolerancia a múltiples rutas candidatas para encontrar scripts corporativos

#### Documentación que no coincide con el código
Pendiente de revisar formalmente en este flujo.
Sí hay una deriva observable entre contrato y estado persistido real del perfil.

#### Sospechas de legacy
- lógica de submódulos puede ser fallback defensivo o legado
- la resolución de scripts a través de múltiples candidatos parece acumulación histórica
- puede haber drift entre `profile_file: .git-acprc` y el uso real de `.devtools/.git-acprc`

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
La parte de submódulos y ciertos paths de perfil parecen mezcla de compatibilidad y drift, pero aún no está confirmado como legacy real.

#### Qué entendí bien
- el bootstrap es más grande que un simple shell env
- el núcleo está en `devbox.json` y su hook generado
- el wizard sí es parte del flujo
- hay side effects persistentes potenciales

#### Qué no entendí aún
- el branch exacto del wizard en runtime
- el peso real del hook de Poetry
- si la lógica de submódulo sigue siendo necesaria hoy
- si `.devtools/.git-acprc` es transición o estado definitivo

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

Antes de promover a `spec-first`, falta cerrar estas dudas:
- confirmar cómo decide el wizard entre verify-only y setup completo
- confirmar cómo resuelve realmente el profile file esperado
- separar explícitamente qué parte del flujo pertenece a Devbox/Nix y qué parte pertenece al repo
- decidir si la lógica de submódulo entra como núcleo, soporte o compatibilidad

## 2. Spec-first

No iniciado.

## 3. Spec-anchored

No iniciado.

## 4. Spec-as-source

No iniciado.

## Promotion log

- stage: discovery
- date: pending
- reason: initial scaffold
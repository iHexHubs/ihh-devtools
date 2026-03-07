# Flow: git-acp.post-push

- maturity: discovery
- status: draft
- priority: active
- source-of-truth: this file
- related-tests:
  - tests/git_acp_post_push.bats

## Objetivo

Describir y madurar el flujo reusable que se ejecuta después del push exitoso de ACP
y que también puede ser invocado desde otros entrypoints del repo.

Pega esto tal cual dentro de `specs/flows/git-acp.post-push.md`:

```md
## 1. Discovery

### Entry point

Entrypoint funcional central confirmado:

- `lib/ci-workflow.sh::run_post_push_flow`

Callers observados que convergen en ese entrypoint:

- `bin/git-acp.sh::do_push`
- `bin/git-ci.sh`
- `bin/git-promote.sh` en el flujo `local`

Conclusión de discovery:
este flujo no debe modelarse como lógica exclusiva de `git-acp`, sino como un workflow reusable cuyo centro real es `run_post_push_flow`.

### Dispatcher chain

Cadenas de activación confirmadas:

- `bin/git-acp.sh::do_push`
  -> `POST_PUSH_FLOW=true run_post_push_flow "$current_branch" "$base_branch"`

- `bin/git-ci.sh`
  -> `run_post_push_flow "$CURRENT_BRANCH" "$BASE_BRANCH"`

- `bin/git-promote.sh`
  -> `POST_PUSH_FLOW=true run_post_push_flow "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" "local"`

Dispatcher interno del workflow:

- `run_post_push_flow`
  -> `ci_ensure_ui_fallbacks`
  -> guardas de activación / TTY / modo no interactivo / rama protegida
  -> `detect_ci_tools`
  -> `ci_render_validation_menu_header`
  -> `ci_build_validation_menu`
  -> `ci_prompt_validation_menu`
  -> `ci_normalize_selection`
  -> `ci_map_validation_option`
  -> `ci_run_validation_option`

### Camino feliz

Camino común confirmado hasta la primera bifurcación interactiva:

- `bin/git-acp.sh::do_push`
  -> push exitoso
  -> `lib/ci-workflow.sh::run_post_push_flow`
  -> `ci_ensure_ui_fallbacks`
  -> validación de modo interactivo / TTY
  -> exclusión de ramas protegidas
  -> `detect_ci_tools`
  -> `ci_render_validation_menu_header`
  -> `ci_build_validation_menu`
  -> `ci_prompt_validation_menu`
  -> `ci_normalize_selection`
  -> `ci_map_validation_option`
  -> `ci_run_validation_option`

Importante:
no hay un único camino feliz terminal sustentable más allá de ese punto sin fijar una opción concreta del menú.
El flujo real se bifurca según la selección del usuario.

### Ramas importantes

Ramas top-level confirmadas en `run_post_push_flow`:

- salida inmediata si `POST_PUSH_FLOW != "true"`
- salida inmediata si hay:
  - `DEVTOOLS_NONINTERACTIVE=1`
  - `CI=1|true`
  - `GITHUB_ACTIONS=1|true`
  - ausencia de TTY
- salida inmediata si `head` es:
  - `dev`
  - `staging`
  - `main`
- salida inmediata si la selección mapea a `skip`

Ramas de dispatch confirmadas en `ci_run_validation_option`:

- `gate`
- `native`
- `act`
- `compose`
- `k8s`
- `k8s_full`
- `start_minikube`
- `k9s`
- `help`
- `pr`
- `skip`
- `unknown`

Normalización especial observada:

- `rc=10` y `rc=11` se normalizan a éxito del orquestador (`return 0`)

### Side effects

Side effects observables confirmados:

- impresión de paneles y diagnósticos en stdout/stderr
- prompt interactivo por `gum choose` o `select` sobre `/dev/tty`
- redetección de comandos CI y reseteo previo de:
  - `NATIVE_CI_CMD`
  - `ACT_CI_CMD`
  - `COMPOSE_CI_CMD`
  - `K8S_HEADLESS_CMD`
  - `K8S_FULL_CMD`
- mutación de variables de shell:
  - `CI_GATE_PASSED`
  - `CI_OPT_*`
  - `CI_MENU_CHOICES`
- ejecución de procesos externos mediante:
  - `eval`
  - `run_cmd`
  - `ci_run_command_with_evidence`
- posible delegación a `bin/git-pr.sh` en la rama `pr`
- en el caller `git-promote local`, creación de log temporal en `/tmp`

No quedó confirmada persistencia contractual estable propia del flujo en disco.

### Inputs

Inputs formales del entrypoint central:

- `head`
- `base`

Inputs contextuales observados:

- `POST_PUSH_FLOW`
- `DEVTOOLS_NONINTERACTIVE`
- `CI`
- `GITHUB_ACTIONS`
- `PR_BASE_BRANCH`
- `DEVTOOLS_CI_NATIVE_CMD_OVERRIDE`
- `DEVTOOLS_ACP_NATIVE_DEVTOOLS_CHECKS`
- `REQUIRE_GATE_BEFORE_PR`
- `DEVTOOLS_ALLOW_PR_WITHOUT_GATE`

Inputs del entorno local detectado:

- existencia de TTY
- herramientas disponibles:
  - `task`
  - `gum`
  - `act`
  - `docker`
  - `kubectl`
  - `minikube`
  - `k9s`
- tareas detectables vía Taskfile
- selección interactiva del usuario en el menú

### Outputs

Outputs observados:

- código de salida del workflow
- salida textual de:
  - panel de entorno
  - panel diagnóstico
  - resumen de selección
  - contexto Task
  - ejecución o fallo de la rama elegida

Comportamiento de salida confirmado:

- retorna `0` en early-exit del orquestador
- retorna `0` en `skip`
- retorna `0` cuando la rama interna devuelve `10` o `11`
- fuera de eso, intenta propagar `rc`

Output adicional posible por rama:

- ejecución de comandos CI locales
- apertura de `k9s`
- ayuda contextual
- delegación a `bin/git-pr.sh`

### Preconditions

Precondiciones confirmadas para entrar desde `git-acp`:

- el push tuvo que ser exitoso

Precondiciones confirmadas para mostrar menú interactivo:

- `POST_PUSH_FLOW == "true"`
- no estar en modo no interactivo
- disponer de TTY
- no estar en `dev|staging|main`

Precondiciones observadas por rama:

- `native` requiere detección de comando CI nativo del proyecto
- `act` requiere `ACT_CI_CMD`
- `pr` requiere gate previo o bypass explícito, y además `bin/git-pr.sh`
- `start_minikube` y `k9s` dependen de tareas/comandos detectables
- `gate` depende de disponibilidad efectiva de comandos nativos y/o Act

### Error modes

Modos de fallo confirmados antes del reusable flow, en caller ACP:

- HEAD desacoplado
- push rechazado con rebase no resoluble
- push final no exitoso

Modos de fallo confirmados dentro del reusable flow:

- no se detecta comando nativo requerido
- falla ejecución de CI nativo
- falla ejecución de Act
- falla rama `k8s_full` con rc distinto de `0`, `130` o `143`
- PR abortado por gate no superado
- PR abortado por cancelación del usuario
- `bin/git-pr.sh` inexistente o fallando

Punto aún abierto:
no quedó completamente cerrada la propagación exacta de errores en todas las ramas que usan `run_cmd` sin manejo local explícito.

### Archivos / funciones involucradas

Archivos núcleo:

- `lib/ci-workflow.sh`
- `lib/ci/detection.sh`

Wrappers / callers:

- `bin/git-acp.sh`
- `bin/git-ci.sh`
- `bin/git-promote.sh`

Archivos de soporte directo:

- `lib/ci/ui.sh`
- `lib/ci/actions.sh`
- `lib/core/utils.sh`
- `lib/core/config.sh`

Funciones clave confirmadas:

- `run_post_push_flow`
- `ci_ensure_ui_fallbacks`
- `detect_ci_tools`
- `ci_render_validation_menu_header`
- `ci_build_validation_menu`
- `ci_prompt_validation_menu`
- `ci_normalize_selection`
- `ci_map_validation_option`
- `ci_run_validation_option`
- `ci_get_native_cmd`
- `ci_resolve_native_app_ci_cmd`
- `ci_print_task_context_evidence`
- `ci_is_skip_option`
- `do_create_pr_flow`

### Unknowns

Unknowns que siguen abiertos al cierre de discovery:

- comportamiento runtime real de cada rama del menú en entorno controlado
- propagación exacta de errores en ramas que llaman `run_cmd` sin chequeo local explícito
- detalle real del subflujo delegado a `bin/git-pr.sh`
- peso real de cada opción del menú en repos concretos distintos
- si `git-promote local` realmente obtiene una validación útil al redirigir stdout/stderr a log
- si la dependencia implícita de `git-ci.sh` respecto al bootstrap de `detect_ci_tools` debe considerarse contractual o sólo incidental

### Sospechas de legacy / compatibility seams

Sospechas sustentadas, todavía no conclusiones definitivas:

- el flujo ya no parece un simple “post-push ACP”; parece un workflow reusable que fue creciendo por acumulación de casos de uso
- `ci_ensure_ui_fallbacks` funciona como seam claro de compatibilidad cuando no está cargada la UI completa
- `lib/core/utils.sh` también contiene shims UI, lo que sugiere superposición defensiva
- `ci_resolve_native_app_ci_cmd` intenta varios layouts de proyecto, lo que sugiere compatibilidad con estructuras históricas o múltiples convenciones
- `git-ci.sh` depende de un default implícito de `POST_PUSH_FLOW` inyectado durante el bootstrap, no de un seteo explícito propio
- `git-promote.sh` reutiliza el workflow con redirección a log, lo que puede desalinear intención aparente vs comportamiento interactivo real
- el nombre del flujo puede estar quedándose corto frente a su rol actual

### Evidencia

Evidencia textual confirmada por lectura de código:

- `bin/git-acp.sh` llama `POST_PUSH_FLOW=true run_post_push_flow "$current_branch" "$base_branch"` tras push exitoso
- `bin/git-ci.sh` llama `run_post_push_flow "$CURRENT_BRANCH" "$BASE_BRANCH"`
- `bin/git-promote.sh` reutiliza `POST_PUSH_FLOW=true run_post_push_flow "${DEVTOOLS_PROMOTE_FROM_BRANCH:-}" "local"`
- `lib/ci-workflow.sh` define `run_post_push_flow`
- `run_post_push_flow` corta si `POST_PUSH_FLOW != "true"`
- `run_post_push_flow` corta en modo no interactivo o sin TTY
- `run_post_push_flow` corta silenciosamente para `dev|staging|main`
- `run_post_push_flow` redetecta herramientas con `detect_ci_tools`
- `ci_build_validation_menu` agrega opciones dinámicas más `Help`, `PR` y `Skip`
- `ci_run_validation_option` implementa ramas `gate/native/act/compose/k8s/k8s_full/start_minikube/k9s/help/pr/skip`
- `ci_run_validation_option` usa `10` y `11` como códigos de control normalizados luego a éxito

### Promotion gate to spec-first

No promover a `spec-first` hasta dejar explícitamente cerrados estos puntos:

- definir el contrato visible del flujo como workflow reusable, no sólo como detalle de `git-acp`
- fijar qué parte del flujo es común y qué parte depende de la opción elegida
- decidir qué ramas son contractuales para el usuario y cuáles son soporte operativo
- dejar explícito que:
  - el menú sólo aparece en modo interactivo
  - el flujo no corre sobre `dev|staging|main`
  - `skip` y ciertos códigos de control no deben considerarse fallo del orquestador
- documentar como drift observado:
  - reuse desde `git-ci`
  - reuse desde `git-promote local`
  - diferencia entre la expectativa textual de `git-ci` y la condición real del core
- dejar marcados como pendientes de validación:
  - rama `pr`
  - runtime real bajo TTY/no TTY
  - smoke sandboxeado con mocks
```

# Flow: git-acp.post-push

- maturity: spec-anchored
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
## 2. Spec-first

### Flow id
`git-acp.post-push`

### Resumen del contrato

`git-acp.post-push` es un workflow reusable de validación post-operación Git.

Su contrato visible no es “hacer CI siempre después de un push”, sino:

- ofrecer un menú de validación interactiva cuando el flujo está habilitado
- omitir ese menú de forma segura cuando el contexto no es apto
- construir las opciones del menú según herramientas realmente detectadas
- despachar la selección del usuario hacia una rama de validación o ayuda
- no tratar como fallo del orquestador las salidas de control como `skip`, `help`, `start_minikube` o `k9s`

Este flujo puede ser activado desde:

- `git-acp` después de un push exitoso
- `git-ci` como runner manual/simulador
- `git-promote local` como reutilización contextual

La intención contractual del flujo, en este stage, es:
dar una capa reusable de verificación/ayuda operativa posterior al trabajo Git, sin obligar siempre la ejecución de CI real y sin depender de un único caller.

### Code anchors

Anchors principales del contrato actual:

- `lib/ci-workflow.sh`
  - `run_post_push_flow`
  - `ci_build_validation_menu`
  - `ci_prompt_validation_menu`
  - `ci_map_validation_option`
  - `ci_run_validation_option`

- `lib/ci/detection.sh`
  - `detect_ci_tools`

- `bin/git-acp.sh`
  - `do_push`

- `bin/git-ci.sh`
  - runner manual del mismo workflow

- `bin/git-promote.sh`
  - reutilización del workflow tras `promote local`

- `lib/ci/ui.sh`
  - paneles y render de diagnóstico

- `lib/ci/actions.sh`
  - `do_create_pr_flow`

- `lib/core/utils.sh`
  - TTY, prompts, `run_cmd`, helpers UI

- `lib/core/config.sh`
  - soporte de activación por variables como `PR_BASE_BRANCH`

### Mapeo del camino feliz

Camino común contractual del flujo:

1. un caller invoca `run_post_push_flow(head, base)`
2. el workflow verifica si está habilitado para correr
3. el workflow valida si el contexto es interactivo y apto para mostrar menú
4. el workflow excluye ramas protegidas donde no debe aparecer menú
5. el workflow redetecta herramientas y comandos CI disponibles
6. el workflow renderiza paneles de estado/diagnóstico
7. el workflow construye el menú según detección real
8. el workflow recibe la selección del usuario
9. el workflow normaliza y mapea la selección a una intención interna
10. el workflow:
   - omite de forma limpia
   - muestra ayuda
   - ejecuta una validación
   - o delega a PR según la rama elegida
11. el workflow devuelve un exit code final normalizado

### Mapeo de ramas

Ramas contractuales visibles del flujo:

- salida temprana si el workflow no está habilitado
- salida temprana si el contexto es:
  - no interactivo
  - CI
  - GitHub Actions
  - sin TTY
- salida temprana si la rama actual es protegida:
  - `dev`
  - `staging`
  - `main`

Ramas de menú observables:

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

Reglas visibles que sí deben quedar contractuales desde `spec-first`:

- `skip` no debe contarse como fallo del flujo
- `help` no debe contarse como fallo del flujo
- códigos de control internos como `10` y `11` no deben escapar como fallo visible del orquestador
- el menú depende de detección real de tooling, no de una lista fija incondicional
- `pr` pertenece al flujo actual como rama observable, aunque su implementación profunda viva en otro archivo

### Notas de drift

Drift ya observado entre intención aparente y código real:

- el nombre `git-acp.post-push` queda corto:
  el flujo ya no es exclusivo de `git-acp`; es reusable

- `bin/git-ci.sh` sugiere que el menú “normalmente” aparece en `feature/**`,
  pero el core real no modela eso así;
  el core sólo excluye `dev|staging|main`

- `git-promote local` lo reutiliza como “verificación de entorno”,
  pero el workflow compartido sigue exponiendo ramas como `PR`, `Help` y `Skip`

- hay ramas con manejo explícito de `rc` y otras que delegan más al comportamiento de `run_cmd`,
  así que la semántica de fallo todavía no está completamente homogénea

### Boundaries

Pertenece a este flujo:

- activación del workflow reusable
- guards de habilitación / TTY / no interactivo / rama protegida
- detección de tooling que define el menú
- construcción del menú
- selección, normalización y mapeo
- dispatch a ramas internas del menú
- normalización final del exit code del orquestador

No pertenece completamente a este flujo:

- la lógica completa de push de `git-acp`
- la lógica completa de `git-promote`
- la implementación completa de `bin/git-pr.sh`
- la semántica profunda de cada comando Task detectado
- la lógica completa de Docker/K8s/Act/minikube/k9s fuera de este dispatcher

Flujos vecinos que tocan este uno:

- `git-acp.push-success`
- `git-ci.manual-run`
- `git-promote.to-local`
- `git-acp.pr-create`

### Seams sospechosos de legacy

Seams de compatibilidad o tolerancia observados:

- `ci_ensure_ui_fallbacks` como fallback defensivo de UI
- presencia simultánea de shims UI en `ci-workflow.sh` y `lib/core/utils.sh`
- resolución múltiple de comandos nativos del proyecto en `ci_resolve_native_app_ci_cmd`
- dependencia implícita de `git-ci.sh` respecto al bootstrap que ya ejecutó `detect_ci_tools`
- reutilización de `run_post_push_flow` desde `git-promote local` bajo redirección de salida
- coexistencia de ramas claramente operativas con ramas de ayuda/control (`help`, `skip`, `k9s`, `start_minikube`)

En `spec-first` estos seams quedan reconocidos, pero todavía no se declaran como deprecados.

### Estado de validación

Validado con buena confianza por lectura de código:

- entrypoint funcional central
- callers reales
- guards principales
- construcción dinámica de menú
- mapeo de ramas
- normalización general del `rc`

Validado sólo parcialmente:

- comportamiento real de cada rama cuando ejecuta comandos externos
- propagación exacta de ciertos errores en ramas con `run_cmd`
- utilidad real del reuse desde `git-promote local` bajo no-TTY efectivo
- subflujo completo de `pr`

Estado actual de testeabilidad:

- ya se pueden escribir tests Bats estáticos sobre:
  - existencia del flow
  - callers
  - entrypoint
  - guards principales
  - ramas y normalización de códigos
- todavía falta validación sandboxeada/mockeada para ramas ejecutables

### Notas de seguridad para refactor

No se debe romper en refactors futuros:

- la existencia de un único entrypoint reusable (`run_post_push_flow`)
- la omisión segura en contextos no interactivos
- la exclusión de `dev|staging|main`
- la construcción dinámica del menú según tooling detectado
- la separación entre:
  - selección visible del usuario
  - mapeo interno
  - dispatch de ejecución
- la normalización de `skip` y códigos de control como no-fallo del orquestador
- la posibilidad de invocación desde más de un caller

Tampoco debería asumirse que:

- este flujo sólo existe para `git-acp`
- siempre habrá TTY
- siempre habrá tooling CI detectado
- la rama `pr` equivale a “crear PR siempre” sin gates ni validaciones previas

### Criterio de salida para promover a spec-as-source

Antes de promover a `spec-as-source`, debería quedar resuelto:

- definir el contrato canónico exacto de qué ramas del menú son obligatorias y cuáles son soporte operativo
- fijar con más precisión la semántica visible de éxito/fallo por rama
- validar con Bats al menos:
  - entrypoint y callers
  - guards de activación
  - normalización de `skip/help/10/11`
  - presencia de ramas contractuales mínimas
- hacer al menos una validación sandboxeada o mockeada del flujo interactivo
- decidir cómo documentar contractualmente la rama `pr`:
  - como parte del flujo
  - o como delegación explícita a flujo vecino
- dejar registradas las notas de drift aceptadas frente al código actual

## 3. Spec-anchored

### Flow id
`git-acp.post-push`

### Resumen del contrato

El flujo `git-acp.post-push` es un workflow reusable de validación/ayuda operativa
que puede ser invocado desde más de un caller del repo.

En el codebase actual, su contrato observable queda anclado así:

- recibe una rama origen (`head`) y una rama base (`base`)
- sólo actúa si el flujo está habilitado
- omite el menú si el contexto no es interactivo o si la rama es protegida
- detecta tooling real disponible antes de construir el menú
- ofrece opciones visibles según esa detección, más ramas de ayuda/control
- normaliza la selección del usuario antes de ejecutar la rama elegida
- despacha a una rama interna del workflow o delega a un flujo vecino
- no trata `skip`, `help` ni ciertos códigos internos de control como fallo del orquestador

Este contrato no describe todavía la semántica profunda de todos los subcomandos
externos que el flujo puede ejecutar, pero sí amarra el comportamiento visible del
dispatcher y sus decisiones principales al código actual.

### Code anchors

Anchors principales del contrato hacia el codebase actual:

- `lib/ci-workflow.sh`
  - `run_post_push_flow`
  - `ci_ensure_ui_fallbacks`
  - `ci_get_native_cmd`
  - `ci_acp_native_include_devtools_checks`
  - `ci_resolve_native_app_ci_cmd`
  - `ci_print_task_context_evidence`
  - `ci_normalize_selection`
  - `ci_map_validation_option`
  - `ci_build_validation_menu`
  - `ci_render_validation_menu_header`
  - `ci_prompt_validation_menu`
  - `ci_is_skip_option`
  - `ci_run_validation_option`

- `lib/ci/detection.sh`
  - `detect_ci_tools`

- `lib/ci/ui.sh`
  - `render_env_status_panel`
  - `render_ci_diagnostic_panel`

- `lib/ci/actions.sh`
  - `do_create_pr_flow`

- `lib/core/utils.sh`
  - `is_tty`
  - `ask_yes_no`
  - `run_cmd`

- `bin/git-acp.sh`
  - `do_push`

- `bin/git-ci.sh`
  - runner manual del flujo reusable

- `bin/git-promote.sh`
  - reutilización del flujo en `promote local`

- `lib/core/config.sh`
  - soporte de variables como `PR_BASE_BRANCH`

### Mapeo del camino feliz

Camino común anclado al código actual:

1. `bin/git-acp.sh::do_push`
   - hace push de la rama actual
   - si el push es exitoso, invoca:
     `POST_PUSH_FLOW=true run_post_push_flow "$current_branch" "$base_branch"`

2. `lib/ci-workflow.sh::run_post_push_flow`
   - recibe `head` y `base`
   - asegura fallbacks UI con `ci_ensure_ui_fallbacks`
   - asegura disponibilidad mínima de `is_tty`

3. `lib/ci-workflow.sh::run_post_push_flow`
   - aplica guards:
     - `POST_PUSH_FLOW == "true"`
     - no modo no interactivo / CI / GitHub Actions
     - hay TTY
     - la rama no es `dev|staging|main`

4. `lib/ci-workflow.sh::run_post_push_flow`
   - hace `unset` de comandos detectados
   - reejecuta `detect_ci_tools`
   - reinicia `CI_GATE_PASSED=0`

5. `lib/ci-workflow.sh::ci_render_validation_menu_header`
   - renderiza panel de entorno
   - renderiza panel diagnóstico si existe

6. `lib/ci-workflow.sh::ci_build_validation_menu`
   - construye las opciones visibles del menú
   - usa tooling detectado para decidir qué opciones mostrar
   - siempre añade `Help`, `PR` y `Skip`

7. `lib/ci-workflow.sh::ci_prompt_validation_menu`
   - muestra el menú interactivo
   - usa `gum choose` si está disponible
   - si no, usa `select` sobre `/dev/tty`

8. `lib/ci-workflow.sh::run_post_push_flow`
   - normaliza la selección con `ci_normalize_selection`
   - la mapea con `ci_map_validation_option`
   - imprime resumen de selección y contexto Task

9. `lib/ci-workflow.sh::run_post_push_flow`
   - si la selección equivale a `skip`, termina con éxito visible

10. `lib/ci-workflow.sh::ci_run_validation_option`
    - ejecuta la rama correspondiente:
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

11. `lib/ci-workflow.sh::run_post_push_flow`
    - normaliza `rc=10` y `rc=11` a éxito del orquestador
    - propaga otros códigos de salida

Importante:
este mapeo describe el camino común contractual del dispatcher.
No fija todavía un único camino terminal, porque el flujo real depende de la
opción elegida por el usuario.

### Mapeo de ramas

Ramas top-level del orquestador:

- rama `disabled`
  - vive en `run_post_push_flow`
  - si `POST_PUSH_FLOW != "true"`, retorna `0`

- rama `non-interactive`
  - vive en `run_post_push_flow`
  - si existe:
    - `DEVTOOLS_NONINTERACTIVE=1`
    - `CI=1|true`
    - `GITHUB_ACTIONS=1|true`
    - no TTY
  - informa y retorna `0`

- rama `protected-branch`
  - vive en `run_post_push_flow`
  - si `head` es `dev|staging|main`, retorna `0`

- rama `skip-before-dispatch`
  - vive en `run_post_push_flow`
  - si `ci_is_skip_option "$selected"` da verdadero, retorna `0`

Ramas del dispatcher interno en `ci_run_validation_option`:

- `gate`
  - corre CI nativo y Act
  - puede marcar `CI_GATE_PASSED=1`
  - puede ofrecer creación de PR

- `native`
  - resuelve comando CI nativo de app
  - puede añadir checks devtools si corresponde

- `act`
  - corre el workflow local basado en Act

- `compose`
  - ejecuta el chequeo compose detectado

- `k8s`
  - ejecuta pipeline headless local

- `k8s_full`
  - ejecuta pipeline full interactivo
  - trata `0`, `130` y `143` como salidas aceptables

- `start_minikube`
  - ejecuta `task cluster:up`
  - retorna `11`

- `k9s`
  - ejecuta `task ui:local` o `k9s`
  - retorna `11`

- `help`
  - muestra ayuda
  - retorna `11`

- `pr`
  - puede exigir gate previo
  - delega a `do_create_pr_flow "$head" "$base"`

- `skip`
  - retorna `10`

- `unknown`
  - avisa y retorna `11`

Notas ancladas al código actual:

- el menú visible depende de tooling detectado,
  pero `Help`, `PR` y `Skip` se añaden siempre
- `skip` puede resolverse antes del dispatch final
- `help`, `start_minikube`, `k9s` y `unknown`
  usan códigos de control luego normalizados por el orquestador

### Notas de drift

Drift ya observable entre spec intencional y codebase actual:

- el nombre del flujo sugiere algo posterior a `git-acp`,
  pero el código real lo reutiliza también desde:
  - `bin/git-ci.sh`
  - `bin/git-promote.sh`

- `bin/git-ci.sh` comunica que el menú “normalmente” aparece en `feature/**`,
  pero el core real sólo excluye:
  - `dev`
  - `staging`
  - `main`

- `bin/git-promote.sh` lo presenta como verificación de entorno local,
  pero el menú compartido sigue incluyendo opciones como:
  - `PR`
  - `Help`
  - `Skip`

- existe doble construcción del menú:
  - `run_post_push_flow` llama `ci_build_validation_menu`
  - `ci_prompt_validation_menu` vuelve a llamar `ci_build_validation_menu`
  Esto hoy parece funcional/defensivo, pero no está claro si es parte intencional
  del contrato o sólo una consecuencia del diseño actual.

- la semántica de fallo no está completamente homogénea:
  algunas ramas chequean `rc` explícitamente
  y otras dependen más de la ejecución de `run_cmd`

- `git-ci.sh` depende de una habilitación implícita del flujo vía bootstrap y
  detección inicial, no de un seteo explícito propio equivalente al de ACP o promote

### Boundaries

Pertenece a este flujo:

- el dispatcher reusable `run_post_push_flow`
- guards de habilitación e interactividad
- redetección de tooling CI
- construcción del menú
- selección, normalización y mapeo
- dispatch a ramas del menú
- normalización final del exit code del orquestador

No pertenece completamente a este flujo:

- el push completo de `git-acp`
- el flujo completo de `git-promote`
- el flujo completo de creación de PR en `bin/git-pr.sh`
- la implementación completa de:
  - Docker
  - Act
  - Kubernetes
  - Minikube
  - K9s
  - Task targets concretos

Flujos vecinos explícitos:

- `git-acp.push-success`
- `git-ci.manual-run`
- `git-promote.to-local`
- `git-acp.pr-create`

La rama `pr` pertenece a este flujo como rama observable del menú,
pero su implementación profunda ya entra en un flujo vecino.

### Seams sospechosos de legacy

Seams anclados al codebase actual:

- `ci_ensure_ui_fallbacks`
  - seam defensivo cuando no se cargó la capa de UI completa

- coexistencia de fallbacks UI en:
  - `lib/ci-workflow.sh`
  - `lib/core/utils.sh`

- `ci_resolve_native_app_ci_cmd`
  - seam de compatibilidad con múltiples layouts de proyecto / Taskfiles

- `detect_ci_tools`
  - seam de compatibilidad que intenta varias convenciones de detección

- `git-ci.sh`
  - seam de reutilización manual que no replica exactamente la activación explícita
    de otros callers

- `git-promote.sh`
  - seam de reutilización contextual de un workflow originalmente nombrado como post-push

- uso de códigos internos `10` y `11`
  - seam de protocolo interno entre dispatcher y orquestador

A esta altura esos seams deben considerarse existentes y relevantes para el flujo,
aunque todavía no estén clasificados formalmente como deuda o legacy a deprecar.

### Estado de validación

Ya validado con buena confianza por lectura de código:

- entrypoint funcional central
- callers reales
- guards principales
- redetección de tooling
- construcción dinámica del menú
- normalización de selección
- ramas observables del dispatcher
- normalización de `10` y `11` a éxito del orquestador

Validado sólo parcialmente:

- comportamiento runtime real bajo TTY/no TTY
- propagación exacta de errores en todas las ramas que usan `run_cmd`
- utilidad real del reuse desde `git-promote local`
- rama `pr` y su delegación completa a `bin/git-pr.sh`

Testeable desde ya con Bats estático:

- existencia del flow y del entrypoint
- callers que convergen en `run_post_push_flow`
- guards top-level
- presencia de ramas contractuales mínimas
- normalización de `skip/help/10/11`

Aún pendiente para promoción final:

- smoke sandboxeado o mockeado del menú
- validación controlada de al menos una rama segura del dispatcher

### Notas de seguridad para refactor

No se debe romper:

- la centralidad de `run_post_push_flow` como entrypoint reusable
- la omisión segura en contextos no interactivos
- la exclusión de `dev|staging|main`
- la construcción dinámica del menú según detección real
- la existencia de una fase explícita de:
  - selección
  - normalización
  - mapeo
  - dispatch
- la normalización de `skip` y códigos de control como no-fallo del orquestador
- la posibilidad de que más de un caller invoque el mismo workflow

No debe asumirse en refactors futuros:

- que el flujo sólo lo usa `git-acp`
- que siempre habrá TTY
- que siempre habrá comandos CI detectados
- que la rama `pr` es autónoma y no delega
- que `Help`, `K9s`, `start_minikube` o `Skip` son meros detalles sin impacto contractual

Refactor sensible:

- cualquier cambio que convierta `10/11` en errores visibles
- cualquier cambio que haga fijo un menú que hoy es dinámico
- cualquier cambio que mezcle otra vez caller-specific logic dentro del core reusable
- cualquier cambio que oculte o elimine guards top-level sin actualizar la spec

### Criterio de salida para promover a spec-as-source

Antes de promover a `spec-as-source`, todavía debería quedar resuelto:

- fijar el contrato canónico exacto de qué ramas son obligatorias para el flujo
  y cuáles son soporte operativo o tolerancia histórica

- definir de forma autoritativa la semántica visible de éxito/fallo del orquestador

- decidir cómo quedará contractualizada la rama `pr`:
  - rama propia del flujo
  - o delegación explícita a flujo vecino

- agregar tests Bats mínimos que cubran, al menos:
  - entrypoint central
  - callers reales
  - guards top-level
  - exclusión de ramas protegidas
  - ramas visibles mínimas del menú
  - normalización de `skip`, `help`, `10` y `11`

- realizar una validación controlada o mockeada de runtime
  para confirmar el flujo interactivo sin tocar el workspace real

- registrar explícitamente como drift aceptado o no aceptado:
  - reuse desde `git-ci`
  - reuse desde `git-promote local`
  - dependencia implícita de activación en `git-ci`
  - exposición de `PR` dentro de reuse contexts no necesariamente orientados a PR
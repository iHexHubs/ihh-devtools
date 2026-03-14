# Plantilla: spec-as-source

## Propósito

Usar el spec anclado como fuente de verdad para validar y gobernar el trabajo posterior del flujo `git-acp-devbox`, sin dejar que tolerancias accidentales del código vuelvan a mandar.

## Secciones

### Flow id
`git-acp-devbox`

### Spec de referencia
- La entrada visible del flujo es `git acp "<texto_aquí>"` dentro de una sesión válida de `devbox` en cualquier subdirectorio del repo `/webapps/ihh-devtools`.
- `"<texto_aquí>"` es obligatorio y debe actuar como mensaje principal del operador.
- Antes de commit o push deben ejecutarse las verificaciones y decisiones operativas propias del repo.
- No debe existir ningún side effect persistente antes de `check_superrepo_guard`.
- Debe existir simulación segura sin commit ni push efectivos.
- El cierre observable del flujo puede validarse por señal visible compuesta; no requiere marcador terminal único.
- La validación obligatoria del flujo completo debe existir en Bats.

### Partes del código que ya cumplen
- La entrada visible runtime sigue aterrizando en el flujo local del repo por `alias.acp` efímero y wrapper inline en `devbox.json`.
- El entrypoint local del flujo sigue siendo `bin/git-acp.sh`.
- El flujo valida contexto Git utilizable antes de continuar.
- `--dry-run` sigue evitando commit y push efectivos y deja una salida visible de simulación.
- El flujo puede ejecutarse desde cualquier subdirectorio del repo porque resuelve la raíz con `git rev-parse --show-toplevel`.
- El cierre visible compuesto ya puede sostenerse con señales observables del banner, la simulación, el progreso final y, cuando aplica, el tramo post-push.

### Gaps a cerrar
- Confirmar por Bats la entrada del flujo completo bajo contexto controlado del repo, no solo el subflujo `post-push`.
- Mantener explícito que otras ramas del post-push distintas de `skip` siguen fuera de la validación mínima del flujo completo.
- Mantener bajo observación la estabilidad futura de la inyección runtime de `alias.acp` en sesiones reales de `devbox`.

### Cambios necesarios derivados del spec
- Rechazar la ejecución si no se provee mensaje CLI válido.
- Eliminar la tolerancia actual del modo interactivo como sustituto del mensaje obligatorio.
- Diferir cualquier side effect persistente de `lib/core/config.sh` hasta después de `check_superrepo_guard`.
- Derivar validación Bats mínima del flujo completo:
  - rechazo sin mensaje
  - `--dry-run` sin commit ni push
  - ejecución válida desde subdirectorio
  - cierre visible compuesto suficiente

### Cambios explícitamente fuera de alcance
- Rediseñar el flujo completo de `git-acp`.
- Limpiar o eliminar toda la compatibilidad `LEGACY_` o `Compat`.
- Redefinir flags accidentales como interfaz contractual adicional.
- Reescribir el menú completo de `post-push`.
- Convertir la señal compuesta de cierre en un marcador terminal único por obligación técnica.

### Superficies principales de intervención
- Principal:
  - `bin/git-acp.sh`
  - `lib/core/config.sh`
  - `tests/03_git_acp_devbox.bats`
- Secundaria:
  - `lib/core/utils.sh`
  - `lib/ssh-ident.sh`
  - `devbox.json`
- Riesgo alto:
  - `lib/ci-workflow.sh`
  - seams de dispatch y compatibilidad de config

### Seams, compatibilidades y zonas de riesgo
- `DEVTOOLS_DISPATCH_DONE` sigue siendo seam de redispatch entre entrada visible y script local.
- `LEGACY_VENDOR_CONFIG` mantiene compatibilidad entre config contractual y fallback heredado.
- `feature/dev-update` sigue siendo compatibilidad de rama deprecada.
- `ci_ensure_ui_fallbacks` y `run_cmd` siguen siendo seams de tolerancia del post-push.
- `DEVTOOLS_WIZARD_MODE` sigue alterando el camino de carga de config.

### Validación obligatoria
- El flujo completo rechaza ejecución sin mensaje.
- El flujo completo permite `--dry-run` sin commit ni push.
- El flujo completo puede invocarse desde un subdirectorio del repo.
- La salida del flujo seguro deja evidencia visible suficiente del cierre compuesto.
- El subflujo `post-push` validado previamente sigue cubriendo al menos la rama `skip`.

### Acceptance candidates listos para ejecución
- `bin/git-acp.sh` falla con salida visible de error cuando no recibe mensaje.
- `bin/git-acp.sh --dry-run "<texto>"` no mueve `HEAD` ni publica cambios.
- `bin/git-acp.sh --dry-run "<texto>"` funciona desde un subdirectorio del repo.
- El flujo seguro expone banner de entrada, marca de simulación y salida visible de progreso.
- `run_post_push_flow` conserva la rama `skip` como cierre visible exitoso del tramo post-push.

### Criterio de cumplimiento
- Cumplimiento mínimo:
  - el mensaje es obligatorio
  - no hay side effects persistentes antes del guard
  - `--dry-run` no comitea ni pushea
  - el flujo funciona desde cualquier subdirectorio del repo
  - existe validación Bats del flujo completo
- Cumplimiento deseable:
  - la señal visible compuesta del cierre queda cubierta por pruebas del flujo seguro y del tramo `skip`
  - el seam runtime de `devbox` conserva evidencia observada suficiente en documentación y tests controlados
- Falsa apariencia de cumplimiento:
  - probar solo `post-push`
  - probar solo el script local sin cubrir rechazo sin mensaje
  - asumir que banner o `RC=0` aislados equivalen a cierre contractual completo

### Criterio de terminado
- El código queda alineado con mensaje obligatorio y sin side effects persistentes antes del guard.
- El Bats del flujo completo existe y cubre la validación mínima definida por el spec.
- Los unknowns restantes quedan explícitos y recortados.
- No se introducen cambios laterales fuera del scope del contrato.

### Unknowns
- No bloquean:
  - otras ramas del post-push no cubiertas todavía
  - peso real actual de piezas `Compat` / `LEGACY_`
- Condicionan observación futura:
  - estabilidad del alias runtime inyectado por `devbox` en sesiones reales posteriores
- No deben cerrarse por intuición:
  - alcance vivo de ramas post-push distintas de `skip`
  - necesidad operativa actual de cada seam heredado

### Evidencia
- Contrato visible: `specs/flows/02-git-acp.post-push/02-spec-first.md`
- Anclaje previo: `specs/flows/02-git-acp.post-push/01-discovery.md`
- Entrada runtime y alias efímero: `devbox.json`
- Entry local y parseo del flujo: `bin/git-acp.sh`
- Guard y cierre visible: `lib/core/utils.sh`
- Config contractual y side effects diferidos: `lib/core/config.sh`, `lib/core/contract.sh`
- Identidad y remotos: `lib/ssh-ident.sh`
- Post-push validado: `lib/ci-workflow.sh`, `tests/02_git_acp_post_push.bats`
- Validación mínima del flujo completo: `tests/03_git_acp_devbox.bats`

### Criterio de salida para ejecutar o delegar implementación
- Trabajo autorizado por el spec:
  - sostener mensaje obligatorio
  - sostener ausencia de side effects persistentes antes del guard
  - sostener `--dry-run` seguro
  - sostener ejecución válida desde subdirectorio
  - sostener validación Bats del flujo completo
- Trabajo prohibido o fuera de alcance:
  - rediseños generales
  - limpiezas amplias de compatibilidad
  - ampliación de interfaz visible no decidida por negocio
- Validaciones obligatorias:
  - `tests/03_git_acp_devbox.bats`
  - cobertura vigente de `tests/02_git_acp_post_push.bats`
- Unknowns que no bloquean:
  - ramas no críticas del post-push
  - peso real de `LEGACY_`
- Unknowns que sí obligan a vigilancia:
  - estabilidad futura del seam runtime de `devbox`

Formato obligatorio de trabajo durante todo spec-as-source:

Estado actual
- Bloque actual: inicialización para transición a spec-as-source
- Objetivo del bloque: dejar el flujo alineado con el contrato decidido y con validación mínima derivada del spec
- Pregunta operativa que estamos resolviendo:
  qué trabajo quedó ya autorizado, qué validación mínima sostiene cumplimiento y qué partes siguen fuera de scope

Trabajo ya claramente derivado del spec
- mensaje obligatorio
- side effects persistentes solo después del guard
- `--dry-run` seguro
- aceptación desde subdirectorio
- Bats mínimo del flujo completo

Puntos aún parciales o abiertos
- cobertura profunda del post-push más allá de `skip`
- estabilidad futura del alias runtime inyectado
- peso real de seams heredados

Riesgos de desviación o scope creep
- reintroducir modo interactivo para suplir mensaje
- volver a ejecutar side effects persistentes durante `source lib/core/config.sh`
- tomar el subflujo `post-push` como sustituto del flujo completo

Qué podemos dejar fuera por ahora
- expansión completa del menú post-push
- limpieza general de legacy
- endurecimientos no derivados del spec aprobado

Condición para pasar al siguiente bloque
- esta plantilla ya puede gobernar ejecución o delegación posterior sin reabrir el contrato

Regla final:
Spec-as-source solo queda bien hecho si esta plantilla permite responder con claridad a la pregunta:
“¿Qué trabajo está realmente autorizado por el spec, qué debe validarse para afirmar cumplimiento y qué no debemos tocar para no perder el marco?”

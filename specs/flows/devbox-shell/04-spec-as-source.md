# Spec as Source — `devbox-shell`

## Flow id
`devbox-shell`

## Autoridad vigente
- Autoridad funcional aprobada: `specs/flows/devbox-shell/02-spec-first.md`.
- Autoridad aprobada de anclaje a la realidad actual del código: `specs/flows/devbox-shell/03-spec-anchored.md`.
- Autoridad observacional de apoyo: `specs/flows/devbox-shell/01-discovery.md`.
- Evidencia del repo usada solo como apoyo: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh`, `lib/core/config.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`, `devtools.repo.yaml`.
- Este artefacto no redefine el contrato desde el código actual y no mezcla implementation, evaluation ni review.

## Reserva metodológica sobre el schema visible
- El schema visible en `~/.codex/docs/spec-as-source-output-schema.md` está truncado después de `# Spec as Source — <flow-id>` y `## Flow id`.
- Por esa razón, la estructura restante de este artefacto se apoya en el checkpoint aprobado, `spec-as-source-checkpoint-spec.md`, `spec-as-source-artifact-creation-policy.md` y las constituciones de supervisor/worker de la fase.
- Esta reserva no rebaja la autoridad del spec ni autoriza mezcla de fases; solo explicita la base metodológica usada para completar la estructura restante del documento.

## Pregunta operativa de la fase
- Qué trabajo está realmente autorizado por el spec aprobado.
- Qué ya cumple y no debe tocarse.
- Qué gaps deben cerrarse para que el spec gobierne trabajo posterior.
- Qué validación será obligatoria para afirmar cumplimiento real.
- Bajo qué condiciones podrá empezar implementation sin renegociar el sentido del spec aprobado.

## Contrato Aprobado
- `devbox shell` debe dejar una sesión utilizable para operar este repo.
- La preparación efímera del entorno forma parte del núcleo contractual.
- El flujo debe comunicar de forma visible si la sesión quedó `ready` o degradada.
- La configuración guiada con side effects persistentes puede existir, pero no constituye el éxito base universal del flujo.
- El flujo debe seguir siendo repo-céntrico.
- Prompt exacto, menú exacto, texto exacto, chequeo remoto de versión y `submodule sync/update` best-effort de `.devtools` no forman parte de la garantía contractual central.

## Realidad Anclada
- El repo controla el flujo desde `devbox.json:shell.init_hook`, materializado en `.devbox/gen/scripts/.hooks.sh`.
- La cadena principal sigue hacia `bin/setup-wizard.sh`, que carga `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/config.sh` y luego pasos del wizard.
- El hook prepara entorno efímero mediante `PATH`, aliases Git en memoria y variables de sesión.
- La rama estricta usa el resultado del wizard para decidir si habilita la ruta lista/contextualizada.
- La rama no estricta puede conservar `DEVBOX_SESSION_READY=1` aunque el wizard falle.
- `lib/core/config.sh` puede aplicar una mutación persistente temprana sobre Git global.
- `detect_workspace_root` puede desplazar la responsabilidad efectiva hacia un superproyecto.

## Ya Cumple
- El flujo tiene entrypoint y dispatcher chain localizados con evidencia suficiente.
- Existe preparación efímera del entorno como responsabilidad real del hook.
- El wizard funciona como gatekeeper explícito entre validación y setup guiado.
- La rama estricta ya comunica degradación visible cuando no se satisface la verificación requerida.
- Version check y `submodule sync/update` ya operan como best-effort y no dominan el criterio contractual central.
- La capacidad de setup guiado persistente existe como capacidad adicional sin necesidad de elevarla a éxito base universal.

## Gap a Cerrar
- La señalización `ready/degradada` no es honesta de forma universal en la rama no estricta.
- La frontera entre verificación/preparación efímera y mutación persistente no está suficientemente preservada.
- La semántica repo-céntrica queda tensionada por la resolución actual de root hacia superproyecto.
- Los seams entre hook hardcodeado y resolución contractual deben seguir visibles para no rebajar el spec por inercia del código.

## Cambio Necesario
- Ajustar la lógica de readiness para que un fallo relevante del wizard no desemboque en una apariencia de sesión lista.
- Preservar la separación contractual entre preparación efímera y side effects persistentes, evitando mutación temprana en rutas de verificación.
- Alinear la resolución efectiva de root con el contrato repo-céntrico aprobado.
- Mantener fuera del criterio central de cumplimiento el prompt exacto, el menú exacto, el texto exacto, el version check y el `submodule sync/update` best-effort.

## Cambio Opcional
- Unificar el hook con la resolución contractual de `vendor_dir` y `profile_file`, aunque hoy coincidan para este repo.
- Endurecer el control de deriva entre `devbox.json` y `.hooks.sh` como artefacto generado.
- Mejorar UX, texto de mensajes, menú o prompt.
- Agregar instrumentación de diagnóstico adicional siempre que no se convierta en criterio contractual ni abra implementation colateral.

## Fuera de Alcance
- Reescribir el onboarding o el wizard completo.
- Convertir side effects persistentes en requisito universal de éxito del flujo.
- Redefinir el contrato para soportar workspaces o superproyectos como semántica aprobada.
- Refactors amplios de `lib/core/*` o `lib/wizard/*` no exigidos directamente por los gaps contractuales.
- Cambios de evaluation, review, tests finales del producto o implementation durante esta fase.

## Superficies de Cambio Autorizadas
- Superficie principal: `devbox.json` y `.devbox/gen/scripts/.hooks.sh`, por la semántica de entrada y señalización `ready/degradada`.
- Superficie principal: `bin/setup-wizard.sh`, por el acoplamiento entre root, verify-only y setup guiado.
- Superficie principal: `lib/core/config.sh`, por la mutación persistente temprana que tensiona el contrato.
- Superficie secundaria: `lib/core/git-ops.sh`, por `detect_workspace_root` y su impacto repo-céntrico.
- Superficie secundaria: `lib/core/contract.sh`, por la resolución contractual de `vendor_dir` y `profile_file`.
- Zonas de alto riesgo: `lib/wizard/step-03-config.sh` y `lib/wizard/step-04-profile.sh`, por concentrar mutaciones persistentes.
- Partes que no deberían tocarse salvo necesidad contractual demostrada: prompt, menú, copy exacto, version check y compatibilidad best-effort de submódulo.

## Validación Requerida
- Confirmar que la rama estricta y la no estricta comunican honestamente `ready` o degradada frente a fallo relevante del wizard.
- Confirmar que el camino mínimo sigue dejando una sesión utilizable del repo con preparación efímera del entorno.
- Confirmar que verify-only y validaciones tempranas no producen side effects persistentes sobre Git global/local, `.env`, `.git-acprc` o marker.
- Confirmar que la resolución efectiva de root, `vendor_dir` y `profile_file` respeta el repo objetivo y no rebaja el carácter repo-céntrico.
- Confirmar que version check y `submodule sync/update` best-effort no se convierten en criterio central de aceptación.

## Validación Útil pero No Requerida
- Observar el primer arranque interactivo real con credenciales GH/SSH válidas.
- Confirmar regeneración exacta de `.hooks.sh` a partir de `devbox.json`.
- Recolectar rc y copy exactos de runtime para documentación posterior.

## Criterio de Cumplimiento
- Cumplimiento mínimo:
  - la sesión resultante es utilizable para este repo;
  - la preparación efímera del entorno se conserva;
  - el flujo comunica honestamente `ready` o degradada en las ramas relevantes;
  - verify-only no muta configuración persistente;
  - la semántica repo-céntrica queda preservada.
- Cumplimiento deseable si difiere:
  - los seams entre contrato, hook y artefacto generado quedan acotados sin ampliar alcance;
  - la validación cubre de forma explícita ramas estricta, no estricta y verify-only.

## Falsa Apariencia de Cumplimiento
- Que la rama estricta se degrade correctamente pero la no estricta siga mostrando bienvenida como si todo hubiera quedado listo.
- Que verify-only o validaciones tempranas sigan tocando Git global/local aunque el flujo aparente ser solo de verificación.
- Que se validen helpers internos o textos de consola sin validar el comportamiento visible de readiness/degradación.
- Que el setup guiado persistente funcione y eso se use para esconder que el núcleo contractual sigue incumplido.
- Que se acepte comportamiento de superproyecto por conveniencia técnica sin aprobación explícita del contrato.

## Riesgo de Desviación
- Aceptar como suficiente la semántica actual de la rama no estricta por simple existencia del código.
- Convertir checks internos cómodos en prueba de cumplimiento real.
- Corregir readiness pero dejar viva la mutación persistente temprana.
- Rebajar el carácter repo-céntrico para acomodar `detect_workspace_root`.
- Elevar capacidades opcionales del wizard a trabajo necesario sin base en el spec aprobado.

## Riesgo de Scope Creep
- Aprovechar para reescribir el wizard completo.
- Abrir limpieza amplia de `lib/core/*` o `lib/wizard/*`.
- Meter mejoras de UX, prompt o copy como si fueran parte del cierre contractual.
- Reabrir la intención del flujo para workspaces/superproyectos sin autoridad explícita.
- Convertir seams incómodos en backlog de refactor amplio no requerido por el spec.

## Unknown
### No bloquea
- No se observó una corrida real de `devbox shell`; faltan rc y copy exactos de runtime.
- No se verificó regeneración actual exacta de `.hooks.sh`.
- Prompt exacto y UX exacta del menú no están observados y no forman núcleo contractual.

### Condiciona
- La experiencia exacta del primer arranque interactivo con credenciales reales GH/SSH.
- El efecto práctico de `detect_workspace_root` en un workspace anidado real.
- La reserva metodológica por schema visible truncado, que condiciona la verificación formal de estructura pero no impide usar checkpoint/policy/constituciones como base.

### Bloquea
- Ningún unknown adicional bloquea esta fase por sí mismo.

## Condiciones para pasar luego a Implementation
- Que implementation trate `02-spec-first.md` como autoridad funcional y `03-spec-anchored.md` como autoridad de mapeo actual al código.
- Que implementation se limite a cerrar los gaps clasificados aquí como necesarios.
- Que implementation no promueva cambios opcionales ni trabajo fuera de alcance por conveniencia.
- Que implementation preserve visibles los seams y riesgos aquí declarados.
- Que la validación obligatoria definida en este artefacto se trate como requisito de cumplimiento real, no como check decorativo.
- Que el trabajo posterior no renegocie el significado de `ready`, degradación, preparación efímera ni repo-centrismo del flujo.

## Criterio de Terminado de esta Fase
- Esta fase queda terminada cuando el trabajo posterior puede responder, sin renegociar autoridad:
  - qué está autorizado;
  - qué ya cumple y no debe tocarse;
  - qué gaps deben cerrarse;
  - qué es opcional;
  - qué está fuera de alcance;
  - qué validación es obligatoria;
  - qué cuenta como cumplimiento real;
  - qué sería falsa apariencia de cumplimiento;
  - y bajo qué condiciones puede empezar implementation.

# Plantilla: spec-as-source

## Propósito

Usar el spec anclado como fuente de verdad para guiar cambios, validación y criterio de terminado del flujo.

Actúa como coordinador metodológico estricto de la fase spec-as-source. No eres un agente que improvisa cambios “porque parecen correctos”, ni un refactorizador libre, ni un solucionador sin marco. Tu función es hacer que el contrato ya definido en spec-first y ya anclado en spec-anchored se convierta en la fuente operativa de todo el trabajo posterior sobre el flujo: qué se cambia, qué no se cambia, qué se valida, qué se considera cumplimiento y qué se considera desviación.

Debes trabajar con estas reglas:

1. Analiza un solo flujo a la vez.
2. No pierdas autoridad del spec: el spec manda sobre intuiciones del chat y sobre comportamientos accidentales del código actual.
3. No conviertas deseos vagos en trabajo implícito.
4. No propongas cambios fuera del alcance del spec.
5. No permitas que Codex implemente primero y justifique después.
6. No mezcles spec-as-source con discovery ni con redacción contractual desde cero.
7. No ignores divergencias detectadas en spec-anchored.
8. Distingue siempre entre:
   - contrato aprobado,
   - anclaje real en código,
   - gap que debe cerrarse,
   - cambio necesario,
   - cambio opcional,
   - validación necesaria,
   - riesgo de desviación,
   - trabajo fuera de scope.

Regla de persistencia de contexto de fase

Si en este hilo ya existe evidencia, contrato, mapa o decisión válida producida en la fase actual o en fases previas aprobadas, debes tratarla como contexto vigente.

No puedes afirmar que:
- no encuentras el proyecto,
- no ves el repo,
- no tienes suficiente contexto,
- o que debes reiniciar desde cero,

mientras exista trabajo válido ya consolidado en este mismo hilo, salvo que:
1. el usuario cambie explícitamente de repositorio o de flujo,
2. el entorno cambie de forma explícita,
3. falte una ruta o archivo puntual indispensable para una tarea nueva distinta del bloque actual.

Si ocurre uno de esos casos, debes decir:
- qué parte del contexto sigue vigente,
- qué parte puntual falta,
- y por qué eso no autoriza a reiniciar la fase completa.

Regla de rechazo de desvío de tarea o fase

Si aparece una petición que no pertenece al bloque actual o a la fase actual, no la ejecutes.

Primero debes responder:
- que esa petición no corresponde a la fase actual,
- en qué bloque estás,
- qué falta para cerrar el bloque,
- y que no cambiarás de fase o de tarea hasta cerrar la fase actual o recibir una instrucción explícita de abandonarla.

Regla de autoridad metodológica y de Codex

Durante esta fase, Codex es la fuente de inspección del repositorio y el chat es el coordinador metodológico.

No debes:
- sustituir la evidencia de Codex por suposiciones tuyas,
- volver a pedir al usuario archivos ya localizados por Codex,
- reiniciar la búsqueda del repo desde cero si Codex ya produjo hallazgos relevantes en este hilo,
- ni permitir que Codex cambie por su cuenta la fase, el alcance o la metodología.

Variante de persistencia para spec-as-source

Debes conservar como contexto vigente:
- el discovery aprobado,
- el spec-first aprobado,
- el spec-anchored aprobado,
- las divergencias ya identificadas,
- y la definición de qué trabajo está autorizado por el spec.

No puedes reabrir el contrato ni ampliar el scope por comodidad técnica o por detalles del código actual.

Variante de rechazo para spec-as-source

No aceptes mejoras colaterales, limpiezas generales, refactors oportunistas ni trabajo vecino al flujo si no están directamente justificados por el spec aprobado.

Variante de autoridad para spec-as-source

Codex puede aterrizar superficies de cambio, riesgos y validación, pero no puede ampliar el alcance, redefinir el criterio de cumplimiento ni implementar primero y justificar después.

Tu trabajo consiste en avanzar por bloques estrictos y solo promover al siguiente cuando el anterior tenga suficiente definición operativa.

Orden obligatorio de bloques:

- Bloque 1: Alinear insumos desde discovery, spec-first y spec-anchored
- Bloque 2: Derivar trabajo permitido directamente desde el spec
- Bloque 3: Delimitar estrategia de cambio y superficies afectadas
- Bloque 4: Derivar validación, acceptance y criterio de cumplimiento
- Bloque 5: Vigilar desviaciones, cambios fuera de scope y riesgos
- Bloque 6: Consolidar plan guiado por spec y criterio de terminado
- Bloque 7: Cierre con ficha final de spec-as-source

Rol del usuario en esta fase:

- valida que el spec siga siendo la autoridad del flujo;
- decide si una divergencia se corrige ahora o se difiere;
- decide si un cambio potencial queda dentro o fuera del alcance;
- aprueba el criterio de terminado y la forma de validación;
- decide si la fase está lo bastante cerrada para pasar a ejecución real.

Rol del chat en esta fase:

- administra el método;
- usa el spec como fuente de verdad;
- traduce el spec y el anclaje en trabajo permitido, validación y criterio de cumplimiento;
- usa a Codex solo para aterrizar impactos, superficies, riesgos y confirmaciones;
- impide deriva metodológica;
- impide que el código actual vuelva a gobernar por accidente;
- impide que se cuele trabajo extra no justificado por el spec.

Rol de Codex en esta fase:

- inspecciona el repo para confirmar dónde deben hacerse los cambios derivados del spec;
- identifica superficies concretas de modificación y validación;
- propone cómo verificar cumplimiento del spec sin salirse de alcance;
- detecta riesgos de impacto, zonas dispersas y posibles desviaciones;
- no redefine el contrato;
- no cambia el scope por su cuenta;
- no implementa antes de que el trabajo haya sido claramente derivado del spec;
- no decide la metodología.

Debes usar a Codex así:

- En Bloque 1 no le pidas todavía plan detallado ni implementación; primero fija autoridad y alcance.
- En Bloque 2 usa el Prompt 1.
- En Bloque 3 usa el Prompt 2.
- En Bloque 4 usa el Prompt 3.
- En Bloque 5 usa el Prompt 4.
- En Bloque 6 usa el Prompt 5.
- En Bloque 7 ya no abras nuevos frentes salvo contradicción crítica.

Prompts obligatorios para Codex:

Prompt 1: derivar trabajo permitido desde el spec

No implementes nada.
No edites nada.
No propongas refactors generales.
No escribas tests finales todavía.
No avances a otros bloques fuera del actual.

Estamos en la fase spec-as-source y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 2
Objetivo del bloque: derivar, directamente desde el spec aprobado, qué trabajo está permitido y qué gaps deben cerrarse en el código real.

Contexto ya establecido:
- Flow id: [flow-id]
- Discovery consolidado: [resumen]
- Spec-first consolidado: [resumen]
- Spec-anchored consolidado: [resumen]
- Divergencias detectadas: [lista]
- Superficies principales de cambio: [lista]

Quiero únicamente:

1. qué partes del código deben alinearse necesariamente con el spec
2. qué divergencias detectadas requieren trabajo real para cumplir el spec
3. qué partes del comportamiento actual ya cumplen y no deberían tocarse
4. qué cambios serían opcionales pero no necesarios para cumplir el spec
5. qué trabajo sería claramente fuera de scope aunque parezca cercano
6. qué dudas de alcance siguen abiertas

Restricciones:
- no diseñes todavía la solución detallada;
- no propongas mejoras colaterales;
- no inventes objetivos no escritos en el spec;
- si una divergencia depende de una pregunta abierta no resuelta, márcala como tal.

Tu respuesta debe distinguir entre:
- cambio necesario por spec,
- ya cumple,
- opcional,
- fuera de scope,
- pendiente por ambigüedad.

Prompt 2: estrategia de cambio y superficies afectadas

No implementes nada.
No edites nada.
No propongas refactors generales.
No escribas tests finales todavía.
No avances a otros bloques fuera del actual.

Estamos en la fase spec-as-source y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 3
Objetivo del bloque: delimitar la estrategia de cambio y las superficies afectadas, siempre derivadas del spec.

Contexto ya establecido:
- Flow id: [flow-id]
- Cláusulas del spec que requieren alineación: [lista]
- Divergencias reales detectadas: [lista]
- Superficies principales y secundarias desde spec-anchored: [lista]
- Seams o zonas de riesgo: [lista]

Quiero únicamente:

1. superficies principales que habría que tocar para alinear el código con el spec
2. superficies secundarias potencialmente afectadas
3. dependencias o zonas dispersas que aumentan el riesgo
4. orden lógico de intervención guiado por el spec
5. qué partes conviene no tocar para evitar salir de alcance
6. qué seams o compatibilidades heredadas condicionan la estrategia
7. riesgos principales de regresión o desalineación

Restricciones:
- no escribas todavía pasos de implementación detallados;
- no propongas rediseño del flujo;
- no uses “sería mejor” como criterio; el criterio es el spec;
- si una superficie parece tocable pero no necesaria, márcala como opcional o fuera de alcance.

Tu respuesta debe distinguir entre:
- superficie principal,
- superficie secundaria,
- riesgo alto,
- riesgo moderado,
- no tocar por ahora,
- dependiente de decisión abierta.

Prompt 3: validación, acceptance y criterio de cumplimiento

No implementes nada.
No edites nada.
No propongas refactors generales.
No escribas todavía los artefactos finales de test como resultado principal.
No avances a otros bloques fuera del actual.

Estamos en la fase spec-as-source y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 4
Objetivo del bloque: derivar la validación y el criterio de cumplimiento directamente desde el spec.

Contexto ya establecido:
- Flow id: [flow-id]
- Acceptance candidates desde spec-first: [lista]
- Mapa spec -> código desde spec-anchored: [resumen]
- Divergencias a cerrar: [lista]
- Superficies de cambio: [lista]

Quiero únicamente:

1. qué afirmaciones del spec deben validarse sí o sí
2. qué acceptance candidates ya están maduros para convertirse en validación concreta
3. qué validaciones deberían comprobar comportamiento observable
4. qué validaciones deberían comprobar que una divergencia quedó cerrada
5. qué partes del spec todavía no pueden validarse limpiamente por falta de claridad o de anclaje
6. qué evidencias permitirían decir que el flujo ya cumple el spec
7. qué falsa sensación de cumplimiento podría ocurrir si se valida solo una parte

Restricciones:
- no escribas todavía el test suite final como producto principal;
- no conviertas detalles internos de implementación en criterio de cumplimiento salvo que el spec lo exija;
- no declares cumplimiento sin evidencias observables;
- si una validación depende de un unknown, márcalo.

Tu respuesta debe distinguir entre:
- validación obligatoria,
- validación recomendable,
- validación aún inmadura,
- criterio claro de cumplimiento,
- riesgo de validación insuficiente.

Prompt 4: desviaciones, scope creep y riesgos

No implementes nada.
No edites nada.
No propongas refactors generales.
No escribas tests finales todavía.
No avances a otros bloques fuera del actual.

Estamos en la fase spec-as-source y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 5
Objetivo del bloque: detectar desviaciones posibles, scope creep y riesgos metodológicos o técnicos antes de ejecutar trabajo guiado por spec.

Contexto ya establecido:
- Flow id: [flow-id]
- Trabajo necesario derivado del spec: [lista]
- Trabajo opcional detectado: [lista]
- Validaciones obligatorias: [lista]
- Riesgos de superficies y seams: [lista]

Quiero únicamente:

1. posibles desviaciones respecto del spec que podrían colarse durante el trabajo
2. cambios tentadores pero fuera de scope
3. zonas donde el código actual podría arrastrar decisiones contrarias al spec
4. riesgos técnicos que harían parecer cumplido algo que no lo está
5. riesgos metodológicos de mezclar limpieza, refactor o mejoras laterales con cumplimiento del spec
6. controles prácticos para no perder la autoridad del spec
7. qué decisiones deben quedar explícitas antes de ejecutar cambios

Restricciones:
- no diseñes todavía la implementación;
- no uses esta sección para reabrir discovery ni reescribir el contrato;
- no escondas riesgos bajo frases vagas;
- si un riesgo depende de una ambigüedad contractual, dilo.

Tu respuesta debe distinguir entre:
- desviación probable,
- scope creep,
- riesgo técnico,
- riesgo metodológico,
- control preventivo,
- decisión pendiente.

Prompt 5: consolidación operativa y criterio de terminado

No implementes nada.
No edites nada.
No propongas refactors generales.
No avances a otros bloques fuera del actual.

Estamos en la fase spec-as-source y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 6
Objetivo del bloque: consolidar el trabajo guiado por spec, el criterio de cumplimiento y el criterio de terminado antes de ejecutar o delegar cambios.

Contexto ya establecido:
- Flow id: [flow-id]
- Trabajo necesario por spec: [lista]
- Superficies de cambio confirmadas: [lista]
- Validaciones obligatorias: [lista]
- Riesgos y controles: [lista]
- Unknowns aún abiertos: [lista]

Quiero únicamente:

1. resumen consolidado de qué debe cambiarse para cumplir el spec
2. resumen de qué no debe tocarse
3. criterio mínimo de cumplimiento del spec
4. criterio de terminado de la fase
5. unknowns que no bloquean avanzar
6. unknowns que sí bloquean avanzar
7. mínima aclaración necesaria si todavía no conviene ejecutar trabajo
8. condiciones para delegar implementación o validación sin perder autoridad del spec

Restricciones:
- no implementes;
- no conviertas un plan tentativo en trabajo aprobado si todavía hay bloqueos;
- no cierres la fase si el criterio de cumplimiento sigue ambiguo;
- si algo sigue dependiendo de interpretación, dilo claramente.

Tu respuesta debe distinguir entre:
- listo para ejecutar,
- listo con reservas,
- necesita aclaración menor,
- bloqueado por ambigüedad,
- bloqueado por riesgo o divergencia no resuelta.

Criterio de promoción entre bloques:

- No pases de Bloque 1 a Bloque 2 hasta tener discovery, spec-first y spec-anchored claramente resumidos y una pregunta operativa de cumplimiento.
- No pases de Bloque 2 a Bloque 3 hasta tener claro qué cambios son necesarios, cuáles no y qué queda fuera de alcance.
- No pases de Bloque 3 a Bloque 4 hasta tener superficies afectadas y estrategia de intervención razonablemente delimitadas.
- No pases de Bloque 4 a Bloque 5 hasta tener validaciones obligatorias y criterio preliminar de cumplimiento.
- No pases de Bloque 5 a Bloque 6 hasta tener riesgos, desviaciones y controles suficientemente explícitos.
- No pases de Bloque 6 a Bloque 7 hasta saber qué significa “cumplir el spec” y bajo qué condiciones el trabajo puede ejecutarse o delegarse sin perder el marco.

En Bloque 1 debes hacer esto antes de hablar con Codex:

1. Recuperar y resumir el discovery del flujo.
2. Recuperar y resumir el spec-first del flujo.
3. Recuperar y resumir el spec-anchored del flujo.
4. Separar claramente:
   - contrato aprobado,
   - partes ya sostenidas por el código,
   - divergencias que requieren acción,
   - unknowns abiertos.
5. Formular la pregunta operativa principal:
   qué debe hacerse, qué debe validarse y qué no debe tocarse para que el spec sea realmente la fuente.

Después de cada respuesta de Codex, debes actualizar esta plantilla y dejar explícito si cada sección está:
- operativamente clara,
- parcial,
- abierta,
- en conflicto,
- bloqueada.

Tu salida final de spec-as-source debe rellenar esta plantilla sin ejecutar cambios y dejando claro cómo el spec gobierna el trabajo posterior.

## Secciones

### Flow id
`git-acp-devbox`

Instrucción operativa:
Usa el mismo flow id heredado de discovery, spec-first y spec-anchored. No lo cambies salvo redefinición explícita del flujo.

**Contenido**
- Se mantiene el mismo flow id heredado de discovery, spec-first y spec-anchored.
- El flujo gobernado por esta fase sigue siendo la entrada visible `git acp "<texto_aquí>"` dentro de `devbox`, para el repo `ihh-devtools`.

**Estado:** operativamente clara

### Spec de referencia
Qué parte del contrato aprobado gobierna esta fase.

Instrucción operativa:
Resume la intención, el contrato visible, los invariants, los failure modes y los acceptance candidates relevantes. No reescribas toda la historia del flujo; trae solo la parte del spec que debe gobernar el trabajo posterior.

**Contenido**
- `git acp "<texto_aquí>"` debe funcionar como entrada visible al ACP local del repo dentro de `devbox`.
- `"<texto_aquí>"` es obligatorio y debe tratarse como mensaje principal del operador.
- Antes de commit o push deben ejecutarse las verificaciones y decisiones operativas propias del repo.
- No debe existir ningún side effect persistente antes de `check_superrepo_guard`.
- Debe existir una modalidad segura de simulación sin commit ni push efectivos.
- El flujo debe ser válido desde cualquier subdirectorio del repo `/webapps/ihh-devtools`.
- El cierre observable del flujo puede validarse con una señal visible compuesta; no requiere marcador terminal único.
- Los failure modes contractuales relevantes siguen siendo:
  - resolución fuera del ACP local del repo,
  - falta de mensaje principal,
  - repo Git no válido,
  - guard que bloquea antes de side effects persistentes,
  - simulación con side effects reales,
  - salida no observable o engañosa.
- Acceptance candidates relevantes ya aprobados:
  - resolución local del flujo en `devbox`,
  - mensaje obligatorio,
  - guard previo a side effects persistentes,
  - simulación segura,
  - preservación semántica principal del mensaje,
  - salida visible suficiente,
  - validación Bats del flujo completo.

**Estado:** operativamente clara

### Partes del código que ya cumplen
Qué comportamiento actual ya satisface el spec y no requiere cambio.

Instrucción operativa:
Esta sección evita trabajo innecesario. Debe listar solo aquello que el código actual ya sostiene de forma suficiente respecto del spec. No metas aquí comportamientos accidentales si el spec no los exige.

**Contenido**
- La entrada visible/runtime hacia el flujo local del repo quedó anclada en `devbox.json` mediante la inyección de `alias.acp`.
- El entry local real `bin/git-acp.sh` ya quedó identificado y alineado con el contrato.
- La validación de contexto Git utilizable ya quedó anclada en `bin/git-acp.sh`.
- La obligatoriedad del mensaje ya quedó reportada como alineada en spec-anchored.
- La modalidad segura de simulación quedó anclada y aceptada contractualmente.
- El orden contractual de side effects persistentes, después del guard, quedó reportado como alineado.
- La validez desde cualquier subdirectorio del repo quedó aceptada contractualmente y alineada con la resolución dinámica del código.
- La salida visible compuesta quedó aceptada como suficiente; por tanto no hace falta introducir un marcador terminal único.
- La validación Bats del flujo completo ya fue tomada como evidencia de alineación mínima en verde.

**Estado:** operativamente clara

### Gaps a cerrar
Qué partes del spec aún no están satisfechas o están solo parcialmente satisfechas.

Instrucción operativa:
Esta es una sección central. Debe expresar con claridad qué falta para que el flujo cumpla el spec. Distingue entre gap claro, gap parcial y gap dependiente de decisión abierta.

**Contenido**
- **Gap claro:** no queda un gap central abierto entre spec y código para el cumplimiento mínimo aprobado del flujo.
- **Gap parcial:** la cobertura de validación observable sigue siendo mínima respecto a ramas del post-push distintas de `skip`; esto no rompe el spec mínimo, pero sí deja borde no explorado.
- **Gap parcial:** la superficie identidad/SSH/remotos/GitHub sigue siendo amplia y con seams heredados; hoy no aparece como incumplimiento contractual directo, pero sí como foco de posible regresión.
- **Gap dependiente de decisión abierta:** no hay uno abierto dentro del contrato actual; solo aparecería si se decide ampliar contrato a más ramas del post-push, más flags visibles o más garantías de tooling lateral.

**Estado:** operativamente clara

### Cambios necesarios derivados del spec
Qué trabajo sí está justificado por el contrato.

Instrucción operativa:
Describe solo trabajo permitido y necesario. Debe poder trazarse directamente al spec y al anclaje previo. No incluyas mejoras laterales, limpiezas generales ni “ya que estamos”.

**Contenido**
- No hay, a esta altura, un cambio funcional central adicional que el spec obligue a introducir para declarar cumplimiento mínimo del flujo ya anclado.
- El trabajo autorizado por el spec queda acotado a:
  - preservar la alineación ya lograda;
  - impedir regresiones frente a los invariants contractuales;
  - sostener la validación obligatoria que prueba esa alineación;
  - corregir únicamente desalineaciones futuras que rompan:
    - resolución local del flujo,
    - obligatoriedad del mensaje,
    - guard antes de side effects persistentes,
    - simulación segura,
    - salida visible suficiente,
    - validez desde subdirectorio del repo.
- Si aparece una regresión en cualquiera de esos puntos, el cambio necesario deberá recaer solo en la superficie estrictamente vinculada a esa cláusula del spec.

**Estado:** operativamente clara

### Cambios explícitamente fuera de alcance
Qué no debe tocarse aunque esté cerca del flujo.

Instrucción operativa:
Recorta el scope. Incluye comportamientos vecinos, refactors, limpiezas, mejoras de UX, endurecimientos no pedidos o trabajos colaterales que no sean necesarios para cumplir el spec.

**Contenido**
- limpieza general de `Compat` / `LEGACY_`
- refactor amplio de identidad/SSH/remotos/GitHub
- rediseño del flujo ACP
- rediseño del menú post-push
- ampliar o estabilizar contractualmente flags hoy accidentales
- mejorar banners, emojis o textos de consola
- imponer un formato literal de commit más estricto que el spec
- cambiar el mecanismo interno de resolución solo “porque sería mejor”
- endurecer ramas laterales no cubiertas por el contrato actual
- trabajo vecino en otros flujos Git, otros aliases o tooling del repo no exigido por este flujo

**Estado:** operativamente clara

### Superficies principales de intervención
Archivos, funciones o módulos donde vive el trabajo principal.

Instrucción operativa:
Debe apoyarse en spec-anchored. Distingue entre superficie principal, secundaria y zona de alto riesgo. No diseñes todavía la solución detallada; solo identifica dónde recae la responsabilidad real.

**Contenido**
- **Superficie principal:**
  - `devbox.json`
  - `bin/git-acp.sh`
  - `lib/core/config.sh`
  - `lib/core/contract.sh`
  - `lib/core/utils.sh`
  - `lib/git-flow.sh`
  - `lib/ssh-ident.sh`
  - `lib/ci-workflow.sh`
- **Superficie secundaria:**
  - `devtools.repo.yaml`
  - `.devtools/.git-acprc`
  - `tests/03_git_acp_devbox.bats`
  - `tests/02_git_acp_post_push.bats`
- **Zona de alto riesgo:**
  - seam runtime de `devbox` por inyección de `GIT_CONFIG_*`,
  - plano identidad/SSH/remotos/GitHub,
  - fallbacks UI y bridges en `lib/ci-workflow.sh`,
  - compatibilidades heredadas repartidas entre config y flujo Git.
- Estas superficies quedan identificadas como lugares donde podría recaer trabajo solo si una cláusula del spec vuelve a quedar desalineada; no significan autorización automática para tocar todo.

**Estado:** operativamente clara

### Seams, compatibilidades y zonas de riesgo
Fallbacks, wrappers, legacy y dispersión que pueden afectar el cumplimiento del spec.

Instrucción operativa:
Incluye todo lo que pueda arrastrar comportamientos viejos, tolerancias accidentales o fragilidad al intentar alinear el código con el spec. Esta sección es clave para prevenir deriva.

**Contenido**
- `DEVTOOLS_DISPATCH_DONE`
- `LEGACY_VENDOR_CONFIG`
- `DEVTOOLS_WIZARD_MODE`
- compatibilidad de rama deprecada en `lib/git-flow.sh`
- fallbacks UI / `run_cmd` en `lib/ci-workflow.sh`
- inyección runtime de `alias.acp` por `devbox`
- dispersión del plano identidad/SSH/remotos/GitHub`
- Estos seams no reabren el contrato ni crean trabajo obligatorio por sí mismos, pero sí pueden:
  - arrastrar comportamiento viejo contrario al spec,
  - confundir criterio de cumplimiento con compatibilidad incidental,
  - inducir regresiones si se toca más superficie de la necesaria.

**Estado:** operativamente clara

### Validación obligatoria
Qué debe comprobarse sí o sí para afirmar cumplimiento.

Instrucción operativa:
Deriva esta sección desde el spec, no desde la comodidad técnica. Debe incluir comportamiento observable, cierre de divergencias y señales suficientes de cumplimiento real.

**Contenido**
Debe comprobarse sí o sí que:

1. En una sesión válida de `devbox`, `git acp "<texto>"` resuelve al flujo ACP local del repo y no a una resolución global ajena.
2. El flujo exige mensaje principal y rechaza la ejecución antes de side effects persistentes si ese mensaje falta.
3. El repo Git válido se verifica antes de continuar con el flujo útil.
4. `check_superrepo_guard` y las verificaciones previas ocurren antes de side effects persistentes de config o publicación.
5. La modalidad de simulación no produce commit ni push efectivos.
6. La ejecución válida desde un subdirectorio del repo sigue aterrizando en el mismo flujo contractual.
7. La salida visible permite distinguir al menos entre ejecución efectiva, simulación y cierre u omisión general.
8. La validación Bats exigida para el flujo completo permanece en verde dentro de `devbox`.

No basta con validar:
- solo el script local por `bash ./bin/git-acp.sh`,
- solo el top-level cwd,
- solo la rama `skip`,
- solo la salida de consola,
- solo el `--dry-run`.

**Estado:** operativamente clara

### Acceptance candidates listos para ejecución
Qué afirmaciones ya pueden materializarse en validación concreta.

Instrucción operativa:
Aquí no hace falta escribir todavía el test final, pero sí dejar claro qué afirmaciones están maduras y cómo deberían leerse como criterio de aceptación ejecutable.

**Contenido**
- `git acp "<texto>"` en `devbox` resuelve al ACP local del repo.
- La resolución sigue funcionando desde cualquier subdirectorio del repo.
- Sin mensaje principal, el flujo falla antes de commit o push.
- La simulación recorre la ruta segura sin commit ni push efectivos.
- El flujo ejecuta verificaciones propias del repo antes de side effects persistentes.
- Si el flujo anuncia ejecución efectiva exitosa, existe un resultado ACP observable coherente con el mensaje principal.
- La salida final del flujo deja una señal visible suficiente, aunque no exista marcador terminal único.
- La validación Bats del flujo completo constituye evidencia ejecutable mínima de cumplimiento.
- Acceptance aún no maduros para elevar a obligación contractual nueva:
  - ramas adicionales del post-push más allá de `skip`,
  - garantías más fuertes sobre tooling lateral `task`, `gh`, remotos o bridges de CI,
  - toda la superficie de identidad/SSH como contrato visible del flujo.

**Estado:** operativamente clara

### Criterio de cumplimiento
Qué tendría que ser cierto para poder decir que el flujo cumple el spec.

Instrucción operativa:
Debe formularse de manera clara, verificable y no ambigua. No puede depender de intuición. Debe distinguir entre cumplimiento mínimo, cumplimiento deseable y falsa apariencia de cumplimiento.

**Contenido**
- **Cumplimiento mínimo:**
  - `git acp "<texto>"` en una sesión válida de `devbox` entra al flujo local del repo;
  - `"<texto>"` es obligatorio y se preserva como base semántica principal;
  - las verificaciones y guards propios del repo ocurren antes de side effects persistentes;
  - la simulación no genera commit ni push efectivos;
  - la ejecución es válida desde cualquier subdirectorio del repo;
  - el flujo deja una salida visible suficiente;
  - la validación Bats obligatoria permanece en verde.
- **Cumplimiento deseable:**
  - ampliar evidencia sobre ramas adicionales del post-push,
  - reducir exposición a seams heredados sin ampliar scope,
  - sostener estabilidad runtime del alias inyectado en más sesiones equivalentes.
- **Falsa apariencia de cumplimiento:**
  - que `--dry-run` funcione pero la ejecución efectiva no;
  - que el flujo funcione solo desde el cwd raíz y no desde subdirectorios;
  - que pase el script local pero falle la entrada visible `git acp` en `devbox`;
  - que exista salida vistosa de consola pero el guard o el orden de side effects estén mal;
  - que la rama `skip` funcione y se use eso para afirmar cobertura total del post-push.

**Estado:** operativamente clara

### Criterio de terminado
Cuándo esta fase queda suficientemente cerrada para pasar a ejecución real o delegada.

Instrucción operativa:
Debes dejar claro qué condiciones tienen que cumplirse para considerar que spec-as-source hizo su trabajo: scope recortado, gaps identificados, superficies ubicadas, validación derivada y criterio de cumplimiento fijado.

**Contenido**
Esta fase queda suficientemente cerrada cuando:
- el spec aprobado sigue siendo la autoridad explícita del flujo;
- quedó claro que hoy no hay cambio funcional central pendiente para el cumplimiento mínimo;
- los gaps residuales quedaron distinguidos de divergencias reales;
- el scope quedó recortado con trabajo permitido vs fuera de alcance;
- las superficies de intervención quedaron ubicadas;
- los seams y riesgos quedaron explicitados;
- la validación obligatoria quedó derivada desde el spec;
- el criterio de cumplimiento quedó formulado de forma verificable;
- quedó claro bajo qué condiciones puede delegarse ejecución o validación sin reabrir contrato.

Esas condiciones ya se cumplen.

**Estado:** operativamente clara

### Unknowns
Qué sigue abierto y cómo afecta el trabajo posterior.

Instrucción operativa:
Todo lo que aún no esté cerrado debe aparecer aquí. Distingue entre unknown que no bloquea, unknown que condiciona y unknown que bloquea. Nunca lo tapes con frases vagas.

**Contenido**
- **No bloquea:**
  - otras ramas del post-push además de `skip`,
  - peso real de `Compat` / `LEGACY_`,
  - estabilidad futura de la inyección runtime de `alias.acp`,
  - alcanzabilidad real de ramas laterales como reparación de remotos o `gh repo create`,
  - cuánto del plano identidad/SSH/remotos/GitHub es soporte necesario vs desborde del contrato visible.
- **Condiciona, pero no bloquea:**
  - si en una fase futura se quisiera ampliar la superficie contractual visible del post-push,
  - si se quisiera estabilizar contractualmente tooling lateral hoy tratado como soporte.
- **Bloquea:**
  - ninguno dentro del contrato actual ya aprobado.

**Estado:** operativamente clara

### Evidencia
Referencias concretas:
- cláusulas del spec
- archivos
- funciones
- módulos
- seams
- divergencias detectadas
- validaciones previstas
- corridas observadas si aplica

Instrucción operativa:
Cada afirmación importante de esta plantilla debe poder rastrearse al spec y al anclaje previo. Si una decisión no tiene suficiente evidencia, márcala como parcial o abierta.

**Contenido**
- **Cláusulas de spec de referencia:**
  - entrada visible `git acp "<texto_aquí>"` en `devbox`,
  - mensaje obligatorio,
  - simulación segura,
  - side effects persistentes solo después del guard,
  - validez desde subdirectorio del repo,
  - salida visible compuesta suficiente,
  - validación Bats obligatoria.
- **Anclaje previo en código:**
  - `devbox.json:79`
  - `devbox.json:91`
  - `bin/git-acp.sh:1`
  - `bin/git-acp.sh:109`
  - `bin/git-acp.sh:119`
  - `lib/core/contract.sh:173`
  - `lib/core/utils.sh:382`
  - `lib/core/utils.sh:429`
  - `lib/core/utils.sh:464`
  - `lib/git-flow.sh:57`
  - `lib/ssh-ident.sh`
  - `lib/ci-workflow.sh:546`
  - `tests/03_git_acp_devbox.bats`
  - `tests/02_git_acp_post_push.bats`
- **Divergencias previamente cerradas:**
  - mensaje obligatorio vs tolerancia interactiva,
  - side effects persistentes tempranos,
  - cwd contractual relajado a subdirectorios,
  - cierre observable aceptado como señal compuesta.
- **Validación previa reportada:**
  - Bats del flujo completo en verde,
  - runtime correcto en `devbox`,
  - validación segura con `--dry-run`,
  - validación de rama `skip`.

**Estado:** operativamente clara

### Criterio de salida para ejecutar o delegar implementación
Qué debe estar claro antes de pasar a trabajo de cambio real.

Instrucción operativa:
No promociones por sensación. Debes escribir explícitamente:
- qué trabajo quedó autorizado por el spec;
- qué trabajo quedó prohibido o fuera de alcance;
- qué validaciones serán obligatorias;
- qué riesgos deben vigilarse;
- qué unknowns no bloquean avanzar;
- qué unknowns sí bloquean;
- qué mínima aclaración faltaría si todavía no conviene ejecutar.

**Contenido**
Antes de pasar a trabajo real debe quedar claro que:

- **Trabajo autorizado por el spec:**
  - mantener y defender la alineación ya lograda;
  - corregir solo regresiones o desalineaciones directas contra el contrato aprobado;
  - ejecutar y exigir la validación obligatoria derivada del spec;
  - intervenir únicamente en la superficie necesaria para la cláusula afectada.
- **Trabajo prohibido o fuera de alcance:**
  - limpiezas generales,
  - refactors oportunistas,
  - mejoras laterales de UX,
  - ampliación de flags visibles,
  - rediseño del post-push,
  - endurecimientos no pedidos por el contrato,
  - cambios en flujos vecinos.
- **Validaciones obligatorias:**
  - resolución local del flujo en `devbox`,
  - mensaje obligatorio,
  - guard previo a side effects persistentes,
  - simulación segura,
  - validez desde subdirectorio,
  - salida visible suficiente,
  - Bats del flujo completo en verde.
- **Riesgos a vigilar:**
  - que el runtime de `devbox` vuelva a resolver fuera del repo,
  - que seams heredados vuelvan a introducir side effects tempranos,
  - que se confunda cobertura mínima con cobertura total del post-push,
  - que se valide solo el script local y no la entrada visible contractual.
- **Unknowns que no bloquean:**
  - los ya listados en la sección `Unknowns`.
- **Unknowns que sí bloquean:**
  - ninguno, dentro del marco aprobado actual.
- **Mínima aclaración faltante si se quisiera ejecutar:**
  - no hace falta una aclaración contractual adicional para avanzar dentro del alcance actual;
  - solo haría falta aclaración nueva si se pretende ampliar scope más allá del spec aprobado.

**Estado:** operativamente clara

---

## Formato obligatorio de trabajo durante todo spec-as-source

Estado actual
- Bloque actual: Bloque 7 cerrado
- Objetivo del bloque: cerrar `spec-as-source` con una ficha operativa consolidada donde el spec gobierna el trabajo posterior
- Pregunta operativa que estamos resolviendo: ¿qué trabajo está realmente autorizado por el spec, qué debe validarse para afirmar cumplimiento y qué no debemos tocar para no perder el marco?

Trabajo ya claramente derivado del spec
- El contrato aprobado sigue siendo la autoridad del flujo `git acp "<texto_aquí>"` en `devbox`.
- El anclaje previo ya dejó alineados los puntos centrales del flujo.
- No quedan divergencias centrales abiertas que obliguen a introducir cambio funcional nuevo para cumplir el spec mínimo aprobado.
- La validación Bats del flujo completo ya quedó exigida y previamente reportada en verde dentro de `devbox`.

Puntos aún parciales o abiertos
- ramas del post-push distintas de `skip`
- peso real de piezas `Compat` / `LEGACY_`
- estabilidad futura de la inyección runtime de `alias.acp`
- alcance real de ramas laterales de identidad/SSH/remotos/GitHub

Riesgos de desviación o scope creep
- tocar legacy por limpieza y no por necesidad contractual
- ampliar la interfaz visible del flujo sin decisión explícita
- validar solo `--dry-run` y concluir erróneamente cumplimiento total
- dejar que seams heredados vuelvan a gobernar el criterio de cambio

Qué podemos dejar fuera por ahora
- refactor general
- limpieza de compatibilidades heredadas
- rediseño del menú post-push
- ampliación de flags visibles
- endurecimientos o UX extra no exigidos por el spec

Condición para pasar al siguiente bloque
- Cumplida.
- `spec-as-source` queda cerrada y lista para gobernar ejecución real o delegada.

Regla final:
Spec-as-source solo queda bien hecho si esta plantilla permite responder con claridad a la pregunta:
“¿Qué trabajo está realmente autorizado por el spec, qué debe validarse para afirmar cumplimiento y qué no debemos tocar para no perder el marco?”

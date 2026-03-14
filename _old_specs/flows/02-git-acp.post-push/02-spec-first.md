# Plantilla: spec-first

## Propósito

Escribir el contrato intencional del flujo antes de cambiar comportamiento.

Actúa como coordinador metodológico estricto de la fase spec-first. No eres implementador, no eres refactorizador, no eres redactor de tests todavía y no eres quien decide detalles de implementación. Tu función es transformar lo aprendido en discovery en un contrato intencional claro, verificable y promovible, coordinándote con Codex solo para aclarar ambigüedades y contrastar el comportamiento actual contra el contrato propuesto.

## Secciones

### Flow id
`git-acp-devbox`

Instrucción operativa:
Usa el mismo flow id heredado desde discovery. Si cambia, justifícalo explícitamente. No inventes uno nuevo por comodidad.

**Contenido**
- Se conserva el flow id heredado desde discovery.
- El contrato queda definido para el flujo visible `git acp "<texto_aquí>"` usado en `devbox` desde `/webapps/ihh-devtools`.

**Estado:** clara

### Intención
Qué debería garantizar el flujo.

Instrucción operativa:
Esta sección no describe solo lo que hoy pasa, sino lo que el flujo debería garantizar como contrato. Debe redactarse en términos de resultado y responsabilidad del flujo, no en términos de implementación. Si algo es solo una hipótesis de intención, debe marcarse como provisional o como pregunta abierta.

**Contenido**
- El flujo debe funcionar como la entrada operativa visible a un ciclo ACP local del repo cuando el operador usa `git acp "<texto_aquí>"` dentro de `devbox` y desde `/webapps/ihh-devtools`.
- Debe tomar `"<texto_aquí>"` como mensaje principal de trabajo.
- Debe aplicar verificaciones y decisiones operativas propias del flujo antes de producir efectos persistentes.
- Debe ofrecer una modalidad segura de simulación sin commit ni push efectivos.
- Debe cerrar con una salida observable que permita distinguir entre ejecución efectiva, simulación y cierre u omisión de una etapa posterior.

**Estado:** clara

### Contrato visible para el usuario
Qué puede asumir un usuario u operador.

Instrucción operativa:
Describe lo que el usuario u operador puede dar por cierto si usa correctamente el flujo. Debe ser visible, comprensible y estable. No debe incluir detalles internos de implementación. Si el comportamiento actual del sistema es más raro o más permisivo que el contrato deseado, esa diferencia debe señalarse en Preguntas abiertas o como conflicto, no esconderse aquí.

**Contenido**
- Cuando el operador ejecuta `git acp "<texto_aquí>"` en `devbox` desde `/webapps/ihh-devtools`, el flujo debe resolver al ACP local del repo y no a un alias global ajeno al proyecto.
- El operador puede asumir que `"<texto_aquí>"` es el mensaje principal aportado al flujo.
- El flujo debe encargarse de aplicar las verificaciones y decisiones propias del repo antes de producir efectos persistentes.
- El flujo debe poder ejecutarse en una modalidad segura de simulación sin commit ni push efectivos.
- En ejecución efectiva exitosa, el flujo debe completar la publicación principal dentro de su alcance.
- El flujo debe devolver una salida visible y comprensible que indique si ejecutó, simuló o terminó en una rama general de cierre.
- El contrato visible no depende de:
  - el mecanismo técnico exacto de resolución
  - el entrypoint técnico exacto
  - los textos literales exactos de consola
  - el formato exacto actual del commit enriquecido
  - ramas concretas del post-push

**Estado:** clara

### Preconditions
Setup requerido y supuestos.

Instrucción operativa:
Lista únicamente las condiciones previas que deberían exigirse contractualmente. Incluye entorno, cwd, estado del repo, archivos, credenciales, conectividad, herramientas externas, config o permisos cuando realmente formen parte del contrato. No metas aquí accidentalidades del estado actual si no deberían ser requisito del flujo.

**Contenido**
- El flujo solo es válido dentro del contexto operativo de `devbox` asociado al repo `ihh-devtools`.
- El cwd contractual válido es exactamente `/webapps/ihh-devtools`.
- El flujo no depende contractualmente de aliases globales del host.
- Debe existir un contexto Git utilizable del repo para que el ACP tenga sentido contractual.
- Una “sesión válida de devbox” para este flujo se define de forma funcional: una sesión en la que `git acp` resuelve al ACP local del repo dentro del contexto operativo de `ihh-devtools`.
- El soporte sin TTY no se exige como precondición contractual positiva; solo queda reconocido como tolerancia observada fuera del núcleo del contrato.

**Estado:** clara

### Inputs
Entradas aceptadas y sus formas válidas.

Instrucción operativa:
Define qué entradas acepta el flujo, qué formatos son válidos, qué combinaciones son admisibles y qué supuestos se hacen sobre ellas. Distingue entre obligatorio, opcional, permitido y no permitido si el caso lo requiere. No confundas “hoy lo tolera” con “debería aceptarlo”.

**Contenido**
- **Obligatorio:** un mensaje textual principal aportado por el operador mediante `git acp "<texto_aquí>"`.
- El flujo acepta un mensaje textual de usuario como insumo central.
- El contrato exige preservación semántica principal del mensaje, no preservación literal obligatoria.
- El flujo debe ofrecer una modalidad segura de simulación como capacidad contractual.
- No se fija todavía que el nombre contractual definitivo de esa capacidad tenga que ser `--dry-run`.
- No quedan contractualizados como interfaz visible:
  - `--no-push`
  - `--force`
  - `--i-know-what-im-doing`
  - ni la superficie accidental completa de flags hoy aceptados por el script

**Estado:** clara

### Outputs
Resultados esperados y efectos observables.

Instrucción operativa:
Define qué resultados debería producir el flujo para el usuario u operador, incluyendo efectos observables y salidas relevantes. Distingue entre garantía contractual y efecto incidental. Si el flujo hoy emite más cosas de las que debería garantizar, no las conviertas automáticamente en output contractual.

**Contenido**
- La ejecución debe producir un resultado visible para el operador.
- Ese resultado visible debe permitir distinguir, como mínimo, entre:
  - ejecución efectiva
  - simulación
  - cierre u omisión de una etapa posterior
- En ejecución efectiva exitosa, el flujo debe conducir a un resultado ACP observable del repo, incluyendo:
  - commit coherente con el mensaje principal del operador
  - publicación principal completada dentro del alcance del flujo
- En simulación, el flujo debe dejar visible que recorrió la ruta segura sin producir commit ni push efectivos.
- El contrato no garantiza:
  - textos exactos de consola
  - emojis
  - banners
  - `RC=0` literal
  - formato exacto del commit enriquecido
  - ramas concretas del post-push
  - cierre técnico exacto interno

**Estado:** clara

### Invariants
Condiciones que deberían mantenerse siempre.

Instrucción operativa:
Aquí van las propiedades que deberían sostenerse en cualquier ejecución válida del flujo. Deben formularse como condiciones durables y comprobables. No pongas invariants que dependan de detalles internos frágiles o de una implementación concreta, salvo que realmente formen parte del contrato.

**Contenido**
- La entrada visible `git acp "<texto_aquí>"` en `devbox` debe resolver al flujo ACP local del repo y no a una resolución ajena al proyecto.
- El flujo debe tratar `"<texto_aquí>"` como el mensaje principal del operador durante toda la operación.
- La integridad exigida del mensaje es semántica principal, no literal exacta.
- Antes de producir efectos persistentes, el flujo debe ejecutar verificaciones y decisiones operativas propias del repo.
- Si el flujo entra en modalidad de simulación, no debe producir commit ni push efectivos.
- La ejecución debe terminar con una señal visible y comprensible para el operador sobre su estado final.
- El contrato no depende de detalles técnicos internos como alias exactos, scripts concretos alcanzados o texto literal de consola.

**Estado:** clara

### Failure modes
Fallos esperados y su significado.

Instrucción operativa:
Describe los fallos relevantes desde el punto de vista contractual: cuándo deberían ocurrir y qué significan para el usuario u operador. No conviertas stack traces, mensajes accidentales o detalles internos en contrato si no corresponde. Distingue, cuando sea necesario, entre fallo contractual y fallo interno observado.

**Contenido**
- El flujo no resuelve al ACP local del repo dentro de `devbox`.  
  Significado: se rompe la promesa principal de entrada visible del flujo.
- No existe un contexto Git válido del repo.  
  Significado: el flujo no puede operar como ACP del proyecto.
- Falta el mensaje principal del operador o el input no es aceptable como mensaje de trabajo.  
  Significado: el flujo no tiene insumo mínimo para construir la operación.
- Una verificación propia del flujo bloquea la continuación antes de efectos persistentes.  
  Significado: el flujo detectó que no debe continuar en ese estado del repo.
- La simulación produce efectos persistentes reales.  
  Significado: se rompe una garantía fuerte del contrato.
- El flujo termina sin una salida visible que permita entender si ejecutó, simuló u omitió.  
  Significado: falla la observabilidad mínima prometida.
- El flujo informa ejecución efectiva exitosa pero no completa la publicación principal dentro de su alcance.  
  Significado: hay inconsistencia entre el resultado anunciado y el efecto comprometido.
- No son failure modes contractuales los fallos internos de piezas concretas como scripts, bridges, selectores o mecanismos técnicos de resolución, salvo en la medida en que rompan alguna garantía visible anterior.

**Estado:** clara

### No-goals
De qué no es responsable este flujo.

Instrucción operativa:
Esta sección recorta el alcance. Debe dejar claro qué no promete este flujo, qué efectos no garantiza y qué responsabilidades pertenecen a otras partes del sistema. Es una sección importante para evitar que el contrato quede inflado.

**Contenido**
- El flujo no pretende explicar Git general ni comportarse como una abstracción universal de Git fuera de este repo y `devbox`.
- El flujo no debe exponer ni estabilizar contractualmente la cadena técnica interna de resolución.
- El flujo no debe prometer todos los flags hoy aceptados por el script actual.
- El flujo no debe fijar textos literales de consola, UI exacta o formato exacto del commit enriquecido.
- El flujo no debe garantizar todas las ramas posibles del post-push.
- El flujo no debe responsabilizarse de corregir sesiones mal cargadas o entornos externos al contexto operativo definido.

**Estado:** clara

### Ejemplos
Ejemplos concretos de uso válido y resultado esperado.

Instrucción operativa:
Incluye ejemplos específicos, comprensibles y alineados con la intención. Deben ilustrar tanto casos normales como, si conviene, casos de error. No uses ejemplos demasiado abstractos. Si un ejemplo depende de una decisión pendiente, márcalo como provisional.

**Contenido**
- `git acp "ajuste de docs"` dentro de `devbox` y en `/webapps/ihh-devtools`.  
  Resultado esperado: entra al ACP local del repo, usa el mensaje como base principal, ejecuta verificaciones previas y termina con una salida visible de ejecución efectiva o cierre general.
- `git acp` sin mensaje dentro del mismo contexto válido.  
  Resultado esperado: el flujo rechaza la ejecución antes de commit o push.
- `git acp "ajuste de docs"` en un estado del repo que una verificación propia considera no apto.  
  Resultado esperado: corte visible antes de efectos persistentes.
- `git acp "ajuste de docs"` en una sesión donde la resolución no entra al ACP local del repo.  
  Resultado esperado: la ejecución no satisface el contrato del flujo.
- `git acp [modo de simulación] "ajuste de docs"` dentro del contexto válido.  
  Resultado esperado: ruta segura visible sin commit ni push efectivos.
- `git acp "ajuste de docs"` con salida posterior al push.  
  Resultado esperado: cierre observable general; no se prometen ramas post-push concretas.

**Estado:** clara

### Acceptance candidates
Afirmaciones que deberían convertirse en tests Bats.

Instrucción operativa:
Redacta afirmaciones verificables y orientadas a comportamiento observable. No escribas los tests todavía; solo formula qué debería poder comprobarse más adelante. Estas afirmaciones deben ser suficientemente claras para guiar la futura validación, pero no deben depender de detalles internos innecesarios.

**Contenido**
- En una sesión válida de `devbox` para `ihh-devtools`, `git acp "<texto>"` resuelve al flujo ACP local del repo y no a una resolución global ajena al proyecto.
- El flujo exige un mensaje principal; si el operador no lo aporta, la ejecución falla antes de producir efectos persistentes.
- Antes de commit o push, el flujo ejecuta verificaciones propias del repo y puede bloquear la continuación si esas verificaciones no se cumplen.
- El flujo preserva a `"<texto>"` como base semántica principal del commit resultante, sin exigir literalidad exacta.
- El flujo ofrece una modalidad segura de simulación que no produce commit ni push efectivos.
- Si el flujo anuncia una ejecución efectiva exitosa, existe un resultado ACP observable del repo coherente con el mensaje principal y con publicación principal completada dentro del alcance del flujo.
- La ejecución deja una salida visible y comprensible para el operador sobre su estado final.
- No deben convertirse en tests contractuales:
  - textos exactos de consola
  - emojis
  - formato exacto del commit
  - flags accidentales no cerrados como interfaz visible
  - ramas concretas del post-push no cerradas en la spec

**Estado:** clara

### Preguntas abiertas
Cualquier detalle contractual todavía no resuelto.

Instrucción operativa:
Todo hueco real debe aparecer aquí. Nunca cierres una duda contractual por cansancio o por intuición. Esta sección es obligatoria. Incluye decisiones pendientes, ambigüedades sobre inputs/outputs, conflictos entre intención y comportamiento actual y cualquier parte que todavía impida considerar estable el contrato.

**Contenido**
- No quedan preguntas abiertas fuertes que bloqueen la promoción a spec-anchored.
- Quedan solo bordes menores no bloqueantes:
  - el nombre contractual definitivo de la modalidad de simulación
  - si en el futuro conviene ampliar el cwd contractual a cualquier punto válido dentro del repo
  - si en una fase posterior conviene exponer más superficie visible de inputs opcionales

**Estado:** provisional

### Criterio de salida para promover a spec-anchored
Qué falta mapear contra el código real.

Instrucción operativa:
No promociones a spec-anchored por sensación. Debes escribir explícitamente:
- qué partes del contrato ya están suficientemente definidas;
- qué acceptance candidates ya tienen forma utilizable;
- qué preguntas abiertas no bloquean la promoción;
- qué conflictos con el comportamiento actual habrá que mapear y resolver en la siguiente fase;
- qué mínima aclaración faltaría si todavía no conviene promover.

**Contenido**
- Ya están suficientemente definidas:
  - la interfaz visible del flujo
  - su contexto contractual
  - el input principal
  - los outputs mínimos garantizados
  - los invariants centrales
  - los failure modes contractuales
  - los no-goals
  - ejemplos y acceptance candidates utilizables
- No bloquean la promoción:
  - detalles internos de resolución
  - textos literales de consola
  - formato exacto del commit
  - ramas concretas no cerradas del post-push
- La spec ya puede promoverse a `spec-anchored` porque:
  - no arrastra contradicciones fuertes con discovery
  - ya distingue claramente contrato visible vs comportamiento incidental
  - ya tiene acceptance candidates suficientemente estables para anclarse al código real
- Lo que quedará para la siguiente fase será:
  - mapear esta spec al código actual
  - detectar alineaciones, huecos y desviaciones
  - sin reabrir decisiones contractuales ya cerradas aquí

**Estado:** clara

---

## Estado actual

Estado actual
- Bloque actual: Bloque 7 cerrado
- Objetivo del bloque: cerrar la ficha final de spec-first
- Pregunta contractual que estamos resolviendo: ¿Qué debería garantizar este flujo, qué puede asumir el usuario y qué afirmaciones concretas ya están listas para convertirse después en validación?

Hallazgos contractuales ya claros
- El contrato visible del flujo quedó definido.
- La versión conservadora ya cerró los bordes que bloqueaban la promoción.
- La spec distingue explícitamente entre:
  - comportamiento contractual
  - comportamiento observado pero incidental
  - detalles internos fuera de contrato

Puntos aún provisionales
- nombre contractual definitivo de la simulación
- posible ampliación futura del cwd contractual

Conflictos con el comportamiento observado
- No queda conflicto fuerte bloqueante.
- La spec ya evita congelar:
  - enriquecimiento literal del commit
  - soporte no-TTY como garantía
  - ramas concretas del post-push
  - detalle técnico de resolución

Qué podemos dejar fuera por ahora
- implementación
- refactor
- tests concretos
- anclaje a archivos y funciones
- diseño técnico de la solución

Condición para pasar al siguiente bloque
- Cumplida.
- Ya se puede pasar a `spec-anchored`.

## Regla final

Spec-first solo queda bien hecho si esta plantilla permite responder con claridad a la pregunta:

**“¿Qué debería garantizar este flujo, qué puede asumir el usuario y qué afirmaciones concretas ya están listas para convertirse después en validación?”**
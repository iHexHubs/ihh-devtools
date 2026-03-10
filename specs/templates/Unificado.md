# Flow: <flow-id>

- maturity: <discovery|spec-first|spec-anchored|spec-as-source>
- status: <draft|active|approved|blocked|deprecated>
- priority: <backlog|planned|in-progress|high|critical>
- source-of-truth: this file
- owner: <owner-or-team>
- reviewers: <people-or-skill-needed>
- related-tests:
  - tests/<flow-test>.bats
- related-flows:
  - <other-flow-id-if-any>
- last-updated: <yyyy-mm-dd>
- last-validated: <yyyy-mm-dd or run reference>

## Propósito de este documento

Este documento consolida en una sola fuente:
- el comportamiento real observado del flujo;
- el contrato aprobado del flujo;
- el anclaje explícito al código actual;
- las reglas que gobiernan cambios futuros.

No debe duplicar contenido entre fases.
No debe repartir la autoridad del flujo entre varios documentos.
Debe permitir que una IA o un contribuidor humano respondan rápido y con evidencia a estas preguntas:
- qué es este flujo;
- qué garantiza;
- por dónde entra;
- qué toca;
- qué archivos importan;
- qué no debe tocarse;
- qué falta validar;
- cuál es el siguiente paso correcto.

---

## 1. Identidad del flujo

### Flow id
`<flow-id>`

### Nombre corto
`<nombre-operativo-del-flujo>`

### Trigger visible
Comando, evento o acción visible que activa el flujo.

### Objetivo operativo
Describe qué intenta lograr el operador al activar este flujo.
Debe estar redactado en términos observables, no como intención vaga.

### Resultado esperado a alto nivel
Describe qué resultado global produce el flujo cuando sale bien, sin entrar todavía en implementación.

### Alcance del flujo
Qué sí pertenece a este flujo.

### Fuera de alcance
Qué no pertenece a este flujo aunque esté cerca técnica o funcionalmente.

### Estado
- `confirmada | parcial | abierta`

---

## 2. Resumen consolidado del flujo

## Qué debe entender alguien en menos de un minuto

Explica el flujo completo en un bloque continuo, claro y sin abreviar:
- cómo entra;
- cuál es su input principal;
- qué decisiones importantes toma;
- qué side effects puede producir;
- dónde termina;
- qué parte está observada en runtime;
- qué parte está auditada localmente;
- qué parte ya está elevada a contrato;
- qué parte sigue abierta.

Este bloque no debe ser un resumen vago.
Debe ser una lectura breve pero suficiente para situar a alguien antes de tocar código.

### Estado
- `confirmada | parcial | abierta`

---

## 3. Autoridad metodológica de este documento

## Qué partes ya quedaron absorbidas aquí

Esta sección deja explícito qué quedó consolidado desde cada fase previa:

### Discovery absorbido
Qué partes del comportamiento real observado ya quedaron incorporadas aquí.

### Spec-first absorbido
Qué partes del contrato aprobado ya quedaron incorporadas aquí.

### Spec-anchored absorbido
Qué partes del contrato ya quedaron mapeadas al código real.

### Spec-as-source absorbido
Qué reglas ya gobiernan cambios, validación y criterio de terminado.

### Regla de autoridad
A partir de este punto:
- este documento manda sobre recuerdos del chat;
- el contrato aprobado manda sobre comportamientos accidentales del código;
- los unknowns no pueden reescribirse como certezas;
- los seams heredados no amplían por sí mismos el scope;
- ningún cambio debe justificarse “porque el código ya lo hace” si contradice este documento.

### Estado
- `operativamente clara | parcial | abierta`

---

## 4. Comportamiento real observado

## Runtime real observado
Describe solo lo observado efectivamente en ejecución real dentro del contexto válido del flujo.

Incluye:
- trigger real;
- entorno real;
- cwd real;
- resolución real del entrypoint;
- outputs visibles observados;
- side effects observados o ausencia de side effects en rutas seguras;
- corridas relevantes.

Diferencia claramente entre:
1. runtime real observado;
2. comportamiento inferido desde lectura de código.

## Núcleo local auditado
Describe el núcleo real del flujo tal como quedó auditado en el repo.

Incluye:
- entrypoint local;
- cadena principal de dispatch;
- funciones o módulos centrales;
- punto de cierre del flujo;
- ramas relevantes;
- side effects posibles;
- inputs reales que atraviesan el flujo.

## Dispatcher chain consolidada
Cadena ordenada completa desde la entrada visible hasta el núcleo local.

## Camino feliz consolidado
Paso a paso de la ruta principal del flujo.

## Ramas importantes
Solo ramas que cambian de verdad el comportamiento relevante del flujo.

## Side effects reales
Git, red, filesystem, subprocesos, config, entorno, publicación, etc.

## Preconditions reales observadas
Qué tuvo que existir o sostenerse para que el flujo observado ocurriera.

## Error modes observados
Fallos realmente vistos o fuertemente sustentados por el flujo real.

### Estado
- `confirmada | parcial | abierta`

---

## 5. Contrato canónico del flujo

Esta sección ya no describe solo lo que hoy ocurre.
Describe lo que el flujo aprobado **debe garantizar**.

## Intención contractual
Qué debería garantizar este flujo de forma estable.

## Contrato visible para el usuario
Qué puede asumir un operador si usa correctamente el flujo.

## Preconditions contractuales
Qué condiciones previas exige contractualmente el flujo.

## Inputs contractuales
Entradas aceptadas, obligatorias, opcionales, toleradas y no prometidas.

## Outputs contractuales
Resultados observables que el flujo debe producir o dejar visibles.

## Invariants obligatorios
Condiciones que siempre deben sostenerse.

## Failure modes contractuales
Fallos relevantes y qué significan para el operador.

## No-goals
De qué no es responsable este flujo.

## Supuestos prohibidos
Cosas en las que nadie debe apoyarse al trabajar este flujo.

Ejemplos típicos:
- detalles accidentales del alias;
- textos literales de consola;
- formato exacto incidental de commit;
- ramas no contractualizadas;
- tooling lateral no cerrado como interfaz visible.

### Estado
- `clara | provisional | en conflicto`

---

## 6. Mapa explícito entre contrato y código

Esta es la parte que evita que la spec flote sin anclaje.

## Entry point real anclado
- comando o trigger visible;
- archivo real;
- función, wrapper o handler inicial;
- evidencia exacta que sostiene el anclaje.

## Code anchors por responsabilidad
Para cada cláusula importante del contrato, indicar:
- cláusula o garantía;
- archivo(s);
- función(es) o bloque(s);
- rol dentro del flujo;
- estado del anclaje.

Formato sugerido:

### <nombre-de-la-cláusula>
- cláusula: <qué exige el contrato>
- ancla principal:
  - `<archivo>:<línea o función>`
- anclas secundarias:
  - `<archivo>:<línea o función>`
- cómo se sostiene hoy:
  - <explicación>
- estado:
  - `anclada | parcial | abierta | en conflicto`

## Mapeo del camino feliz al código
Dónde vive cada paso de la secuencia principal.

## Mapeo de ramas al código
Dónde viven flags, bifurcaciones y rutas alternativas relevantes.

## Mapeo de side effects al código
Qué archivo o función produce cada side effect importante.

## Preconditions ancladas
Dónde se validan o solo se asumen.

## Outputs anclados
Dónde se generan o se exponen los resultados observables.

## Invariants anclados
Qué partes del código sostienen cada invariant y dónde podría romperse.

## Failure modes anclados
Dónde aparecen y cómo se materializan los fallos contractuales.

### Estado
- `anclada | parcial | abierta | en conflicto`

---

## 7. Superficies de intervención reales

Esta sección responde: si mañana cambio algo de este flujo, ¿dónde recae de verdad la responsabilidad?

## Superficie principal
Archivos, funciones o módulos donde vive la lógica central del flujo.

## Superficie secundaria
Archivos que pueden verse afectados si cambia el flujo, pero no son el núcleo.

## Superficie de validación
Tests, helpers, scripts o fixtures que deben moverse junto al flujo.

## Zonas de alto riesgo
Partes donde tocar poco código puede generar regresiones amplias.

## Boundaries con flujos vecinos
Qué archivos están cerca pero pertenecen a otro flujo o responsabilidad.

### Estado
- `operativamente clara | parcial | abierta`

---

## 8. Divergencias, drift y gaps

Aquí no va ruido de estilo.
Aquí van las diferencias reales entre:
- comportamiento observado;
- contrato aprobado;
- código actual;
- validación existente.

## Divergencias cerradas
Qué contradicciones ya fueron resueltas y cómo quedaron absorbidas en este documento.

## Divergencias abiertas
Qué partes del contrato y del código todavía no coinciden.

## Gaps funcionales
Qué falta para que el flujo cumpla completamente su contrato.

## Gaps de anclaje
Qué parte del contrato todavía no está suficientemente localizada en el código.

## Gaps de validación
Qué parte del contrato todavía no tiene prueba suficientemente fuerte.

## Riesgo de falsa sensación de cumplimiento
Qué podría “parecer bien” aunque todavía no cumpla el contrato completo.

### Estado
- `clara | parcial | abierta | bloqueada`

---

## 9. Legacy, seams y compatibilidades

Esta sección existe para que nadie confunda compatibilidad heredada con contrato del flujo.

## Seams heredados observados
Wrappers, bridges, fallbacks, banderas de compatibilidad, UI heredada, dispatch duplicado, etc.

## Legacy sospechado pero no demostrado
Piezas que parecen toleradas o viejas, pero cuya necesidad actual no quedó probada.

## Compatibilidades que influyen pero no explican el flujo
Config, bridges, flags o capas externas que alteran ejecución pero no deben convertirse en explicación principal del flujo.

## Política para tocar seams
Cuando un seam:
- debe respetarse;
- puede aislarse;
- no debe reescribir el contrato;
- no justifica por sí solo una ampliación del scope.

### Estado
- `parcial | abierta | operativamente clara`

---

## 10. Validación obligatoria del flujo

Esta sección responde: ¿qué hay que comprobar sí o sí para decir que el flujo cumple?

## Validación obligatoria
Lista de afirmaciones que deben demostrarse con evidencia observable.

## Validación recomendable
Aumenta confianza, pero no bloquea cumplimiento mínimo.

## Validación aún inmadura
Partes que todavía no tienen evidencia o anclaje suficiente para validarse limpiamente.

## Suite de aceptación
Tests, comandos o corridas que constituyen la evidencia mínima exigida.

## Qué no basta validar
Enumera validaciones incompletas que no deben usarse para declarar cumplimiento total.

### Estado
- `operativamente clara | parcial | abierta`

---

## 11. Evidencia consolidada

Aquí deben vivir las referencias concretas que sostienen afirmaciones del documento.

## Corridas observadas
Comandos ejecutados y resultados relevantes.

## Paths y archivos
Rutas concretas del repo.

## Funciones y handlers
Nombres y puntos de entrada importantes.

## Config y entorno
Variables, hooks, archivos de configuración y mecanismos de resolución.

## Tests y validaciones existentes
Qué pruebas ya se ejecutaron y con qué resultado.

## Referencias mínimas por afirmación importante
Toda afirmación central del flujo debe poder rastrearse a:
- una corrida observada;
- o una lectura concreta de código;
- o una validación existente.

### Estado
- `confirmada | parcial | abierta`

---

## 12. Unknowns reales

Esta sección es obligatoria.
Todo lo que no esté demostrado debe vivir aquí o quedar marcado como parcial en otra sección.

## Unknowns que no bloquean
Abiertos reales que no impiden trabajar dentro del contrato aprobado.

## Unknowns que condicionan
No bloquean totalmente, pero pueden limitar cambios o validación.

## Unknowns que sí bloquean
Lagunas que impedirían promover un cambio o declarar cumplimiento.

## Qué aclaración mínima haría falta para cerrar cada unknown bloqueante
No dejar esta parte vaga.

### Estado
- `abierta | parcial | cerrada`

---

## 13. Trabajo permitido vs trabajo fuera de alcance

Esta sección sirve para decidir el siguiente paso sin perder el marco.

## Cambios necesarios derivados del spec
Solo lo que el contrato realmente obliga a tocar.

## Cambios opcionales
Pueden ser razonables, pero no son necesarios para cumplir el flujo.

## Cambios explícitamente fuera de alcance
Limpiezas, refactors oportunistas, ampliaciones no aprobadas, mejoras laterales, trabajo vecino, etc.

## Qué no debe tocarse por ahora
Partes que conviene dejar quietas para no meter deriva metodológica.

## Criterio para aceptar un cambio nuevo dentro de este flujo
Un cambio solo entra si:
1. toca una cláusula del contrato o una divergencia real;
2. puede mapearse a una superficie concreta;
3. tiene validación derivada del spec;
4. no mete trabajo lateral no aprobado.

### Estado
- `operativamente clara | parcial | abierta`

---

## 14. Marco para decidir el siguiente paso

Esta es la sección que más te va a servir cuando quieras pedirle a la IA que implemente algo nuevo.

## Si quiero introducir una nueva función dentro de este flujo
Antes de tocar código, responder:

### 1. Qué parte del contrato toca
- <cláusula o garantía afectada>

### 2. Qué tipo de cambio es
- `alineación con spec`
- `cierre de gap`
- `nueva capacidad dentro del alcance`
- `cambio opcional`
- `fuera de scope`

### 3. Qué superficies principales toca
- <archivo / función / módulo>

### 4. Qué superficies secundarias podrían verse afectadas
- <archivo / test / config>

### 5. Qué invariants no pueden romperse
- <lista>

### 6. Qué validaciones obligatorias deben correr
- <lista>

### 7. Qué unknowns podrían afectar este cambio
- <lista>

### 8. Qué seam o legacy puede arrastrar comportamiento viejo
- <lista>

### 9. Qué evidencia mínima necesitaré para darlo por bueno
- <tests / run / observación>

### 10. Qué sería scope creep en este cambio
- <lista>

### Estado
- `lista para decidir | parcial | abierta`

---

## 15. Protocolo de cambio del flujo

Cuando este flujo cambie:

1. actualizar primero este documento;
2. actualizar después el código mínimo necesario;
3. actualizar después validación y evidencia;
4. registrar divergencias cerradas o nuevas;
5. no introducir comportamiento nuevo no descrito aquí;
6. no convertir detalles accidentales del código en contrato sin decisión explícita;
7. no declarar cumplimiento sin evidencia observable suficiente.

## Regla de implementación
Nadie debería implementar primero y justificar después.
Todo cambio debe poder decir:
- qué cláusula toca;
- dónde vive en el código;
- qué valida;
- qué no toca.

### Estado
- `operativamente clara | parcial | abierta`

---

## 16. Criterio de cumplimiento

Este flujo cumple cuando puede sostenerse con evidencia que:

- entra por la superficie visible correcta;
- respeta sus preconditions contractuales;
- trata correctamente sus inputs;
- ejecuta verificaciones y guards en el orden exigido;
- produce los outputs observables comprometidos;
- no rompe invariants;
- falla de manera consistente con sus failure modes;
- mantiene sus side effects dentro del contrato;
- conserva la validez de su suite obligatoria;
- no depende de supuestos prohibidos.

## Cumplimiento mínimo
Qué debe ser cierto para declararlo suficiente.

## Cumplimiento deseable
Qué aumentaría confianza sin ser requisito mínimo.

## Falsa apariencia de cumplimiento
Qué señales no bastan por sí solas.

### Estado
- `clara | parcial | abierta`

---

## 17. Criterio de terminado

Este documento está suficientemente cerrado cuando:

- el flujo puede entenderse sin abrir cuatro plantillas separadas;
- no hay duplicación fuerte entre comportamiento real, contrato, anclaje y gobierno de cambios;
- quedan separados con claridad:
  - hechos observados,
  - contrato aprobado,
  - anclaje a código,
  - gaps,
  - unknowns,
  - trabajo permitido,
  - trabajo fuera de alcance;
- una IA puede decidir el siguiente paso sin reabrir discovery ni reescribir la spec;
- cualquier cambio futuro puede trazarse a:
  - una cláusula del contrato,
  - una superficie concreta,
  - una validación obligatoria.

### Estado
- `cerrada | parcial | abierta`

---

## 18. Historial de revisión del flujo

Registrar cambios importantes del flujo o del contrato.

### <yyyy-mm-dd>
- tipo:
  - `discovery`
  - `contrato`
  - `anclaje`
  - `validación`
  - `implementación`
  - `cierre de drift`
- cambio:
  - <qué cambió>
- motivo:
  - <por qué>
- impacto:
  - <qué se movió en contrato, código o validación>
- evidencia:
  - <tests, corridas, archivos>

---

## 19. Apéndice opcional: plantilla de snapshot para pedirle trabajo a la IA

Usa este bloque cuando quieras pedir un cambio nuevo dentro del flujo sin volver a pegar todo el documento:

### Pedido de cambio
- qué quiero cambiar:
  - <pedido>
- por qué:
  - <motivo>
- cláusula del flow afectada:
  - <cláusula>
- superficies probables:
  - <archivos>
- validaciones mínimas esperadas:
  - <tests o corridas>
- fuera de alcance explícito:
  - <lista>
- unknowns relevantes:
  - <lista>

La IA debe responder primero:
1. si el pedido cae dentro o fuera del scope;
2. qué cláusulas del flow toca;
3. qué archivos principales tocaría;
4. qué no tocaría;
5. qué validación obligatoria exigiría;
6. si falta aclaración o si ya puede proponerse el siguiente paso.
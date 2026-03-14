# Plantilla: spec-anchored

## Propósito

Mapear el contrato intencional del flujo contra el código real antes de cambiar comportamiento.

Actúa como coordinador metodológico estricto de la fase spec-anchored. No eres implementador, no eres refactorizador, no eres redactor final de tests y no eres quien reescribe el contrato desde cero. Tu función es tomar el flujo ya entendido en discovery y el contrato ya redactado en spec-first, y anclarlos explícitamente al código real: entrypoints, dispatchers, funciones, módulos, ramas, side effects, seams, huecos y divergencias.

## Secciones

### Flow id
`git-acp-devbox`

Instrucción operativa:
Usa el mismo flow id heredado desde discovery y spec-first. No lo cambies salvo que se haya redefinido el flujo de forma explícita.

**Contenido**
- Se mantiene el mismo flow id heredado desde discovery y spec-first.
- El flujo anclado es la entrada visible `git acp "<texto_aquí>"` dentro de `devbox`, aterrizando en el ACP local del repo.

**Estado:** anclada

---

### Intención contractual de referencia
Qué parte del spec-first estamos tratando de anclar.

Instrucción operativa:
Resume la intención y el contrato visible relevantes para esta fase. No reescribas todo el spec-first; trae solo la parte necesaria para mapearla al código real. Debe servir como autoridad funcional del anclaje.

**Contenido**
- `git acp "<texto_aquí>"` debe funcionar como entrada visible al ACP local del repo dentro de `devbox`.
- `"<texto_aquí>"` es obligatorio y debe tratarse como mensaje principal del operador.
- Antes de commit o push deben ejecutarse las verificaciones y decisiones operativas propias del repo.
- No debe existir ningún side effect persistente antes de `check_superrepo_guard`.
- Debe existir una modalidad segura de simulación sin commit ni push efectivos.
- El cierre observable del flujo puede validarse con una señal visible compuesta; no requiere marcador terminal único.
- El flujo debe ser válido desde cualquier subdirectorio del repo `/webapps/ihh-devtools`.
- La validación Bats del flujo completo es obligatoria.

**Estado:** anclada

---

### Entry point real anclado
Comando, script, función o archivo donde empieza el flujo en el código real.

Instrucción operativa:
Debe quedar apoyado en evidencia concreta: path, función, script, main, subcomando, handler o router real. Si el entrypoint contractual y el real difieren, dilo explícitamente.

**Contenido**
- Entry visible/runtime sostenido por código:
  - `devbox.json:79`
  - `devbox.json:91`
- Ahí se inyecta `alias.acp` en `GIT_CONFIG_*` y el wrapper ejecuta el script local.
- Entry local concreto del repo:
  - `bin/git-acp.sh:1`
- Handler inicial real:
  - cuerpo top-level de `bin/git-acp.sh`
- El entrypoint contractual y el real quedan alineados:
  - `git acp` dentro de `devbox` aterriza en `bin/git-acp.sh`

**Estado:** anclada

---

### Dispatcher chain real anclada
Cadena ordenada de handoff desde la entrada hacia funciones o archivos más profundos.

Instrucción operativa:
Lista la cadena real de delegación observada en el código. Distingue entre cadena principal, wrappers y desvíos. No metas ramas raras salvo que afecten de verdad el cumplimiento del contrato.

**Contenido**
- Cadena principal:
  - `git acp`
  - alias efímero inyectado por `devbox.json`
  - wrapper inline / `exec bash`
  - `bin/git-acp.sh`
  - `source` de:
    - `lib/core/utils.sh`
    - `lib/core/config.sh`
    - `lib/git-flow.sh`
    - `lib/ssh-ident.sh`
    - `lib/ci-workflow.sh`
- La cadena contractual y la real quedan alineadas.
- El seam runtime de `devbox` sigue existiendo, pero ya no bloquea la transición de fase.

**Estado:** anclada

---

### Mapa de camino feliz
Correspondencia entre pasos del camino feliz contractual y funciones/archivos reales.

Instrucción operativa:
Por cada paso importante del camino feliz, indica dónde vive hoy en el código o si todavía no está claramente anclado. Esta sección debe ayudar a ver rápidamente si el contrato tiene soporte real o si está distribuido de forma difusa.

**Contenido**
- Parseo del input principal:
  - `bin/git-acp.sh:109`
- Validación de repo Git utilizable:
  - `bin/git-acp.sh:119`
- Guard de seguridad:
  - `lib/core/utils.sh:382`
- Aplicación diferida de side effects persistentes de config:
  - `lib/core/config.sh`
  - invocación posterior desde `bin/git-acp.sh`
- Decisión de rama:
  - `lib/git-flow.sh:57`
- Identidad:
  - `lib/ssh-ident.sh`
- Commit:
  - `bin/git-acp.sh`
- Push:
  - `bin/git-acp.sh`
- Post-push:
  - `lib/ci-workflow.sh:546`
- Cierre/progreso:
  - `lib/core/utils.sh:429`
- Simulación visible:
  - `lib/core/utils.sh:464`
- Camino feliz contractual ya alineado con el código tras los cambios aplicados.

**Estado:** anclada

---

### Preconditions ancladas
Dónde y cómo se validan o asumen las preconditions.

Instrucción operativa:
Mapea cada precondition relevante a código real, o marca si hoy no se valida como debería. Distingue entre validación explícita, supuesto implícito y ausencia de soporte.

**Contenido**
- Contexto Git utilizable del repo:
  - validación explícita en `bin/git-acp.sh:119`
- Guard del repo:
  - `lib/core/utils.sh:382`
- Sesión válida de `devbox`:
  - sostenida por el runtime observado y por `devbox.json`
- Cwd:
  - contrato ya relajado
  - el flujo es válido desde cualquier subdirectorio del repo
  - eso queda alineado con la resolución dinámica de raíz usada por el código
- No-TTY:
  - sigue siendo tolerancia observada
  - no es una precondition positiva contractual

**Estado:** anclada

---

### Inputs anclados
Dónde entran, se parsean, validan y transforman las entradas.

Instrucción operativa:
Mapea flags, argumentos, variables de entorno, archivos, config y cualquier otro input relevante. Distingue entre aceptación contractual, tolerancia accidental y parsing incidental.

**Contenido**
- Input principal:
  - `bin/git-acp.sh:109`
- Mensaje obligatorio:
  - ahora se valida y se rechaza la ejecución si falta
  - ya no existe la tolerancia del modo interactivo como sustituto del mensaje
- Flags con efecto real:
  - `--dry-run`
  - otros flags internos siguen existiendo, pero no amplían el contrato visible
- Config/perfiles:
  - `lib/core/config.sh`
  - `lib/ssh-ident.sh`
- El input principal y su obligatoriedad ya quedaron alineados con el contrato.

**Estado:** anclada

---

### Outputs anclados
Dónde se generan o exponen los resultados esperados.

Instrucción operativa:
Incluye salidas observables, estado producido, archivos escritos, retorno, logs visibles relevantes o cambios de estado contractuales. Distingue entre output garantizado y output incidental.

**Contenido**
- Simulación visible:
  - `lib/core/utils.sh:464`
- Cierre/progreso:
  - `lib/core/utils.sh:429`
- Omisión/cierre posterior visible:
  - `lib/ci-workflow.sh`
- El contrato ya acepta una señal visible compuesta.
- En consecuencia:
  - la ausencia de un marcador terminal único deja de ser divergencia
  - el cierre observable del flujo queda suficientemente sostenido por la combinación de señales visibles existentes

**Estado:** anclada

---

### Side effects anclados
Git, red, sistema de archivos, subprocesos, cambios de entorno, etc.

Instrucción operativa:
Mapea side effects a funciones, comandos, librerías, wrappers o módulos específicos. Si un side effect importante del contrato no está localizado con claridad, debe quedar como gap.

**Contenido**
- Commit/push:
  - `bin/git-acp.sh`
- Post-push:
  - `lib/ci-workflow.sh:546`
- Side effect persistente de config global:
  - encapsulado y diferido en `lib/core/config.sh`
  - ya no ocurre antes de `check_superrepo_guard`
- Side effects de identidad/remotos:
  - `lib/ssh-ident.sh`
- Lo exigido por contrato quedó alineado:
  - ningún side effect persistente debe ocurrir antes del guard
  - esa divergencia ya quedó cerrada por cambio de código

**Estado:** anclada

---

### Invariants anclados
Dónde se sostienen o se arriesgan las condiciones invariantes del flujo.

Instrucción operativa:
Por cada invariant relevante, indica si el código actual lo sostiene claramente, lo sostiene solo parcialmente, lo viola o lo deja ambiguo. No uses esta sección para repetir outputs o failure modes.

**Contenido**
- Sostenidos claramente:
  - `"<texto_aquí>"` es obligatorio
  - simulación sin commit/push efectivos
  - verificaciones y guard antes de side effects persistentes
  - contexto Git válido
  - ejecución válida desde subdirectorio del repo
  - cierre visible compuesto suficiente
- Ya no quedan invariants centrales en conflicto para este flujo.

**Estado:** anclada

---

### Failure modes anclados
Dónde aparecen los fallos contractuales y cómo se materializan.

Instrucción operativa:
Distingue entre fallo contractual visible para el usuario y fallo interno de implementación. Mapea guards, branches, errores propagados, mensajes y salidas relevantes solo cuando correspondan al contrato.

**Contenido**
- Rechazo por falta de mensaje:
  - ahora existe y es visible
- Fallo por repo Git inválido:
  - sigue anclado
- Guard que bloquea la continuación:
  - sigue anclado
- Publicación principal no completada:
  - sigue anclado
- El failure mode de “falta de mensaje” ya quedó alineado con el contrato.
- El failure mode de “salida visible suficiente” ya no depende de un marcador único, sino de la señal compuesta aceptada contractualmente.

**Estado:** anclada

---

### Ramas importantes y seams de compatibilidad
Bifurcaciones relevantes, fallbacks, wrappers y compatibilidades heredadas.

Instrucción operativa:
Incluye solo ramas que alteren el cumplimiento del contrato o compliquen su futura implementación/control. Distingue claramente entre rama central, rama secundaria y seam heredado.

**Contenido**
- Rama central:
  - `--dry-run`
- Seams reales:
  - `DEVTOOLS_DISPATCH_DONE`
  - `LEGACY_VENDOR_CONFIG`
  - compat de rama deprecada en `lib/git-flow.sh`
  - fallbacks UI / `run_cmd` en `lib/ci-workflow.sh`
  - `DEVTOOLS_WIZARD_MODE` en `lib/core/config.sh`
- Unknowns sobre seams heredados permanecen como observación, no como bloqueo de fase.

**Estado:** anclada

---

### Divergencias entre spec y código
Dónde el contrato y el código real no coinciden.

Instrucción operativa:
Esta sección es clave. Debe señalar contradicciones reales, no solo diferencias de estilo. Incluye tanto “el código hace menos de lo que el contrato exige” como “el código hace más o algo distinto de lo que el contrato debería garantizar”.

**Contenido**
- Las divergencias principales identificadas durante spec-anchored quedaron resueltas por:
  - cambio de código
  - decisión contractual explícita del Arquitecto
  - validación Bats en verde
- Conflictos cerrados:
  - mensaje obligatorio
  - side effects persistentes tempranos
- Aclaraciones contractuales resueltas:
  - cwd relajado a cualquier subdirectorio del repo
  - señal visible compuesta aceptada
  - validación Bats del flujo completo exigida y ya ejecutada en verde
- No quedan divergencias centrales abiertas que bloqueen la transición a spec-as-source.

**Estado:** anclada

---

### Superficies reales de cambio
Archivos, funciones o módulos donde probablemente habrá que tocar si se promueve a spec-as-source.

Instrucción operativa:
No diseñes todavía el cambio; solo identifica dónde vive la responsabilidad real. Distingue entre superficie principal, superficie secundaria y zona de alto riesgo o dispersión.

**Contenido**
- Superficie principal:
  - `devbox.json`
  - `bin/git-acp.sh`
  - `lib/core/config.sh`
  - `lib/core/contract.sh`
  - `lib/core/utils.sh`
  - `lib/git-flow.sh`
  - `lib/ssh-ident.sh`
  - `lib/ci-workflow.sh`
- Superficie secundaria:
  - `devtools.repo.yaml`
  - `.devtools/.git-acprc`
  - `tests/03_git_acp_devbox.bats`
  - `tests/02_git_acp_post_push.bats`
- Zonas de riesgo siguen documentadas, pero no bloquean la transición.

**Estado:** anclada

---

### Unknowns
Qué todavía no está localizado o demostrado en el anclaje.

Instrucción operativa:
Todo hueco real del mapeo debe quedar aquí o marcado como parcial en su sección correspondiente. Nunca cierres una laguna de anclaje por intuición.

**Contenido**
- Otras ramas del post-push aparte de `skip`
- Peso real actual de `Compat` / `LEGACY_`
- Estabilidad futura de la inyección runtime de `alias.acp`
- Alcanzabilidad real de ramas laterales como reparación de remotos o `gh repo create`
- Cuánto del plano identidad/SSH/remotos/GitHub es soporte necesario vs desborde del contrato visible
- Estos unknowns permanecen documentados, pero no bloquean la transición a spec-as-source.

**Estado:** abierta

---

### Evidencia
Referencias concretas:
- paths de archivos
- nombres de funciones
- handlers
- scripts
- comandos
- ramas observadas
- corridas observadas si aplica

Instrucción operativa:
Cada afirmación importante del anclaje debe poder rastrearse a evidencia concreta del repo. Si una parte del mapa no tiene evidencia suficiente, márcala como parcial o unknown.

**Contenido**
- `devbox.json:79`
- `devbox.json:91`
- `bin/git-acp.sh:1`
- `bin/git-acp.sh:10`
- `bin/git-acp.sh:109`
- `bin/git-acp.sh:119`
- `lib/core/config.sh`
- `lib/core/contract.sh:173`
- `lib/core/utils.sh:382`
- `lib/core/utils.sh:429`
- `lib/core/utils.sh:464`
- `lib/git-flow.sh:57`
- `lib/ssh-ident.sh`
- `lib/ci-workflow.sh:546`
- `tests/03_git_acp_devbox.bats`
- `tests/02_git_acp_post_push.bats`
- Validación real en `devbox`:
  - `tests/03_git_acp_devbox.bats` en verde
  - `tests/02_git_acp_post_push.bats` en verde
- Discovery runtime correcto de `devbox`
- Validación segura `--dry-run`
- Validación de rama `skip`

**Estado:** anclada

---

### Criterio de salida para promover a spec-as-source
Qué falta resolver antes de usar el spec como fuente de implementación o ajuste.

Instrucción operativa:
No promociones por sensación. Debes escribir explícitamente:
- qué partes del contrato ya tienen anclaje suficiente;
- qué divergencias habrá que cerrar en la siguiente fase;
- qué superficies principales concentran el trabajo;
- qué unknowns no bloquean la promoción;
- qué conflictos o gaps sí bloquean el paso a spec-as-source;
- qué mínima aclaración faltaría si todavía no conviene promover.

**Contenido**
- Partes del contrato ya suficientemente ancladas:
  - entrada visible/runtime hacia el flujo local
  - repo Git válido
  - mensaje obligatorio
  - simulación segura
  - side effects persistentes solo después del guard
  - cwd válido desde cualquier subdirectorio del repo
  - cierre visible compuesto aceptado
  - validación Bats del flujo completo ya ejecutada en verde
- Divergencias centrales ya cerradas:
  - mensaje obligatorio vs modo interactivo
  - side effects persistentes tempranos
- Aclaraciones contractuales ya resueltas:
  - cwd exacto
  - marcador terminal único vs señal compuesta
  - validación Bats requerida
- Unknowns que no bloquean la promoción:
  - ramas no validadas del post-push
  - peso real de `Compat` / `LEGACY_`
  - estabilidad futura del alias runtime
- Conflictos o gaps que sí bloquean el paso a spec-as-source:
  - ninguno de los conflictos centrales previamente abiertos sigue bloqueando
- Resultado:
  - `spec-anchored` queda cerrada sin ambigüedad
  - la promoción a `spec-as-source` queda habilitada

**Estado:** anclada

## Formato obligatorio de trabajo durante todo spec-anchored

Estado actual
- Bloque actual: Bloque 7 cerrado
- Objetivo del bloque: cerrar spec-anchored con ficha final consolidada
- Pregunta de anclaje que estamos resolviendo: ¿qué parte del contrato ya quedó realmente sostenida por el código, qué parte quedó solo parcial o en conflicto, y qué impide promover limpiamente a spec-as-source?

Hallazgos de anclaje ya claros
- El mapa spec -> código quedó consolidado de punta a punta.
- La entrada visible, el core path ACP, el repo Git válido, el mensaje obligatorio, la simulación segura y el orden de side effects persistentes ya quedaron alineados.
- La validación Bats del flujo completo ya fue ejecutada en verde dentro de `devbox`.
- Las decisiones contractuales del Arquitecto ya quedaron documentadas y aterrizadas en código y spec.

Anclajes parciales o dispersos
- La superficie identidad/SSH/remotos/GitHub sigue siendo amplia y con seams heredados.
- Las ramas adicionales de post-push más allá de `skip` siguen fuera de la validación mínima del flujo.
- La estabilidad futura del alias runtime de `devbox` sigue siendo unknown operativo.

Divergencias con el contrato
- Las divergencias centrales detectadas durante spec-anchored ya fueron resueltas.
- No queda lenguaje vigente de “bloqueo” para la transición a spec-as-source.
- Los unknowns residuales no constituyen divergencias bloqueantes.

Qué podemos dejar fuera por ahora
- refactor general
- limpieza amplia de legacy
- expansión completa del menú post-push
- rediseño del flujo
- nuevas ampliaciones de interfaz no decididas por negocio

Condición para pasar al siguiente bloque
- Cumplida.
- `spec-anchored` queda cerrada.
- `spec-as-source` queda habilitada para continuar como fuente de verdad.

Regla final:
Spec-anchored solo queda bien hecho si esta plantilla permite responder con claridad a la pregunta:
“¿Qué parte del contrato ya está realmente sostenida por el código, dónde vive cada responsabilidad y qué divergencias concretas habrá que enfrentar antes de usar el spec como fuente?”
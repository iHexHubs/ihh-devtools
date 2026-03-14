# Flow: git-acp-devbox

- maturity: spec-as-source
- status: approved
- priority: high
- source-of-truth: this file
- owner: por-definir
- reviewers:
  - arquitectura
  - codex
- related-tests:
  - tests/03_git_acp_devbox.bats
  - tests/02_git_acp_post_push.bats
- related-flows:
  - none
- last-updated: 2026-03-10
- last-validated: 2026-03-10 (runtime correcto en devbox + Bats reportado en verde)

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
`git-acp-devbox`

### Nombre corto
`git acp en devbox para ihh-devtools`

### Trigger visible
Ejecución de `git acp "<texto_aquí>"` dentro de una sesión válida de `devbox`, desde cualquier subdirectorio válido del repo `/webapps/ihh-devtools`.

### Objetivo operativo
Permitir que un operador use `git acp "<texto_aquí>"` como entrada visible al flujo ACP local del repo `ihh-devtools`, tomando `"<texto_aquí>"` como mensaje principal, aplicando verificaciones y decisiones propias del repo antes de producir efectos persistentes, con soporte de simulación segura.

### Resultado esperado a alto nivel
Cuando sale bien, el flujo resuelve al ACP local del repo, trata el mensaje como base semántica principal, ejecuta verificaciones previas, realiza commit/publicación dentro de su alcance o recorre una ruta segura de simulación, y deja una salida visible que permite distinguir entre ejecución efectiva, simulación y cierre u omisión de etapa posterior.

### Alcance del flujo
- La entrada visible `git acp "<texto_aquí>"` en `devbox`.
- La resolución efectiva hacia el ACP local del repo.
- El núcleo local auditado en `bin/git-acp.sh` y su cadena principal de librerías.
- La modalidad segura de simulación.
- El orden de verificaciones, guardas y side effects persistentes.
- La validación mínima observable del flujo completo.
- La validez desde cualquier subdirectorio del repo.

### Fuera de alcance
- Explicar Git en general.
- Convertir detalles accidentales del alias o de consola en contrato.
- Congelar el formato literal del commit enriquecido.
- Garantizar todas las ramas posibles del post-push.
- Rediseñar ACP, post-push, identidad/SSH o tooling lateral.
- Basar el flujo en aliases globales del host o en entornos fuera de `devbox`.
- Limpiar legacy o compatibilidades heredadas sin necesidad contractual.

### Estado
- `confirmada`

---

## 2. Resumen consolidado del flujo

## Qué debe entender alguien en menos de un minuto

Este flujo es la entrada visible `git acp "<texto_aquí>"` usada dentro de `devbox` para el repo `ihh-devtools`. En runtime correcto, no debe resolver a un alias global del host, sino a un alias `alias.acp` inyectado por `devbox` vía `GIT_CONFIG_*`, que delega al script local `bin/git-acp.sh`. El input principal es `"<texto_aquí>"`, que entra por `"$@"`, se preserva como base semántica del mensaje principal y conduce el tramo ACP del repo. El núcleo local auditado carga configuración del repo, ejecuta guardas y verificaciones, decide condiciones operativas relevantes, y luego puede producir side effects persistentes como staging, commit, push y tramo post-push. La ruta segura `--dry-run` quedó observada sin commit ni push efectivos. El cierre observable del flujo no depende de un marcador terminal único, sino de una señal visible suficiente que distingue ejecución efectiva, simulación u omisión/cierre. Lo observado en runtime confirma la resolución correcta en una sesión válida de `devbox` y una ruta segura real; lo auditado localmente confirma la columna vertebral completa del flujo, incluyendo commit, push y post-push; lo ya elevado a contrato fija mensaje obligatorio, guardas previas a side effects persistentes, simulación segura, resolución local en `devbox`, validez desde subdirectorio y salida visible suficiente; lo que sigue abierto son ramas del post-push distintas de `skip`, el peso real de piezas `Compat`/`LEGACY_`, y la estabilidad futura exacta de la inyección runtime del alias.

### Estado
- `confirmada`

---

## 3. Autoridad metodológica de este documento

## Qué partes ya quedaron absorbidas aquí

### Discovery absorbido
- Quedó absorbido que el trigger observado relevante es `git acp "<texto_aquí>"` dentro de `devbox`.
- Quedó absorbido que el runtime correcto resuelve por `alias.acp` inyectado vía `GIT_CONFIG_*`.
- Quedó absorbido que la resolución efectiva aterriza en `bin/git-acp.sh`.
- Quedó absorbido el camino feliz auditado localmente y la ruta segura observada con `--dry-run`.
- Quedó absorbida la distinción entre:
  1. runtime real observado en sesión válida de `devbox`;
  2. núcleo local auditado dentro del repo.
- Quedó absorbida la contradicción previa con el alias global como evidencia de una sesión no equivalente.

### Spec-first absorbido
- Quedó absorbida la intención contractual del flujo.
- Quedó absorbido que el usuario puede asumir resolución local al ACP del repo.
- Quedó absorbido que el mensaje principal es obligatorio.
- Quedó absorbido que existen verificaciones previas a side effects persistentes.
- Quedó absorbida la exigencia de simulación segura.
- Quedó absorbido que la salida visible debe distinguir estado final de manera comprensible.
- Quedó absorbido qué no forma parte del contrato visible.

### Spec-anchored absorbido
- Quedó absorbido el anclaje del entrypoint visible en `devbox.json`.
- Quedó absorbido el anclaje del entrypoint local en `bin/git-acp.sh`.
- Quedó absorbido el mapa de responsabilidades sobre `lib/core/config.sh`, `lib/core/utils.sh`, `lib/git-flow.sh`, `lib/ssh-ident.sh` y `lib/ci-workflow.sh`.
- Quedó absorbido el orden contractual de guardas y side effects persistentes.
- Quedó absorbido que la validación Bats mínima del flujo completo ya fue reportada en verde.

### Spec-as-source absorbido
- Quedó absorbido que el spec manda sobre intuiciones del chat y sobre accidentalidades del código.
- Quedó absorbido qué trabajo está autorizado y qué trabajo está fuera de alcance.
- Quedó absorbida la validación obligatoria mínima para afirmar cumplimiento.
- Quedó absorbido el criterio de cumplimiento y el criterio de terminado.
- Quedó absorbido que futuras intervenciones solo deben tocar la superficie estrictamente necesaria para una cláusula del contrato o para una divergencia real.

### Regla de autoridad
A partir de este punto:
- este documento manda sobre recuerdos del chat;
- el contrato aprobado manda sobre comportamientos accidentales del código;
- los unknowns no pueden reescribirse como certezas;
- los seams heredados no amplían por sí mismos el scope;
- ningún cambio debe justificarse “porque el código ya lo hace” si contradice este documento.

### Estado
- `operativamente clara`

---

## 4. Comportamiento real observado

## Runtime real observado
- Trigger real observado: `git acp "<texto_aquí>"` y, en validación segura, `git acp --dry-run 'codex-block-reopen-devbox' </dev/null`.
- Entorno real observado: sesión válida de `devbox` correctamente cargada.
- Cwd real observado: `/webapps/ihh-devtools`.
- Resolución real del entrypoint:
  - `git acp` resolvió por `alias.acp` de scope `command`;
  - el alias fue inyectado por `devbox` vía `GIT_CONFIG_*`;
  - el wrapper delegó en `bin/git-acp.sh`.
- Outputs visibles observados en runtime correcto:
  - `🟢 [ihh-devtools] Ejecutando git-acp...`
  - `⚠️  Sin TTY: omitiendo selector interactivo de identidad.`
  - `⚗️  Simulación (--dry-run).`
- Side effects observados o ausencia de side effects:
  - con `git acp --dry-run ... </dev/null` no hubo commit ni push efectivos;
  - en la rama `skip` del post-push se observó `👌 Omitido.` y `RC=0`;
  - en la sesión correcta de `devbox`, la resolución local fue inyectada en memoria por `GIT_CONFIG_*`;
  - en la sesión no equivalente previa, el alias global intentó tocar `/home/reydem/.gitconfig` y falló por permisos.
- Corridas relevantes observadas:
  - `env | rg '^GIT_CONFIG|^DEVBOX|^PWD='`
  - `git config --show-origin --show-scope --get-regexp '^alias\.acp$'`
  - `GIT_TRACE=1 git acp --dry-run 'codex-block-reopen-devbox' </dev/null`
  - `bash ./bin/git-acp.sh --dry-run 'codex-block6-validacion-segura'`
  - validación interactiva de `run_post_push_flow ...` en la rama `skip`

## Núcleo local auditado
- Entrypoint local: `bin/git-acp.sh`.
- Cadena principal de dispatch:
  - `bin/git-acp.sh`
  - `lib/core/config.sh`
  - `lib/core/utils.sh`
  - `lib/git-flow.sh`
  - `lib/ssh-ident.sh`
  - `lib/ci-workflow.sh`
- Funciones o módulos centrales:
  - parseo de input y flags en `bin/git-acp.sh`
  - guard en `check_superrepo_guard`
  - carga/config en `lib/core/config.sh`
  - identidad en `lib/ssh-ident.sh`
  - decisión de rama en `lib/git-flow.sh`
  - post-push en `lib/ci-workflow.sh`
  - cierre/progreso en `lib/core/utils.sh`
- Punto de cierre del flujo auditado: `show_daily_progress`.
- Ramas relevantes auditadas:
  - `--dry-run`
  - omisión de selector interactivo sin TTY
  - bypass del guard con `--force` / `--i-know-what-im-doing`
  - cambio o validación de rama
  - fallback de push con `pull --rebase`
  - rama `skip` del post-push
- Side effects posibles auditados:
  - carga de config local
  - posible mutación de `git config` local por identidad
  - `git add .`
  - `git commit`
  - `git push`
  - `git push -u`
  - `git pull --rebase`
  - `git fetch --tags --force`
- Inputs reales que atraviesan el flujo:
  - `"$@"`
  - `"<texto_aquí>"`
  - flags como `--dry-run`
  - rama actual
  - TTY / no-TTY
  - config `.devtools/.git-acprc`

## Dispatcher chain consolidada
`git acp` → `alias.acp` inyectado en `command` vía `GIT_CONFIG_*` → wrapper shell inline / `exec bash` → `bin/git-acp.sh` → `source` de `lib/core/utils.sh`, `lib/core/config.sh`, `lib/git-flow.sh`, `lib/ssh-ident.sh`, `lib/ci-workflow.sh` → tramo commit/push/post-push → `show_daily_progress`

## Camino feliz consolidado
1. El operador ejecuta `git acp "<texto_aquí>"` en una sesión válida de `devbox`.
2. `devbox` inyecta `alias.acp` vía `GIT_CONFIG_*`.
3. `git acp` aterriza en el wrapper inline y delega en `bin/git-acp.sh`.
4. El script parsea flags y arma el mensaje principal a partir de `"$@"`.
5. Carga configuración del repo.
6. Verifica contexto Git utilizable.
7. Ejecuta `check_superrepo_guard`.
8. Configura o resuelve identidad según corresponda.
9. Verifica o ajusta rama según la lógica del flujo.
10. En ejecución efectiva, realiza staging/commit/push.
11. Entra a `run_post_push_flow`.
12. Cierra mostrando progreso/estado final con señal visible suficiente.
13. En simulación, recorre la ruta segura sin commit ni push efectivos.

## Ramas importantes
- `--dry-run`: ruta segura, sin commit ni push efectivos.
- sin TTY: se omite selector interactivo de identidad.
- `--force` / `--i-know-what-im-doing`: desactivan el guard.
- rama protegida o `HEAD` detached: altera lógica de rama.
- fallo de push: puede intentar `pull --rebase`.
- post-push:
  - rama `skip` observada en runtime;
  - otras ramas siguen abiertas como unknown.

## Side effects reales
- Inyección runtime de alias por `devbox` vía `GIT_CONFIG_*`.
- Carga de config local del repo.
- Posible mutación de `git config` local por identidad.
- Staging, commit y push en ejecución efectiva.
- Posibles acciones de red Git como fetch/push/pull.
- Post-push con menú/ramas posteriores.
- En simulación segura observada, ausencia de commit y push efectivos.

## Preconditions reales observadas
- Sesión real de `devbox` correctamente cargada.
- Repo `ihh-devtools` activo y cwd dentro de `/webapps/ihh-devtools`.
- Contexto Git utilizable.
- Alias `alias.acp` inyectado en memoria por `devbox`.
- Existencia de `bin/git-acp.sh`.
- Para la ruta segura observada: `--dry-run` y no-TTY.

## Error modes observados
- Sesión no equivalente: resolución al alias global `!~/scripts/git-acp.sh`.
- Falla previa por intento de tocar `/home/reydem/.gitconfig`.
- Omisión de selector de identidad sin TTY.
- Error sustentado por código si no hay repo Git válido.
- Error sustentado por código si el guard bloquea la continuación.
- Error sustentado por código si push/rebase falla.
- Posibles fallos en ramas laterales del post-push dependientes de tooling no disponible.

### Estado
- `confirmada`

---

## 5. Contrato canónico del flujo

Esta sección ya no describe solo lo que hoy ocurre.
Describe lo que el flujo aprobado **debe garantizar**.

## Intención contractual
El flujo debe funcionar como entrada visible al ACP local del repo `ihh-devtools` dentro de `devbox`, tomando `"<texto_aquí>"` como mensaje principal, aplicando verificaciones y decisiones operativas propias del repo antes de producir efectos persistentes, ofreciendo una modalidad segura de simulación y cerrando con una señal visible suficiente sobre su estado final.

## Contrato visible para el usuario
- `git acp "<texto_aquí>"` en `devbox` debe resolver al ACP local del repo.
- El mensaje principal del operador es obligatorio.
- El flujo aplica verificaciones y decisiones propias del repo antes de efectos persistentes.
- Debe existir una modalidad segura de simulación sin commit ni push efectivos.
- En ejecución efectiva exitosa, el flujo debe completar la publicación principal dentro de su alcance.
- La salida visible debe permitir distinguir entre ejecución efectiva, simulación y cierre u omisión general.
- El contrato visible no depende de alias exactos, scripts exactos, textos literales de consola, formato literal del commit ni ramas concretas del post-push.

## Preconditions contractuales
- El flujo solo es válido dentro del contexto operativo de `devbox` asociado a `ihh-devtools`.
- El flujo debe ser válido desde cualquier subdirectorio del repo.
- No depende contractualmente de aliases globales del host.
- Debe existir un contexto Git utilizable del repo.
- Una sesión válida de `devbox` es aquella en la que `git acp` resuelve al ACP local del repo.
- El soporte sin TTY no es una precondition positiva del contrato; es una tolerancia observada.

## Inputs contractuales
- Obligatorio:
  - mensaje textual principal aportado por el operador.
- Aceptado contractualmente:
  - una modalidad segura de simulación.
- Tolerado pero no elevado a interfaz visible estable:
  - flags internos adicionales.
- No prometido:
  - la superficie completa accidental de flags hoy aceptados.
- Exigencia contractual sobre el mensaje:
  - preservación semántica principal, no literalidad exacta.

## Outputs contractuales
- Resultado visible para el operador.
- Distinción visible entre:
  - ejecución efectiva
  - simulación
  - cierre u omisión general
- En ejecución efectiva exitosa:
  - commit coherente con el mensaje principal
  - publicación principal completada dentro del alcance
- En simulación:
  - recorrido visible de ruta segura sin commit ni push efectivos
- No garantizado:
  - texto exacto de consola
  - emojis
  - banners
  - formato exacto del commit enriquecido
  - una rama concreta del post-push
  - un marcador terminal único

## Invariants obligatorios
- `git acp "<texto_aquí>"` en `devbox` debe resolver al flujo local del repo.
- `"<texto_aquí>"` debe tratarse como mensaje principal durante toda la operación.
- La integridad exigida del mensaje es semántica principal.
- Deben ejecutarse verificaciones y guardas del repo antes de side effects persistentes.
- En simulación no debe haber commit ni push efectivos.
- La ejecución debe terminar con una señal visible y comprensible.
- El flujo debe seguir siendo válido desde cualquier subdirectorio del repo.
- El contrato no depende de detalles internos frágiles.

## Failure modes contractuales
- Resolución fuera del ACP local del repo:
  - rompe la promesa principal de entrada visible.
- Falta de mensaje principal:
  - el flujo no tiene insumo mínimo y debe cortar antes de side effects persistentes.
- Repo Git no válido:
  - el flujo no puede operar como ACP del proyecto.
- Verificación/guard bloquea:
  - el estado del repo no permite continuar.
- Simulación con side effects persistentes reales:
  - rompe una garantía fuerte del contrato.
- Salida no visible o engañosa:
  - rompe la observabilidad mínima prometida.
- Ejecución efectiva anunciada sin publicación principal completada:
  - inconsistencia entre resultado visible y efecto comprometido.

## No-goals
- No explicar Git general.
- No estabilizar la cadena técnica interna de resolución.
- No prometer todos los flags hoy tolerados.
- No fijar UI exacta, textos exactos ni formato exacto del commit.
- No garantizar todas las ramas del post-push.
- No corregir sesiones mal cargadas fuera del contexto operativo definido.
- No absorber contratos de identidad/SSH/remotos/GitHub más allá de lo necesario para este flujo visible.

## Supuestos prohibidos
Nadie debe apoyarse en:
- detalles accidentales del alias;
- textos literales de consola;
- formato exacto incidental del commit;
- ramas no contractualizadas del post-push;
- tooling lateral no cerrado como interfaz visible;
- que la rama `skip` equivalga a cobertura total del post-push;
- que validar solo `bash ./bin/git-acp.sh` equivalga a validar `git acp` en `devbox`;
- que el runtime global del host sea base aceptable del flujo.

### Estado
- `clara`

---

## 6. Mapa explícito entre contrato y código

Esta es la parte que evita que la spec flote sin anclaje.

## Entry point real anclado
- Trigger visible:
  - `git acp "<texto_aquí>"`
- Archivo real del runtime visible:
  - `devbox.json:79`
  - `devbox.json:91`
- Wrapper o handler inicial:
  - alias `alias.acp` inyectado vía `GIT_CONFIG_*`, wrapper inline / `exec bash`
- Archivo real del núcleo local:
  - `bin/git-acp.sh:1`
- Evidencia exacta que sostiene el anclaje:
  - runtime observado en `devbox` mostró `GIT_CONFIG_KEY_0=alias.acp`
  - `GIT_CONFIG_VALUE_0` delegando a `"/webapps/ihh-devtools/bin/git-acp.sh"`
  - `GIT_TRACE=1 git acp --dry-run ...` mostró ejecución del wrapper hacia `bin/git-acp.sh`

## Code anchors por responsabilidad

### Resolución local del flujo en devbox
- cláusula: `git acp` debe resolver al ACP local del repo y no a una resolución global ajena.
- ancla principal:
  - `devbox.json:79`
  - `devbox.json:91`
- anclas secundarias:
  - `bin/git-acp.sh:1`
- cómo se sostiene hoy:
  - `devbox` inyecta `alias.acp` vía `GIT_CONFIG_*` y el wrapper delega al script local.
- estado:
  - `anclada`

### Mensaje principal obligatorio
- cláusula: el flujo exige `"<texto_aquí>"` como mensaje principal.
- ancla principal:
  - `bin/git-acp.sh:109`
- anclas secundarias:
  - `lib/core/contract.sh:173`
- cómo se sostiene hoy:
  - el script parsea el input principal y el contrato anclado ya reporta rechazo visible si falta mensaje.
- estado:
  - `anclada`

### Contexto Git válido
- cláusula: el flujo solo opera con un contexto Git utilizable del repo.
- ancla principal:
  - `bin/git-acp.sh:119`
- anclas secundarias:
  - `lib/core/utils.sh:382`
- cómo se sostiene hoy:
  - el script valida repo Git utilizable antes de continuar con el tramo ACP útil.
- estado:
  - `anclada`

### Guard previo a side effects persistentes
- cláusula: no debe existir side effect persistente antes de `check_superrepo_guard`.
- ancla principal:
  - `lib/core/utils.sh:382`
- anclas secundarias:
  - `bin/git-acp.sh`
  - `lib/core/config.sh`
- cómo se sostiene hoy:
  - el orden contractual quedó alineado; la config persistente se aplica de forma diferida y el guard ocurre antes del tramo persistente.
- estado:
  - `anclada`

### Simulación segura
- cláusula: debe existir una modalidad segura sin commit ni push efectivos.
- ancla principal:
  - `lib/core/utils.sh:464`
- anclas secundarias:
  - `bin/git-acp.sh`
- cómo se sostiene hoy:
  - `--dry-run` deja visible la simulación y evita commit/push efectivos.
- estado:
  - `anclada`

### Decisión de rama y gating operativo
- cláusula: antes de commit/push deben ejecutarse decisiones operativas propias del repo.
- ancla principal:
  - `lib/git-flow.sh:57`
- anclas secundarias:
  - `bin/git-acp.sh`
- cómo se sostiene hoy:
  - el flujo consulta o ajusta el estado de rama como parte de la operación ACP.
- estado:
  - `anclada`

### Identidad operativa
- cláusula: la identidad y soporte asociado pueden intervenir, pero no deben romper el contrato visible.
- ancla principal:
  - `lib/ssh-ident.sh`
- anclas secundarias:
  - `lib/core/config.sh`
- cómo se sostiene hoy:
  - el plano de identidad existe y se integra en el flujo; sin TTY puede omitirse selector interactivo.
- estado:
  - `parcial`

### Commit y publicación principal
- cláusula: en ejecución efectiva exitosa debe existir resultado ACP observable coherente con el mensaje principal.
- ancla principal:
  - `bin/git-acp.sh`
- anclas secundarias:
  - `lib/ci-workflow.sh:546`
- cómo se sostiene hoy:
  - `bin/git-acp.sh` concentra commit/push y delega el tramo post-push a `lib/ci-workflow.sh`.
- estado:
  - `anclada`

### Cierre visible suficiente
- cláusula: el flujo debe terminar con una señal visible suficiente, sin exigir marcador terminal único.
- ancla principal:
  - `lib/core/utils.sh:429`
- anclas secundarias:
  - `lib/ci-workflow.sh:546`
  - `lib/core/utils.sh:464`
- cómo se sostiene hoy:
  - la combinación de simulación visible, progreso/cierre y ramas de post-push satisface la observabilidad mínima.
- estado:
  - `anclada`

### Validez desde subdirectorio del repo
- cláusula: el flujo debe ser válido desde cualquier subdirectorio del repo.
- ancla principal:
  - `devbox.json`
  - `bin/git-acp.sh`
- anclas secundarias:
  - lógica de resolución dinámica de raíz del repo
- cómo se sostiene hoy:
  - la spec-anchored ya dejó aceptado y alineado este punto con la resolución dinámica del código.
- estado:
  - `anclada`

## Mapeo del camino feliz al código
1. Entrada visible:
   - `devbox.json:79`
   - `devbox.json:91`
2. Entrypoint local:
   - `bin/git-acp.sh:1`
3. Parseo del input principal:
   - `bin/git-acp.sh:109`
4. Validación de repo Git:
   - `bin/git-acp.sh:119`
5. Guard:
   - `lib/core/utils.sh:382`
6. Config:
   - `lib/core/config.sh`
7. Decisión de rama:
   - `lib/git-flow.sh:57`
8. Identidad:
   - `lib/ssh-ident.sh`
9. Commit/push:
   - `bin/git-acp.sh`
10. Post-push:
   - `lib/ci-workflow.sh:546`
11. Cierre/progreso:
   - `lib/core/utils.sh:429`
12. Simulación visible:
   - `lib/core/utils.sh:464`

## Mapeo de ramas al código
- `--dry-run`:
  - `bin/git-acp.sh`
  - `lib/core/utils.sh:464`
- Bypass del guard:
  - `bin/git-acp.sh`
  - `lib/core/utils.sh:382`
- Lógica de rama:
  - `lib/git-flow.sh:57`
- Selector/omisión de identidad:
  - `lib/ssh-ident.sh`
- Post-push:
  - `lib/ci-workflow.sh:546`

## Mapeo de side effects al código
- Inyección runtime de alias:
  - `devbox.json`
- Config del repo / posible `git config` local:
  - `lib/core/config.sh`
  - `lib/ssh-ident.sh`
- Staging, commit, push:
  - `bin/git-acp.sh`
- Fetch/pull/push secundarios:
  - `bin/git-acp.sh`
  - librerías auxiliares
- Post-push y tooling lateral:
  - `lib/ci-workflow.sh:546`

## Preconditions ancladas
- Sesión válida de `devbox`:
  - `devbox.json`
  - evidencia runtime
- Repo Git utilizable:
  - `bin/git-acp.sh:119`
- Guard del repo:
  - `lib/core/utils.sh:382`
- Cwd válido desde subdirectorio:
  - resolución dinámica del flujo local
- No-TTY:
  - tolerancia observada, no precondition positiva contractual

## Outputs anclados
- Simulación visible:
  - `lib/core/utils.sh:464`
- Cierre/progreso:
  - `lib/core/utils.sh:429`
- Omisión/cierre posterior visible:
  - `lib/ci-workflow.sh`
- Resultado ACP observable:
  - `bin/git-acp.sh` + post-push según rama correspondiente

## Invariants anclados
- Resolución local correcta:
  - `devbox.json`
- Mensaje obligatorio:
  - `bin/git-acp.sh:109`
- Repo válido:
  - `bin/git-acp.sh:119`
- Guard previo a persistencia:
  - `lib/core/utils.sh:382`
  - `lib/core/config.sh`
- Simulación sin commit/push:
  - `lib/core/utils.sh:464`
- Salida visible suficiente:
  - `lib/core/utils.sh:429`
  - `lib/ci-workflow.sh`

## Failure modes anclados
- Falta de mensaje:
  - `bin/git-acp.sh`
  - `lib/core/contract.sh:173`
- Repo Git inválido:
  - `bin/git-acp.sh:119`
- Guard bloqueante:
  - `lib/core/utils.sh:382`
- Fallos de publicación principal:
  - `bin/git-acp.sh`
- Simulación mal implementada:
  - validable sobre `bin/git-acp.sh` + `lib/core/utils.sh:464`
- Resolución fuera del repo:
  - detectable a nivel runtime contra `devbox.json`

### Estado
- `anclada`

---

## 7. Superficies de intervención reales

Esta sección responde: si mañana cambio algo de este flujo, ¿dónde recae de verdad la responsabilidad?

## Superficie principal
- `devbox.json`
- `bin/git-acp.sh`
- `lib/core/config.sh`
- `lib/core/contract.sh`
- `lib/core/utils.sh`
- `lib/git-flow.sh`
- `lib/ssh-ident.sh`
- `lib/ci-workflow.sh`

## Superficie secundaria
- `devtools.repo.yaml`
- `.devtools/.git-acprc`
- `Taskfile.yaml`
- configuración auxiliar del repo
- puntos secundarios de soporte del flujo

## Superficie de validación
- `tests/03_git_acp_devbox.bats`
- `tests/02_git_acp_post_push.bats`
- corridas seguras con `--dry-run`
- corridas runtime de resolución en `devbox`

## Zonas de alto riesgo
- Inyección runtime de `GIT_CONFIG_*` por `devbox`.
- Plano identidad/SSH/remotos/GitHub.
- Fallbacks UI y bridges en `lib/ci-workflow.sh`.
- Compatibilidades heredadas repartidas entre config y flujo Git.
- Cambios en el orden entre guardas, config persistente y side effects.

## Boundaries con flujos vecinos
- Otros aliases Git del host o del repo.
- Tooling lateral de CI/Task/GitHub no contractualizado como interfaz visible de este flujo.
- Flujos Git distintos de `git acp`.
- Trabajo de identidad/SSH/remotos fuera del mínimo necesario para que `git acp` cumpla su contrato visible.

### Estado
- `operativamente clara`

---

## 8. Divergencias, drift y gaps

Aquí no va ruido de estilo.
Aquí van las diferencias reales entre:
- comportamiento observado;
- contrato aprobado;
- código actual;
- validación existente.

## Divergencias cerradas
- La resolución global ajena al repo quedó descartada como base válida del flujo; el runtime correcto en `devbox` ya quedó absorbido.
- La obligatoriedad del mensaje quedó alineada con el contrato.
- El orden de guardas y side effects persistentes quedó alineado.
- La validez desde subdirectorio quedó absorbida como cláusula aceptada.
- La falta de marcador terminal único quedó resuelta aceptando señal visible compuesta.
- La validación Bats del flujo completo quedó exigida y reportada en verde.

## Divergencias abiertas
- No queda una divergencia central abierta que bloquee el cumplimiento mínimo aprobado.
- Las ramas del post-push distintas de `skip` siguen fuera de la evidencia mínima, pero no contradicen el contrato mínimo actual.

## Gaps funcionales
- No hay gap funcional central abierto para el cumplimiento mínimo.
- Sí hay borde no explorado en ramas adicionales del post-push y en tooling lateral.

## Gaps de anclaje
- La superficie identidad/SSH/remotos/GitHub sigue anclada de forma más difusa que el resto.
- El peso actual de piezas `Compat` / `LEGACY_` sigue parcialmente anclado como observación, no como necesidad demostrada.

## Gaps de validación
- Falta evidencia fuerte sobre ramas del post-push distintas de `skip`.
- Falta evidencia adicional sobre estabilidad futura exacta de la inyección runtime de alias en sesiones equivalentes de `devbox`.
- No hay gap de validación bloqueante para el cumplimiento mínimo ya aprobado.

## Riesgo de falsa sensación de cumplimiento
- Validar solo `--dry-run`.
- Validar solo `bash ./bin/git-acp.sh`.
- Validar solo desde el cwd raíz y no desde subdirectorios.
- Tomar la rama `skip` como cobertura total del post-push.
- Concluir cumplimiento por salida vistosa de consola sin revisar orden real de guardas y side effects.
- Ignorar el runtime de `devbox` y validar solo código local.

### Estado
- `clara`

---

## 9. Legacy, seams y compatibilidades

Esta sección existe para que nadie confunda compatibilidad heredada con contrato del flujo.

## Seams heredados observados
- `DEVTOOLS_DISPATCH_DONE`
- `LEGACY_VENDOR_CONFIG`
- `DEVTOOLS_WIZARD_MODE`
- compatibilidad de rama deprecada en `lib/git-flow.sh`
- fallbacks UI / `run_cmd` en `lib/ci-workflow.sh`
- inyección runtime de `alias.acp` por `devbox`

## Legacy sospechado pero no demostrado
- Necesidad actual de piezas `Compat`.
- Necesidad actual de piezas `LEGACY_`.
- Necesidad actual exacta de algunos bridges del plano identidad/SSH/remotos/GitHub.
- Alcanzabilidad real actual de ramas laterales como reparación de remotos o `gh repo create`.

## Compatibilidades que influyen pero no explican el flujo
- Config local del repo.
- Bridges a Task/CI/GitHub.
- Selector interactivo de identidad y su omisión sin TTY.
- Tolerancias del entorno `devbox`.
- Wrappers shell de resolución.

## Política para tocar seams
- Un seam debe respetarse si hoy sostiene una cláusula contractual o evita regresión observable.
- Puede aislarse si la intervención está directamente justificada por el spec.
- No debe reescribir el contrato visible por sí solo.
- No justifica ampliar scope.
- No debe tocarse “por limpieza” si no hay divergencia real ni validación derivada del spec.

### Estado
- `operativamente clara`

---

## 10. Validación obligatoria del flujo

Esta sección responde: ¿qué hay que comprobar sí o sí para decir que el flujo cumple?

## Validación obligatoria
Debe demostrarse con evidencia observable que:
1. En una sesión válida de `devbox`, `git acp "<texto>"` resuelve al flujo ACP local del repo.
2. La resolución sigue funcionando desde cualquier subdirectorio del repo.
3. Sin mensaje principal, el flujo falla antes de commit o push.
4. El flujo verifica repo Git válido antes de continuar con el tramo útil.
5. `check_superrepo_guard` y verificaciones previas ocurren antes de side effects persistentes.
6. La modalidad de simulación no produce commit ni push efectivos.
7. La salida visible permite distinguir al menos entre ejecución efectiva, simulación y cierre/omisión general.
8. La suite Bats mínima del flujo completo permanece en verde dentro de `devbox`.

## Validación recomendable
- Revalidar ramas adicionales del post-push.
- Revalidar sesiones equivalentes adicionales de `devbox`.
- Reforzar evidencia sobre identidad/SSH/remotos si una intervención futura toca esa superficie.
- Añadir corridas desde subdirectorios representativos del repo.

## Validación aún inmadura
- Cobertura fuerte de ramas del post-push distintas de `skip`.
- Cobertura fuerte de tooling lateral `task`, `gh`, remotos y bridges de CI.
- Cobertura fuerte del peso real de `Compat` / `LEGACY_` en ejecución efectiva completa.

## Suite de aceptación
- `tests/03_git_acp_devbox.bats`
- `tests/02_git_acp_post_push.bats`
- corrida runtime de resolución correcta en `devbox`
- corrida segura `git acp --dry-run ...`
- validación observable de la rama `skip`

## Qué no basta validar
- Solo `bash ./bin/git-acp.sh`.
- Solo el top-level cwd.
- Solo `--dry-run`.
- Solo la rama `skip`.
- Solo la salida de consola.
- Solo que el script exista o que el alias aparezca en config.
- Solo evidencia estática sin una corrida observable en `devbox`.

### Estado
- `operativamente clara`

---

## 11. Evidencia consolidada

Aquí deben vivir las referencias concretas que sostienen afirmaciones del documento.

## Corridas observadas
- `env | rg '^GIT_CONFIG|^DEVBOX|^PWD='`
- `git config --show-origin --show-scope --get-regexp '^alias\.acp$'`
- `GIT_TRACE=1 git acp --dry-run 'codex-block-reopen-devbox' </dev/null`
- `bash ./bin/git-acp.sh --dry-run 'codex-block6-validacion-segura'`
- validación interactiva de la rama `skip` del post-push
- sesión previa no equivalente donde resolvió el alias global y falló sobre `~/.gitconfig`

## Paths y archivos
- `/webapps/ihh-devtools/devbox.json`
- `/webapps/ihh-devtools/bin/git-acp.sh`
- `/webapps/ihh-devtools/lib/core/config.sh`
- `/webapps/ihh-devtools/lib/core/contract.sh`
- `/webapps/ihh-devtools/lib/core/utils.sh`
- `/webapps/ihh-devtools/lib/git-flow.sh`
- `/webapps/ihh-devtools/lib/ssh-ident.sh`
- `/webapps/ihh-devtools/lib/ci-workflow.sh`
- `/webapps/ihh-devtools/devtools.repo.yaml`
- `/webapps/ihh-devtools/.devtools/.git-acprc`
- `/webapps/ihh-devtools/tests/03_git_acp_devbox.bats`
- `/webapps/ihh-devtools/tests/02_git_acp_post_push.bats`

## Funciones y handlers
- `check_superrepo_guard`
- `show_daily_progress`
- `run_post_push_flow`
- parseo de `"$@"` y construcción de `MSG`
- handlers de commit/push en `bin/git-acp.sh`

## Config y entorno
- `DEVBOX_ENV_NAME=PMBOK`
- `DEVBOX_PROJECT_ROOT=/webapps/ihh-devtools`
- `DEVBOX_WD=/webapps/ihh-devtools`
- `DEVBOX_SHELL_ENABLED=1`
- `GIT_CONFIG_COUNT=8`
- `GIT_CONFIG_KEY_0=alias.acp`
- `GIT_CONFIG_VALUE_0=!f(){ ... "/webapps/ihh-devtools/bin/git-acp.sh" ... }; f`

## Tests y validaciones existentes
- `tests/03_git_acp_devbox.bats` reportado en verde
- `tests/02_git_acp_post_push.bats` reportado en verde
- runtime correcto en `devbox`
- validación segura con `--dry-run`
- validación de rama `skip`

## Referencias mínimas por afirmación importante
- Resolución local en `devbox`:
  - `devbox.json`
  - `GIT_CONFIG_*`
  - `GIT_TRACE=1 git acp ...`
- Núcleo local del flujo:
  - `bin/git-acp.sh`
- Guard previo a persistencia:
  - `lib/core/utils.sh:382`
- Simulación visible:
  - `lib/core/utils.sh:464`
- Cierre visible:
  - `lib/core/utils.sh:429`
- Decisión de rama:
  - `lib/git-flow.sh:57`
- Post-push:
  - `lib/ci-workflow.sh:546`
- Mensaje obligatorio / contrato:
  - `bin/git-acp.sh:109`
  - `lib/core/contract.sh:173`

### Estado
- `confirmada`

---

## 12. Unknowns reales

Esta sección es obligatoria.
Todo lo que no esté demostrado debe vivir aquí o quedar marcado como parcial en otra sección.

## Unknowns que no bloquean
- Otras ramas del post-push además de `skip`.
- Peso real actual de `Compat` / `LEGACY_`.
- Estabilidad futura exacta de la inyección runtime de `alias.acp`.
- Alcanzabilidad real de ramas laterales como reparación de remotos o `gh repo create`.
- Cuánto del plano identidad/SSH/remotos/GitHub es soporte necesario vs desborde del contrato visible.

## Unknowns que condicionan
- Si en el futuro se quiere ampliar el contrato visible del post-push.
- Si en el futuro se quiere estabilizar tooling lateral como interfaz visible.
- Si una intervención futura toca identidad/SSH/remotos o `lib/ci-workflow.sh` más allá del mínimo contractual.

## Unknowns que sí bloquean
- Ninguno dentro del contrato actual ya aprobado.

## Qué aclaración mínima haría falta para cerrar cada unknown bloqueante
- No aplica por ahora, porque no hay unknown bloqueante dentro del marco aprobado actual.

### Estado
- `abierta`

---

## 13. Trabajo permitido vs trabajo fuera de alcance

Esta sección sirve para decidir el siguiente paso sin perder el marco.

## Cambios necesarios derivados del spec
Hoy no hay un cambio funcional central adicional exigido por el spec para declarar cumplimiento mínimo. El trabajo permitido y necesario queda acotado a:
- preservar la alineación ya lograda;
- corregir regresiones directas contra:
  - resolución local del flujo;
  - mensaje obligatorio;
  - guard previo a side effects persistentes;
  - simulación segura;
  - validez desde subdirectorio;
  - salida visible suficiente;
- sostener la validación obligatoria derivada del spec;
- intervenir solo en la superficie estrictamente necesaria para la cláusula afectada.

## Cambios opcionales
- Reforzar cobertura de ramas adicionales del post-push.
- Reducir exposición a seams heredados sin ampliar el contrato.
- Fortalecer evidencia de estabilidad runtime en más sesiones equivalentes.
- Mejorar claridad interna de anclajes, siempre que no se convierta en refactor oportunista.

## Cambios explícitamente fuera de alcance
- Limpieza general de `Compat` / `LEGACY_`.
- Refactor amplio de identidad/SSH/remotos/GitHub.
- Rediseño del flujo ACP.
- Rediseño del menú post-push.
- Ampliar o estabilizar contractualmente flags accidentales.
- Mejorar banners, emojis o textos de consola.
- Endurecer ramas laterales no cubiertas por el contrato actual.
- Cambiar el mecanismo interno de resolución solo porque “sería mejor”.
- Trabajo vecino sobre otros aliases o flujos Git no cubiertos por este flow.

## Qué no debe tocarse por ahora
- Seams heredados sin divergencia real.
- Tooling lateral fuera del mínimo contractual.
- Contrato visible ya aprobado.
- Detalles accidentales de salida de consola.
- Ramas no validadas del post-push salvo que el trabajo nuevo las haga parte explícita del alcance.

## Criterio para aceptar un cambio nuevo dentro de este flujo
Un cambio solo entra si:
1. toca una cláusula del contrato o una divergencia real;
2. puede mapearse a una superficie concreta;
3. tiene validación derivada del spec;
4. no mete trabajo lateral no aprobado.

### Estado
- `operativamente clara`

---

## 14. Marco para decidir el siguiente paso

Esta es la sección que más te va a servir cuando quieras pedirle a la IA que implemente algo nuevo.

## Si quiero introducir una nueva función dentro de este flujo
Antes de tocar código, responder:

### 1. Qué parte del contrato toca
- una de estas cláusulas:
  - resolución local del flujo en `devbox`
  - mensaje principal obligatorio
  - repo Git válido
  - guard previo a side effects persistentes
  - simulación segura
  - salida visible suficiente
  - validez desde subdirectorio
  - publicación principal coherente con el mensaje

### 2. Qué tipo de cambio es
- `alineación con spec`
- `cierre de gap`
- `nueva capacidad dentro del alcance`
- `cambio opcional`
- `fuera de scope`

### 3. Qué superficies principales toca
- `devbox.json`
- `bin/git-acp.sh`
- `lib/core/config.sh`
- `lib/core/contract.sh`
- `lib/core/utils.sh`
- `lib/git-flow.sh`
- `lib/ssh-ident.sh`
- `lib/ci-workflow.sh`

### 4. Qué superficies secundarias podrían verse afectadas
- `devtools.repo.yaml`
- `.devtools/.git-acprc`
- `tests/03_git_acp_devbox.bats`
- `tests/02_git_acp_post_push.bats`
- configs o helpers laterales estrictamente vinculados a la cláusula afectada

### 5. Qué invariants no pueden romperse
- resolución local correcta en `devbox`
- mensaje obligatorio
- guard antes de side effects persistentes
- simulación sin commit/push efectivos
- validez desde subdirectorio
- salida visible suficiente
- preservación semántica principal del mensaje

### 6. Qué validaciones obligatorias deben correr
- resolución local del flujo en `devbox`
- mensaje obligatorio
- guard previo a side effects persistentes
- simulación segura
- validez desde subdirectorio
- salida visible suficiente
- Bats del flujo completo en verde

### 7. Qué unknowns podrían afectar este cambio
- ramas del post-push distintas de `skip`
- peso real de `Compat` / `LEGACY_`
- estabilidad futura de la inyección runtime de alias
- alcance real del plano identidad/SSH/remotos/GitHub

### 8. Qué seam o legacy puede arrastrar comportamiento viejo
- `DEVTOOLS_DISPATCH_DONE`
- `LEGACY_VENDOR_CONFIG`
- `DEVTOOLS_WIZARD_MODE`
- fallbacks UI / `run_cmd`
- compatibilidad de rama deprecada
- bridges laterales de CI/GitHub/Task

### 9. Qué evidencia mínima necesitaré para darlo por bueno
- una corrida observable en `devbox`
- lectura o diff sobre la superficie exacta tocada
- suite Bats mínima en verde
- evidencia explícita de que no se rompió el invariant relevante

### 10. Qué sería scope creep en este cambio
- tocar legacy “ya que estamos”
- rediseñar post-push
- ampliar flags visibles
- cambiar UX incidental
- tocar flujos vecinos
- convertir tooling lateral en contrato sin decisión explícita

### Estado
- `lista para decidir`

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
- `operativamente clara`

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
- `git acp "<texto>"` en una sesión válida de `devbox` entra al flujo local del repo.
- `"<texto>"` es obligatorio y se preserva como base semántica principal.
- Repo válido y guardas ocurren antes de side effects persistentes.
- La simulación no genera commit ni push efectivos.
- La ejecución es válida desde cualquier subdirectorio del repo.
- El flujo deja una salida visible suficiente.
- La suite Bats obligatoria permanece en verde.

## Cumplimiento deseable
- Mayor evidencia sobre ramas adicionales del post-push.
- Menor exposición a seams heredados sin ampliar scope.
- Mayor evidencia de estabilidad runtime del alias inyectado en sesiones equivalentes.
- Mejor cobertura del plano identidad/SSH/remotos si alguna intervención futura lo toca.

## Falsa apariencia de cumplimiento
- Que `--dry-run` funcione pero la ejecución efectiva no.
- Que el script local funcione pero `git acp` falle en `devbox`.
- Que funcione solo en el cwd raíz y no desde subdirectorios.
- Que haya salida vistosa de consola pero guardas/side effects estén desordenados.
- Que la rama `skip` funcione y eso se use para afirmar cobertura total del post-push.

### Estado
- `clara`

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
- `cerrada`

---

## 18. Historial de revisión del flujo

Registrar cambios importantes del flujo o del contrato.

### 2026-03-10
- tipo:
  - `discovery`
- cambio:
  - se consolidó el runtime correcto de `git acp` dentro de una sesión válida de `devbox` y se confirmó aterrizaje en `bin/git-acp.sh`
- motivo:
  - cerrar la contradicción con el alias global observado en una sesión no equivalente
- impacto:
  - quedó confirmado el entrypoint real efectivo y el núcleo local auditado
- evidencia:
  - `GIT_CONFIG_*`
  - `git config --show-origin --show-scope --get-regexp '^alias\.acp$'`
  - `GIT_TRACE=1 git acp --dry-run ...`

### 2026-03-10
- tipo:
  - `contrato`
- cambio:
  - se cerró el contrato visible del flujo
- motivo:
  - promover discovery a spec-first y fijar qué debe garantizar el flujo
- impacto:
  - quedaron cerrados mensaje obligatorio, simulación segura, guard previo a persistencia, validez desde subdirectorio y salida visible suficiente
- evidencia:
  - spec-first consolidado del flow `git-acp-devbox`

### 2026-03-10
- tipo:
  - `anclaje`
- cambio:
  - se mapeó la spec al código real
- motivo:
  - cerrar `spec-anchored`
- impacto:
  - quedaron anclados entrypoint visible, entrypoint local, guardas, simulación, cierre visible y superficies de cambio
- evidencia:
  - `devbox.json:79`
  - `devbox.json:91`
  - `bin/git-acp.sh:1`
  - `bin/git-acp.sh:109`
  - `bin/git-acp.sh:119`
  - `lib/core/utils.sh:382`
  - `lib/core/utils.sh:429`
  - `lib/core/utils.sh:464`
  - `lib/git-flow.sh:57`
  - `lib/ci-workflow.sh:546`

### 2026-03-10
- tipo:
  - `validación`
- cambio:
  - se absorbió la validación mínima ejecutable del flujo
- motivo:
  - dejar criterio observable de cumplimiento
- impacto:
  - suite Bats mínima y ruta segura quedaron incorporadas como evidencia exigible
- evidencia:
  - `tests/03_git_acp_devbox.bats`
  - `tests/02_git_acp_post_push.bats`
  - `git acp --dry-run ...`
  - rama `skip`

### 2026-03-10
- tipo:
  - `cierre de drift`
- cambio:
  - se consolidó `spec-as-source` como marco rector
- motivo:
  - evitar deriva metodológica y trabajo fuera de alcance
- impacto:
  - quedó fijado qué puede tocarse, qué no y qué valida cumplimiento
- evidencia:
  - consolidación final de `spec-as-source`

---

## 19. Apéndice opcional: plantilla de snapshot para pedirle trabajo a la IA

Usa este bloque cuando quieras pedir un cambio nuevo dentro del flujo sin volver a pegar todo el documento:

### Pedido de cambio
- qué quiero cambiar:
  - <pedido>
- por qué:
  - <motivo>
- cláusula del flow afectada:
  - <resolución local | mensaje obligatorio | guard previo a persistencia | simulación segura | salida visible suficiente | validez desde subdirectorio | publicación principal>
- superficies probables:
  - <archivo(s) de la superficie principal o secundaria>
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
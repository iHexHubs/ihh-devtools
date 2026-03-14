# Plantilla: discovery

## Propósito

Describir el flujo real observado sin inventar todavía el contrato.

Actúa como coordinador metodológico estricto de la fase discovery. No eres implementador, no eres arquitecto y no eres solucionador del problema final. Tu función es dirigir a Codex para inspeccionar el repositorio por bloques, auditar la evidencia y consolidar una ficha de flujo real.

## Caso específico de este discovery

- Flujo objetivo original: ejecución de `git acp "<texto_aquí>"`
- Flow id provisional: `git-acp-devbox`
- Trigger observado: el usuario ejecuta `git acp "<texto_aquí>"` dentro del entorno `devbox`, desde la ruta `/webapps/ihh-devtools`
- Pregunta principal: ¿qué hace realmente `git acp "<texto_aquí>"` dentro de `devbox`, por dónde entra, qué decide, qué toca y dónde termina?
- Frontera del análisis:
  - no explicar Git en general
  - no analizar aliases, funciones o comandos distintos salvo que sean necesarios para entender `git acp "<texto_aquí>"`
  - no proponer mejoras, refactors ni implementación
  - describir únicamente el comportamiento real observado
- Regla adicional 1: asumir inicialmente que `git acp "<texto_aquí>"` podría resolverse por alias dentro de `devbox`, pero corregir la conclusión si la evidencia runtime muestra otra cosa
- Regla adicional 2: no salir de la ruta `/webapps/ihh-devtools` ni del entorno `devbox`
- Regla adicional 3: todo hallazgo debe quedar restringido al comportamiento observable de `git acp "<texto_aquí>"` ejecutado desde `/webapps/ihh-devtools`
- Regla adicional 4: si el alias delega a scripts, funciones, wrappers, subcomandos o config externa, seguirlos solo mientras sigan siendo parte del flujo efectivo observado o del núcleo local auditado
- Regla adicional 5: no abrir discovery sobre otros repos, otros cwd, otras shells ni otros entornos fuera de `devbox`
- Regla adicional 6: no usar como base del flujo local aliases, configs o scripts globales fuera de `/webapps/ihh-devtools`, salvo para dejar explícita la contradicción runtime ya demostrada
- Regla adicional 7: diferenciar siempre entre:
  1. **runtime real observado en esta sesión**
  2. **núcleo local auditado dentro del repo**

## Debes trabajar con estas reglas

1. Analiza un solo flujo a la vez.
2. No implementes nada.
3. No edites nada.
4. No propongas refactors.
5. No propongas tests nuevos.
6. No mezcles discovery con spec-first, spec-anchored ni spec-as-source.
7. No inventes contrato, intención futura ni comportamiento deseado.
8. No conviertas sospechas en hechos.
9. No permitas que Codex se salga del bloque actual.
10. Después de cada respuesta de Codex, separa siempre:
   - confirmado
   - probable
   - sospecha
   - descartado
   - no sustentado
11. No permitas que Codex salga de `/webapps/ihh-devtools` ni del entorno `devbox`.
12. No permitas que Codex reinterprete el caso como un comando Git nativo; el objeto de análisis es la resolución de `git acp "<texto_aquí>"` y el núcleo local auditado del repo.
13. No promociones un bloque usando evidencia global fuera de frontera, salvo para demostrar que la hipótesis local falló en runtime.
14. Si el argumento `"<texto_aquí>"` entra al flujo, trátalo como input real y consérvalo en el análisis.

## Regla de persistencia de evidencia

Si Codex ya inspeccionó el repositorio en este hilo y produjo evidencia concreta, debes tratar esa evidencia como válida para el resto de la fase actual.

No puedes afirmar que:
- no encuentras el proyecto
- no ves el repo
- no tienes contexto suficiente del repo

mientras exista evidencia previa de Codex en este mismo hilo, salvo que:
1. el usuario haya cambiado explícitamente de repositorio
2. el entorno haya cambiado de forma explícita
3. falte una ruta o archivo puntual indispensable para una tarea nueva distinta del bloque actual

En ese caso debes decir:
- que la nueva tarea no pertenece al bloque actual
- que no vas a abandonar la fase en curso
- y que la petición nueva requiere abrir otra tarea o cerrar primero la fase actual

## Regla de rechazo de cambio de fase o de tarea

Si aparece una petición nueva que no pertenece al bloque actual
(por ejemplo: escribir tests, refactorizar, implementar, resumir otra cosa, abrir otro flujo),
no la ejecutes.

Primero debes responder:
- que esa petición no corresponde a la fase actual
- en qué bloque estás
- qué falta para cerrar el bloque
- y que no cambiarás de tarea hasta cerrar la fase o recibir una instrucción explícita de abandonar el método

## Regla de autoridad de Codex

Durante esta fase, Codex es la única fuente de inspección del repo.
No debes sustituir la evidencia de Codex por suposiciones tuyas.
No debes volver a pedir al usuario archivos ya localizados por Codex.
No debes reiniciar la búsqueda del proyecto desde cero si Codex ya produjo hallazgos relevantes en este hilo.

## Regla de confinamiento de entorno

Durante toda la fase discovery:
- el cwd de referencia es `/webapps/ihh-devtools`
- el entorno de ejecución de referencia es `devbox`
- no debes proponer ni aceptar validaciones fuera de `devbox`
- no debes seguir pistas que dependan de otro repo, otro cwd o una shell externa, salvo que aparezcan solo como contexto y sin abandonar el flujo principal
- si existe configuración de alias en `devbox`, shell rc, scripts del repo o wrappers internos, debes priorizar la resolución efectiva usada desde `/webapps/ihh-devtools` dentro de `devbox`
- si una pista viene de fuera del repo, solo puedes mencionarla como descartada por fuera de frontera o como contradicción runtime, no como base del flujo local auditado

## Orden obligatorio de bloques

- Bloque 1: Minuto 0–5 → fijar objetivo y frontera
- Bloque 2: Minuto 5–10 → localizar entrypoint real
- Bloque 3: Minuto 10–20 → leer columna vertebral
- Bloque 4: Minuto 20–30 → trazar camino feliz
- Bloque 5: Minuto 30–35 → separar núcleo, soporte y ruido/legacy
- Bloque 6: Minuto 35–40 → validación segura
- Bloque 7: Minuto 40–45 → cierre con ficha final

## Debes usar a Codex así

- En Bloque 1 no le pidas todavía análisis amplio del repo. Solo fija el flujo con el usuario.
- En Bloque 2 usa el Prompt 1.
- En Bloque 3 usa el Prompt 2.
- En Bloque 4 usa el Prompt 3.
- En Bloque 5 usa el Prompt 4.
- En Bloque 6 usa el Prompt 5.
- En Bloque 7 ya no abras nuevos frentes salvo inconsistencia crítica.

---

## Prompts obligatorios para Codex

### Prompt 1: fijar entrypoint

No implementes nada.  
No edites nada.  
No propongas refactors.  
No describas arquitectura general del repo.  
No avances a otras fases fuera del bloque actual.  
No salgas de `/webapps/ihh-devtools`.  
No salgas del entorno `devbox`.

Estamos en la fase discovery y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 2: Minuto 5–10  
Objetivo del bloque: localizar el entrypoint real del flujo.

Flujo objetivo: ejecución de `git acp "<texto_aquí>"`
Trigger real o entrada real: el usuario ejecuta `git acp "<texto_aquí>"` dentro del entorno `devbox`, desde la ruta `/webapps/ihh-devtools`
Pregunta principal: qué hace realmente `git acp "<texto_aquí>"` dentro de `devbox`: por dónde entra, qué decide, qué comandos dispara, qué toca y dónde termina
Qué queda fuera por ahora:
- no explicar Git en general
- no analizar aliases, funciones o comandos distintos salvo que sean necesarios para entender `git acp "<texto_aquí>"`
- no salir de `/webapps/ihh-devtools`
- no salir de `devbox`

Quiero únicamente:
1. entrypoint más probable
2. archivo del entrypoint
3. función, handler, ruta o comando inicial
4. trigger que lo activa
5. cómo sustentaste que ese es el entrypoint
6. candidatos alternativos que consideraste y descartaste

Restricciones:
- no traces todavía el camino feliz
- no enumeres todavía 3 a 5 archivos clave salvo que sean indispensables para justificar el entrypoint
- no hables todavía de legacy, refactors, soluciones ni implementación
- si algo no está sustentado, márcalo explícitamente como hipótesis

Tu respuesta debe distinguir entre:
- confirmado por el repo
- probable pero no completamente confirmado
- descartado

### Prompt 2: columna vertebral

No implementes nada.  
No edites nada.  
No propongas refactors.  
No avances a otros bloques fuera del actual.

Estamos en la fase discovery y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 3: Minuto 10–20  
Objetivo del bloque: leer solo la columna vertebral del flujo.

Contexto ya establecido:
- Flujo objetivo: ejecución de `git acp "<texto_aquí>"`
- Trigger real: el usuario ejecuta `git acp "<texto_aquí>"` dentro del entorno `devbox`, desde la ruta `/webapps/ihh-devtools`
- Pregunta principal: qué hace realmente `git acp "<texto_aquí>"` dentro de `devbox`: por dónde entra, qué decide, qué comandos dispara, qué toca y dónde termina
- Entry point más probable: [hallazgo del bloque anterior]
- Archivo del entrypoint: [archivo]
- Función/handler/ruta/comando inicial: [dato]

Quiero únicamente:
1. entre 3 y 5 archivos esenciales del flujo
2. rol de cada archivo
3. por qué cada archivo entra en el flujo
4. cuál parece núcleo y cuál parece soporte
5. qué archivo parece tomar la primera decisión significativa

Restricciones:
- no traces todavía el camino feliz completo
- no enumeres ramas raras
- no hagas todavía análisis de ruido/legacy
- no propongas cambios
- si incluyes un archivo, explica por qué entra realmente en este flujo

Tu respuesta debe distinguir entre:
- archivos esenciales ya sustentados
- archivos probablemente relevantes pero aún no confirmados
- archivos que parecen periféricos por ahora

### Prompt 3: camino feliz

No implementes nada.  
No edites nada.  
No propongas refactors.  
No avances a otros bloques fuera del actual.

Estamos en la fase discovery y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 4: Minuto 20–30  
Objetivo del bloque: trazar el camino feliz del flujo.

Contexto ya establecido:
- Flujo objetivo: ejecución de `git acp "<texto_aquí>"`
- Trigger real: el usuario ejecuta `git acp "<texto_aquí>"` dentro del entorno `devbox`, desde la ruta `/webapps/ihh-devtools`
- Pregunta principal: qué hace realmente `git acp "<texto_aquí>"` dentro de `devbox`: por dónde entra, qué decide, qué comandos dispara, qué toca y dónde termina
- Entry point más probable: [hallazgo]
- Archivos esenciales identificados:
  - [archivo 1]
  - [archivo 2]
  - [archivo 3]
  - [archivo 4, si aplica]
  - [archivo 5, si aplica]

Quiero únicamente:
1. secuencia principal del flujo
2. paso a paso del camino feliz
3. decisiones importantes
4. input principal
5. transformaciones importantes
6. output esperado u observado
7. side effects observados
8. estado persistido o publicado

Restricciones:
- no entres todavía en ramas raras, fallbacks secundarios ni análisis de legacy
- no cierres todavía la ficha final
- no propongas cambios
- si una parte del camino feliz no está confirmada, indícalo explícitamente

Tu respuesta debe distinguir entre:
- secuencia sustentada
- secuencia probable
- puntos del flujo que siguen abiertos

### Prompt 4: ruido y legacy

No implementes nada.  
No edites nada.  
No propongas refactors.  
No avances a otros bloques fuera del actual.

Estamos en la fase discovery y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 5: Minuto 30–35  
Objetivo del bloque: separar núcleo, soporte y posible ruido/legacy.

Contexto ya establecido:
- Flujo objetivo: ejecución de `git acp "<texto_aquí>"`
- Entry point: [dato]
- Archivos esenciales ya identificados: [lista]
- Camino feliz ya reconstruido: [resumen corto o secuencia]

Quiero únicamente:
1. archivos esenciales para este flujo
2. archivos de soporte
3. archivos que parecen ruido para este flujo por ahora
4. funciones que parecen wrappers, duplicaciones o compatibilidades heredadas
5. sospechas de legacy o ramas heredadas
6. configuraciones que influyen pero no explican el flujo
7. qué afirmaciones siguen siendo solo sospechas

Restricciones:
- no afirmes legacy como hecho si no está sustentado
- no propongas limpieza ni refactor
- no vuelvas a explicar todo el camino feliz salvo que sea necesario para justificar una sospecha
- no cierres todavía discovery

Tu respuesta debe distinguir entre:
- núcleo del flujo
- periferia útil
- ruido probable
- sospechas sin confirmar

### Prompt 5: validación segura

No cambies código.  
No implementes nada.  
No propongas refactors.  
No avances a otros bloques fuera del actual.

Estamos en la fase discovery y debes seguir estrictamente la metodología por bloques.

Bloque actual: Bloque 6: Minuto 35–40  
Objetivo del bloque: proponer una validación segura del flujo reconstruido.

Contexto ya establecido:
- Flujo objetivo: ejecución de `git acp "<texto_aquí>"`
- Entry point: [dato]
- Secuencia principal reconstruida: [pegar secuencia]
- Side effects principales: [resumen]
- Sospechas aún abiertas: [lista breve]

Quiero únicamente:
1. una validación segura posible
2. qué parte del flujo confirmaría
3. qué parte seguiría sin confirmarse
4. riesgos de ejecutar el flujo real
5. alternativa de validación estática o de baja intervención

Ejemplos válidos:
- dry-run
- --help
- verbose
- test existente
- lectura puntual de logs
- ejecución local controlada
- mocks
- inspección estática concreta

Restricciones:
- no propongas una ejecución riesgosa si existe una alternativa segura
- no rediseñes el flujo
- no cierres discovery todavía
- diferencia claramente entre validación efectiva y mera inferencia

## Criterio de promoción entre bloques

- No pases de Bloque 1 a Bloque 2 hasta tener claro el flujo objetivo, trigger real, pregunta principal y frontera.
- No pases de Bloque 2 a Bloque 3 hasta tener un entrypoint principal razonable y mínimamente sustentado.
- No pases de Bloque 3 a Bloque 4 hasta tener una lista corta y razonable de archivos esenciales.
- No pases de Bloque 4 a Bloque 5 hasta tener un camino feliz entendible y razonablemente sustentado.
- No pases de Bloque 5 a Bloque 6 hasta tener separados núcleo, soporte, ruido y sospechas.
- No pases de Bloque 6 a Bloque 7 hasta saber qué valida la validación propuesta y qué sigue incierto.

Después de cada respuesta de Codex, debes actualizar esta plantilla con evidencia real y dejar explícito si la sección está:
- confirmada
- parcial
- abierta

Tu salida final de discovery debe rellenar esta plantilla sin inventar nada y dejando claros los unknowns.

---

## Secciones

### Flow id
`git-acp-devbox`

Instrucción operativa:  
Usa un identificador corto, estable y específico del flujo. No uses nombres vagos. Si durante el discovery aparece un identificador más preciso, actualízalo y deja constancia del cambio.

**Contenido**
- `git-acp-devbox`
- Se mantiene como identificador de trabajo.
- Quedó alineado con el cierre final del discovery:
  - el flujo observado relevante es `git acp "<texto_aquí>"` ejecutado dentro de una sesión de `devbox` correctamente cargada
  - esa resolución sí aterrizó en el flujo local del repo

**Estado: confirmada**

### Objetivo
Qué intenta lograr el usuario u operador.

Instrucción operativa:  
Redáctalo en términos observables. No escribas intención futura ni contrato deseado. Debe describir qué intenta conseguir el flujo real según trigger, comandos, handlers y efectos observados.

**Contenido**
- Observar qué pasa cuando alguien ejecuta `git acp "<texto_aquí>"` desde `/webapps/ihh-devtools` dentro de `devbox`.
- **Observado en runtime en la sesión correcta de devbox:** `git acp` resolvió al flujo local del repo, no al alias global ajeno al repo.
- **Auditado localmente en el script del repo:** el núcleo del comportamiento tipo ACP quedó trazado desde `bin/git-acp.sh`.

**Estado: confirmada**

### Entry point
Comando, script, función o archivo donde empieza el flujo.

Instrucción operativa:  
Se completa después del Bloque 2. Debe quedar ligado a evidencia concreta: path, comando, handler, ruta, main, subcomando, script o caller inicial.

**Contenido**
- **Observado en runtime en una sesión correctamente cargada de devbox:** `git acp` entra por un `alias.acp` inyectado en scope `command` vía `GIT_CONFIG_*`.
- Ese alias command-line resuelve al flujo local del repo y delega en `bin/git-acp.sh`.
- **Auditado localmente en el repo:** el entrypoint local confirmado del script es `bin/git-acp.sh`.
- La contradicción observada antes con el alias global quedó explicada como una sesión no equivalente a `devbox` correctamente cargado.

**Estado: confirmada**

### Dispatcher chain
Cadena ordenada de handoff desde la entrada hacia funciones o archivos más profundos.

Instrucción operativa:  
Se completa principalmente con Bloques 3 y 4. Debe listar la cadena real de delegación sin meter todavía ramas raras salvo que afecten de verdad al flujo principal.

**Contenido**
- **Observado en runtime en la sesión correcta de devbox:**  
  `git acp` → `alias.acp` de scope `command` inyectado por devbox → wrapper shell inline → `bin/git-acp.sh`
- **Auditado localmente en el repo:**  
  `bin/git-acp.sh` → dispatch inicial con `devtools.repo.yaml` → `lib/core/config.sh` → `lib/core/utils.sh` → `lib/git-flow.sh` → `lib/ssh-ident.sh` → `lib/ci-workflow.sh`
- No apareció un target alterno en `.devtools/bin/git-acp.sh`.
- **Contradicción runtime previa ya explicada:** en una sesión no equivalente, `git acp` había resuelto al alias global `!~/scripts/git-acp.sh`.

**Estado: confirmada**

### Camino feliz
Ruta normal observada, paso a paso.

Instrucción operativa:  
Se completa en Bloque 4. Describe la secuencia principal como ejecución real o altamente sustentada. Si hay pasos no demostrados, márcalos como parciales.

**Contenido**
- **Auditado localmente en el script del repo:**
  1. `"<texto_aquí>"` entra por `"$@"`, pasa por `ORIG_ARGS`, luego `ARGS` y termina en `MSG="${ARGS[*]}"`
  2. `bin/git-acp.sh` carga config local vía `lib/core/config.sh`
  3. ejecuta `check_superrepo_guard`
  4. ejecuta `setup_git_identity`
  5. ejecuta `ensure_feature_branch_before_commit`
  6. ejecuta `do_commit`
  7. ejecuta `do_push`
  8. entra a `run_post_push_flow`
  9. cierra con `show_daily_progress`
- **Observado en runtime con el comando real en sesión correcta de devbox:**  
  `git acp --dry-run 'codex-block-reopen-devbox' </dev/null` sí aterrizó en el flujo local del repo, omitió selector interactivo por no-TTY y recorrió una ruta segura sin commit/push.
- **Validación segura local observada además:**  
  `bash ./bin/git-acp.sh --dry-run 'codex-block6-validacion-segura'` sin TTY recorrió una ruta segura del script local y cerró sin commit/push.
- El camino completo con commit/push/post-push quedó **auditado localmente** y **parcialmente validado en runtime** por la vía segura.

**Estado: parcial**

### Ramas importantes
Flags, variables de entorno, bifurcaciones o rutas alternativas relevantes.

Instrucción operativa:  
Incluye solo ramas relevantes para entender el flujo. No metas ramas hipotéticas ni excepcionales que todavía no estén sustentadas. Si una rama se sospecha pero no se demostró, ubícala también en Unknowns.

**Contenido**
- **Auditado localmente:**
  - `--dry-run` evita el bloque commit/push
  - sin TTY, `setup_git_identity` se omite
  - `--force` / `--i-know-what-im-doing` desactiva el guard
  - si la rama es protegida o `HEAD` está detached, puede cambiar de rama
  - si el push falla, intenta `pull --rebase`
- **Observado en runtime concreto:**
  - en sesión correcta de devbox, `git acp --dry-run ... </dev/null`:
    - entró al flujo local
    - omitió selector de identidad por no-TTY
    - dejó explícita la simulación
  - del post-push sí quedó validada una rama interactiva concreta:
    - `7) 🚪 Salir (Seguir trabajando)`
    - mapeo: `skip`
    - salida: `👌 Omitido.`
    - `RC=0`

**Estado: confirmada**

### Side effects
Git, red, sistema de archivos, subprocesos, cambios de entorno, etc.

Instrucción operativa:  
Describe solo efectos concretos observados o fuertemente inferidos desde el código y la validación. Deben quedar ligados a funciones, comandos, llamadas o archivos.

**Contenido**
- **Auditado localmente:**
  - carga de config local
  - posible mutación de `git config` local por identidad
  - `git add .`
  - `git commit`
  - `git push`
  - posible `git push -u`, `git pull --rebase`, `git fetch --tags --force`
- **Observado en runtime seguro:**
  - con `git acp --dry-run ... </dev/null` dentro de la sesión correcta de devbox no hubo commit/push
  - con `bash ./bin/git-acp.sh --dry-run ...` sin TTY no hubo commit/push
  - en la rama `skip` del post-push no hubo acciones de CI/PR observables
- **Observado en la carga de entorno correcta:**
  - devbox inyectó `GIT_CONFIG_*` en memoria para la resolución local del alias
- **Contradicción runtime previa ya explicada:**
  - en una sesión no equivalente, el alias global intentó tocar `/home/reydem/.gitconfig` y falló por permisos

**Estado: parcial**

### Inputs
Flags CLI, variables de entorno, archivos, config, supuestos sobre cwd.

Instrucción operativa:  
Lista únicamente entradas necesarias o claramente relevantes para que el flujo ocurra. Distingue inputs obligatorios de inputs opcionales cuando haya evidencia.

**Contenido**
- Trigger observado: `git acp "<texto_aquí>"` desde `/webapps/ihh-devtools` dentro de `devbox`
- Inputs auditados del script local:
  - `"$@"`
  - flags `--dry-run`, `--no-push`, `--force`
  - TTY / no-TTY
  - rama actual
  - config en `.devtools/.git-acprc`
- Inputs runtime observados en la sesión correcta:
  - `DEVBOX_ENV_NAME`
  - `DEVBOX_PROJECT_ROOT=/webapps/ihh-devtools`
  - `DEVBOX_WD=/webapps/ihh-devtools`
  - `DEVBOX_SHELL_ENABLED=1`
  - `GIT_CONFIG_COUNT=8`
  - `GIT_CONFIG_KEY_*`
  - `GIT_CONFIG_VALUE_*`
- Input principal preservado en el análisis:
  - `"<texto_aquí>"`

**Estado: confirmada**

### Outputs
Salida en consola, archivos creados, repos actualizados, exit codes, cambios de estado.

Instrucción operativa:  
Describe resultados observables del flujo. No inventes outputs “esperados” si no hay evidencia. Si solo se conoce una parte, márcalo como parcial.

**Contenido**
- **Observado en runtime en sesión correcta de devbox:**
  - `git acp --dry-run 'codex-block-reopen-devbox' </dev/null` mostró:
    - `🟢 [ihh-devtools] Ejecutando git-acp...`
    - `⚠️  Sin TTY: omitiendo selector interactivo de identidad.`
    - `⚗️  Simulación (--dry-run).`
- **Observado en runtime seguro del script local:**
  - banner, omisión de identidad por no-TTY, barra de progreso, simulación
- **Observado para la rama interactiva `skip`:**
  - `👌 Omitido.`
  - `RC=0`
- **Auditado localmente:**
  - commit con mensaje principal, timestamp y `REFS_LABEL #N`
  - menú/panel post-push
- **Contradicción runtime previa ya explicada:**
  - en la sesión no equivalente, `git acp` aterrizó en `~/scripts/git-acp.sh` y falló al intentar tocar `~/.gitconfig`

**Estado: parcial**

### Preconditions
Qué debe existir antes de correr el flujo.

Instrucción operativa:  
Incluye dependencias, estado del repo, archivos, variables, credenciales, cwd, herramientas externas o supuestos del entorno que parezcan necesarios.

**Contenido**
- **Auditado localmente:**
  - estar dentro de un repo Git
  - no tener `.no-acp-here`, o usar bypass
  - existir `bin/git-acp.sh` como núcleo local del flujo
- **Observado en runtime correcto:**
  - estar en `/webapps/ihh-devtools`
  - abrir una sesión real de `devbox` correctamente cargada
  - tener activo el init/runtime hook que inyecta `GIT_CONFIG_*`
  - tener disponible el alias `alias.acp` de scope `command`
- Para ruta segura:
  - `--dry-run` y no-TTY permiten evitar commit/push y selector interactivo de identidad

**Estado: confirmada**

### Error modes
Fallos conocidos u observados.

Instrucción operativa:  
Incluye errores vistos en código, guards, branches de salida, logs, exit codes o validaciones. No mezcles aquí hipótesis no sustentadas.

**Contenido**
- **Observado en runtime en sesión no equivalente previa:**
  - `git acp` usó el alias global y falló al tocar `/home/reydem/.gitconfig`
- **Auditado localmente:**
  - no estar dentro de un repositorio Git
  - no encontrar script de dispatch
  - presencia de `.no-acp-here`
  - problemas de identidad/perfil
  - push rechazado o rebase fallido
  - ramas post-push que dependan de tooling no disponible
- **Observado en ruta segura correcta:**
  - sin TTY, el selector interactivo de identidad se omite

**Estado: parcial**

### Archivos y funciones involucradas
Listar solo las importantes.

Instrucción operativa:  
Esta sección debe salir de Bloques 3, 4 y 5. Divide mentalmente entre núcleo y soporte, pero aquí lista solo lo importante para explicar el flujo.

**Contenido**
- **Observado en runtime en sesión correcta de devbox:**
  - alias inyectado en memoria vía `GIT_CONFIG_*`
- **Observado como contradicción runtime previa:**
  - `~/.gitconfig`
  - `~/scripts/git-acp.sh`
- **Auditado localmente en el repo:**
  - núcleo:
    - `bin/git-acp.sh`
    - `lib/ssh-ident.sh`
    - `lib/git-flow.sh`
    - `lib/ci-workflow.sh`
  - soporte:
    - `devbox.json`
    - `lib/core/config.sh`
    - `lib/core/utils.sh`
    - `devtools.repo.yaml`
    - `.devtools/.git-acprc`
  - periférico/condicional:
    - `Taskfile.yaml`

**Estado: confirmada**

### Unknowns
Qué todavía no está demostrado.

Instrucción operativa:  
Todo lo que no esté confirmado debe quedar aquí o marcado como parcial en su sección correspondiente. Esta sección es obligatoria. Nunca la dejes vacía por comodidad.

**Contenido**
- qué otras ramas del menú post-push funcionan en runtime real
- si `task` y tooling asociado están disponibles en la ejecución real completa
- la necesidad actual de piezas `Compat` / `LEGACY_`
- si toda sesión futura de `devbox` correctamente cargada en esta máquina reproducirá exactamente la misma inyección runtime de `alias.acp`

**Estado: abierta**

### Sospechas de legacy / seams de compatibilidad
Todo lo que parece tolerado pero no central.

Instrucción operativa:  
Se completa sobre todo en Bloque 5. Debe distinguir claramente entre sospecha y hecho. No propongas limpieza ni solución.

**Contenido**
- **Auditado localmente:**
  - dispatch inicial con `DEVTOOLS_DISPATCH_DONE` en `bin/git-acp.sh`
  - `LEGACY_VENDOR_CONFIG` en `lib/core/config.sh`
  - `feature/dev-update` marcado `Compat (deprecado)` en `lib/git-flow.sh`
  - fallbacks UI y bridges a Taskfile en `lib/ci-workflow.sh`
- No quedó demostrada su necesidad actual.

**Estado: parcial**

### Evidencia
Referencias concretas:
- paths de archivos
- nombres de funciones
- comandos
- corridas observadas

Instrucción operativa:  
Cada afirmación importante de la plantilla debe poder rastrearse a evidencia concreta. Si una sección no tiene evidencia suficiente, márcala como parcial o unknown.

**Contenido**
- **Runtime en sesión no equivalente previa:**
  - `env | rg '^GIT_CONFIG|^DEVBOX|^PWD='` mostró solo `PWD=/webapps/ihh-devtools`
  - `git config --show-origin --show-scope --get-regexp '^alias\.acp$'` mostró solo `global file:/home/reydem/.gitconfig alias.acp !~/scripts/git-acp.sh`
  - `GIT_TRACE=1 git acp --dry-run 'codex-block7-alias-runtime'` aterrizó en `~/scripts/git-acp.sh`
- **Runtime en sesión correcta de devbox:**
  - entrada a la shell real con `devbox shell`
  - salida runtime observada:
    - `🔍 Blindando entorno: Activando herramientas corporativas en memoria...`
    - `🔒 Git Config: 8 herramientas corporativas cargadas (desaparecerán al salir).`
    - `🔎 Devtools root=/webapps/ihh-devtools`
  - `pwd` mostró `/webapps/ihh-devtools`
  - `env | rg '^GIT_CONFIG|^DEVBOX|^PWD='` mostró:
    - `DEVBOX_ENV_NAME=PMBOK`
    - `DEVBOX_PROJECT_ROOT=/webapps/ihh-devtools`
    - `DEVBOX_WD=/webapps/ihh-devtools`
    - `DEVBOX_SHELL_ENABLED=1`
    - `PWD=/webapps/ihh-devtools`
    - `GIT_CONFIG_COUNT=8`
    - `GIT_CONFIG_KEY_0=alias.acp`
    - `GIT_CONFIG_VALUE_0=!f(){ ... "$r/bin/git-acp.sh" ... "/webapps/ihh-devtools/bin/git-acp.sh"; ... }`
  - `git config --show-origin --show-scope --get-regexp '^alias\.acp$'` mostró:
    - alias global:
      - `global file:/home/reydem/.gitconfig alias.acp !~/scripts/git-acp.sh`
    - alias efectivo inyectado:
      - `command command line: alias.acp !f(){ ... "$r/bin/git-acp.sh" ... "/webapps/ihh-devtools/bin/git-acp.sh"; ... }; f`
  - `GIT_TRACE=1 git acp --dry-run 'codex-block-reopen-devbox' </dev/null` mostró:
    - `trace: run_command: 'f(){ ... "$r/bin/git-acp.sh" ... "/webapps/ihh-devtools/bin/git-acp.sh"; ... }; f' --dry-run codex-block-reopen-devbox`
    - `🟢 [ihh-devtools] Ejecutando git-acp...`
    - `⚠️  Sin TTY: omitiendo selector interactivo de identidad.`
    - `⚗️  Simulación (--dry-run).`
- **Repo auditado localmente:**
  - `find /webapps/ihh-devtools -type f \( -name 'git-acp.sh' -o -name 'git-acp' \)` encontró solo `bin/git-acp.sh`
  - `find /webapps/ihh-devtools/.devtools ...` no encontró `git-acp*` alterno
  - lectura de `bin/git-acp.sh` mostró parseo de `"$@"`, `MSG`, `do_commit`, `do_push` y `run_post_push_flow`
  - lectura de `lib/core/config.sh`, `devtools.repo.yaml` y `.devtools/.git-acprc` mostró carga de config local
  - `bash ./bin/git-acp.sh --dry-run 'codex-block6-validacion-segura'` validó una ruta segura sin commit/push
  - `run_post_push_flow main-b80c3c4 dev` en PTY permitió validar la rama `skip`

**Estado: confirmada**

### Criterio de salida para promover a spec-first
Qué falta aclarar antes de promover.

Instrucción operativa:  
No promociones a spec-first por sensación. Debes escribir explícitamente:
- qué quedó suficientemente claro
- qué sigue abierto
- si los unknowns pendientes bloquean o no la promoción
- cuál sería la mínima aclaración necesaria para promover

**Contenido**
- **Sí hay material suficiente para promover a spec-first el flujo `git acp` bajo devbox en este repo.**
- Quedó suficientemente claro que:
  - en una sesión correctamente cargada de `devbox`, `git acp` resuelve al flujo local del repo
  - esa resolución entra al núcleo local auditado en `bin/git-acp.sh`
  - el mensaje `"<texto_aquí>"` entra al flujo
  - existe una ruta segura observada con `--dry-run`
- Los unknowns pendientes no bloquean por sí solos la promoción:
  - ramas post-push no revalidadas en runtime completo
  - disponibilidad final de `task` y tooling asociado
  - necesidad actual de piezas `Compat` / `LEGACY_`
- Esos unknowns deberán tratarse como:
  - alcance no cerrado del comportamiento completo
  - o preguntas abiertas de contrato en la siguiente fase
- La aclaración mínima ya lograda para promover era:
  - confirmar la entrada runtime real por devbox
  - y confirmar que `git acp` sí aterriza en `bin/git-acp.sh`

**Estado: confirmada**

---

## Formato obligatorio de trabajo durante todo discovery

Estado actual
- Bloque actual:
- Objetivo del bloque:
- Pregunta que estamos resolviendo:

Hallazgos sustentados
- ...

Hipótesis aún no confirmadas
- ...

Qué podemos ignorar por ahora
- ...

Condición para pasar al siguiente bloque
- ...

## Estado actual del discovery

Estado actual
- Bloque actual: cierre final corregido
- Objetivo del bloque: cerrar discovery con una ficha final que refleje el runtime efectivo de `git acp` dentro de una sesión correctamente cargada de `devbox`
- Pregunta que estamos resolviendo: cuando alguien ejecuta `git acp "<texto_aquí>"` dentro de `devbox` y desde `/webapps/ihh-devtools`, ¿por dónde entra realmente, qué parte quedó observada en runtime y qué parte quedó auditada localmente?

Hallazgos sustentados
- En una sesión real de `devbox` correctamente cargada, `git acp` no entró por el alias global como entrypoint efectivo
- En esa sesión correcta, `git acp` resolvió por un alias `alias.acp` de scope `command` inyectado vía `GIT_CONFIG_*`
- Ese alias runtime sí aterrizó en el flujo local del repo y delegó en `bin/git-acp.sh`
- Dentro del repo, el entrypoint local auditado y confirmado del script es `bin/git-acp.sh`
- El núcleo local auditado del script sí quedó trazado:
  - parseo de `"$@"`
  - carga de config
  - guard
  - identidad
  - decisión de rama
  - commit
  - push
  - post-push
  - barra de progreso
- Se validó una ruta segura del comando real con `git acp --dry-run ... </dev/null` sin commit/push
- Se validó una ruta segura del script local con `--dry-run` sin commit/push
- Se validó una rama interactiva concreta del post-push: `skip`

Hipótesis aún no confirmadas
- Qué otras ramas del menú post-push funcionan en runtime real completo
- Si `task` y tooling asociado están disponibles en la ejecución real completa
- La necesidad actual de piezas `Compat` / `LEGACY_`
- Si toda sesión futura correctamente cargada de `devbox` en esta máquina reproducirá exactamente la misma inyección runtime

Qué podemos ignorar por ahora
- Cualquier comportamiento fuera de `/webapps/ihh-devtools`
- Cualquier alias global del host como base del flujo local
- Cualquier intento de reconstruir otra vez todo el flujo completo
- Cualquier hipótesis de intención futura o rediseño

Condición para pasar al siguiente bloque
- No aplica: la fase discovery ya quedó cerrada

---

## Regla final

Discovery solo queda bien hecho si esta plantilla permite responder con evidencia a la pregunta:

**“Cuando alguien ejecuta `git acp "<texto_aquí>"` dentro de `devbox` y desde `/webapps/ihh-devtools`, ¿por dónde entra, qué decide, qué toca y dónde termina?”**

## Respuesta consolidada a esa pregunta

- **Observado en runtime en una sesión correctamente cargada de `devbox`:**
  - `git acp` entra por un alias `alias.acp` inyectado en scope `command`
  - ese alias delega al flujo local del repo
  - la ejecución observada con `--dry-run` aterrizó en `bin/git-acp.sh`
- **Auditado localmente en el repo:**
  - el entrypoint confirmado del script local es `bin/git-acp.sh`
  - el núcleo local recorre parseo de flags y mensaje, guard de superrepo, identidad, decisión de rama, commit/push, post-push y cierre
- **Qué toca el núcleo local auditado:**
  - config local del repo
  - posible `git config` local
  - staging
  - commit
  - push
  - tramo post-push
- **Dónde termina el núcleo local auditado:**
  - en `show_daily_progress`
  - la rama interactiva `skip` del post-push terminó con `👌 Omitido.` y `RC=0`
- **Conclusión metodológica:**
  - en una sesión de `devbox` correctamente cargada, `git acp` sí resuelve al flujo local del repo y entra a `bin/git-acp.sh`
  - el discovery queda correctamente cerrado
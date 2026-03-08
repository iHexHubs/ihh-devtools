Sí. Aquí va la **plantilla actualizada** con la evidencia que ya dejó Codex, **sin inventar nada** y dejando claro qué está **confirmado, parcial u abierto**.

---

# Plantilla: discovery

## Propósito

Describir el flujo real observado sin inventar todavía el contrato.

Actúa como coordinador metodológico estricto de la fase discovery. No eres implementador, no eres arquitecto y no eres solucionador del problema final. Tu función es dirigir a Codex para inspeccionar el repositorio por bloques, auditar la evidencia y consolidar una ficha de flujo real.

Caso específico de este discovery:

* Flujo objetivo: ejecución del comando `git acp`
* Flow id provisional: `git-acp`
* Trigger real: el usuario ejecuta `git acp` en la terminal, dentro de un repositorio
* Pregunta principal: ¿qué hace realmente `git acp`, por dónde entra, qué decide, qué toca y dónde termina?
* Frontera del análisis: no explicar Git en general; no analizar aliases, funciones o comandos distintos salvo que sean necesarios para entender `git acp`; no proponer mejoras, refactors ni implementación; describir únicamente el comportamiento real observado
* Regla adicional: no asumas que `git acp` es un subcomando nativo de Git; primero verifica si es alias, función shell, script, wrapper o comando custom, y sigue el flujo real hasta encontrar el entrypoint efectivo

## Estado actual

* **Bloque actual:** cierre de Bloque 1 / listo para pasar a Bloque 2
* **Objetivo del bloque:** conseguir evidencia mínima para localizar el entrypoint real
* **Pregunta que estamos resolviendo:** dónde vive realmente `git acp` y con qué evidencia se sostiene

## Hallazgos sustentados

* La raíz del repo relevante observada por Codex es **`/webapps/ihh-devtools`**.
* El repo contiene referencias relacionadas con `acp`, especialmente:

  * **`/webapps/ihh-devtools/bin/git-acp.sh`**
  * **`/webapps/ihh-devtools/devbox.json`**
  * **`/webapps/ihh-devtools/02_git_acp_post_push.bats`**
* En la sesión observada, la definición efectiva encontrada de `git acp` vive **fuera del repo**, en:

  * **`/home/reydem/.gitconfig:2`**
  * valor observado: **`alias.acp !~/scripts/git-acp.sh`**
* El archivo apuntado por ese alias global existe y está fuera del repo:

  * **`/home/reydem/scripts/git-acp.sh`**
* No se observó alias local del repo para `acp` en **`.git/config`**.
* No se observó alias de sistema para `acp`.
* No se observó un ejecutable `git-acp` resolviendo por **PATH** en la sesión inspeccionada.
* No se observó alias o función shell relacionada con `acp` en:

  * `~/.zshrc`
  * `~/.zshenv`
  * `~/.bashrc`
  * `~/.bash_profile`
  * `~/.profile`
* El repo parece contener un mecanismo alternativo condicionado por `devbox`, pero **no hay evidencia de que ese mecanismo esté activo en esta sesión**.
* El script externo **`/home/reydem/scripts/git-acp.sh`** y el script del repo **`/webapps/ihh-devtools/bin/git-acp.sh`** no son el mismo archivo.

## Hipótesis aún no confirmadas

* Que dentro de una sesión lanzada por `devbox` el repo inyecte temporalmente otro `alias.acp`.
* Que el script externo sea una copia, variante o derivado histórico del script del repo.
* Que el flujo que conviene seguir en Bloque 2 sea el de la sesión efectiva observada o el del mecanismo repo-local bajo `devbox`.

## Qué podemos ignorar por ahora

* Menciones documentales en `specs/`, `AGENTS.md`, `repo.dot`, `repo.drawio.xml`.
* Análisis del camino feliz interno de cualquier script.
* Cualquier branch rara o explicación general de Git.
* Archivos de soporte que hoy no demuestran la resolución efectiva de `git acp`.

## Condición para pasar al siguiente bloque

* **Cumplida**, si fijamos como base provisional que:

  * en la sesión observada, `git acp` entra por el alias Git global en **`/home/reydem/.gitconfig`**
  * ese alias dispara **`/home/reydem/scripts/git-acp.sh`**
* Si se quiere estudiar el flujo realmente ejecutado hoy, ese es el punto de partida razonable para Bloque 2.
* Si se quiere estudiar el mecanismo repo-local de `devbox`, primero habría que demostrar que ese entorno está activo.

---

## Secciones

### Flow id

`git-acp`

**Estado:** confirmada

### Objetivo

Descubrir qué intenta lograr realmente el flujo asociado a la ejecución de `git acp`, en términos observables y sustentados por evidencia del repositorio y del entorno de ejecución.

Redacción observacional actual:

* descubrir por dónde entra realmente `git acp` en la sesión observada,
* qué artefacto ejecuta primero,
* y distinguir ese entrypoint efectivo de candidatos repo-locales no activos.

**Estado:** confirmada

### Entry point

**Valor actual provisional:**

* **`git acp`** entra, en la sesión observada, por el alias Git global:

  * **archivo:** `/home/reydem/.gitconfig`
  * **línea observada:** `alias.acp !~/scripts/git-acp.sh`
* El primer comando/script efectivo apuntado por ese alias es:

  * **`/home/reydem/scripts/git-acp.sh`**

**Notas:**

* Esto está sustentado para la **sesión observada**.
* Todavía no está cerrada la discusión sobre un mecanismo alternativo por `devbox`.

**Estado:** parcial

### Dispatcher chain

Cadena mínima sustentada hasta ahora:

* `git acp`
* Git resuelve `alias.acp`
* `/home/reydem/.gitconfig`
* `!~/scripts/git-acp.sh`
* `/home/reydem/scripts/git-acp.sh`

Todavía no se inspeccionó la delegación interna posterior.

**Estado:** parcial

### Camino feliz

Aún no reconstruido.

Solo está fijado el handoff inicial observado:

* `git acp` → alias Git global → script externo `~/scripts/git-acp.sh`

**Estado:** abierta

### Ramas importantes

Ramas o bifurcaciones relevantes detectadas hasta ahora:

* **Rama efectiva observada:** alias Git global en `~/.gitconfig`
* **Rama candidata no confirmada como activa:** mecanismo repo-local/temporal vía `devbox.json`

No hay evidencia todavía de flags, fallbacks internos ni decisiones funcionales dentro del script.

**Estado:** parcial

### Side effects

Todavía no están descritos con sustento.

Solo se puede afirmar por ahora que el trigger lleva a ejecutar un script shell externo. No se ha auditado aún qué toca ese script.

**Estado:** abierta

### Inputs

Inputs observados o razonablemente necesarios hasta ahora:

* ejecución del comando `git acp`
* correr dentro de un repositorio Git
* existencia del alias Git global `alias.acp`
* existencia del archivo `/home/reydem/scripts/git-acp.sh`

Inputs opcionales o alternativos sospechados:

* entorno `devbox` con inyección temporal de alias Git

**Estado:** parcial

### Outputs

No están demostrados todavía.
No hay todavía evidencia consolidada de:

* salida en consola,
* exit codes,
* cambios en el repo,
* archivos creados,
* publicación de estado.

**Estado:** abierta

### Preconditions

Precondiciones actualmente sustentadas o probables:

* existir un repo Git activo
* existir `alias.acp` en `~/.gitconfig` para la sesión observada
* existir el script `/home/reydem/scripts/git-acp.sh`

Precondición alternativa sospechada:

* sesión inicializada por `devbox` para activar el mecanismo repo-local

**Estado:** parcial

### Error modes

No hay error modes del flujo todavía auditados.

Solo hay descartes de resolución:

* no hay alias local observado en `.git/config`
* no hay binario `git-acp` resuelto por PATH
* no hay alias/función shell observada

Eso todavía no constituye error modes del flujo.

**Estado:** abierta

### Archivos y funciones involucradas

Archivos actualmente involucrados o candidatos directos:

* **`/home/reydem/.gitconfig`** — config efectiva observada
* **`/home/reydem/scripts/git-acp.sh`** — script externo apuntado por el alias global
* **`/webapps/ihh-devtools/bin/git-acp.sh`** — candidato repo-local
* **`/webapps/ihh-devtools/devbox.json`** — posible mecanismo de inyección/alias alternativo
* **`/webapps/ihh-devtools/02_git_acp_post_push.bats`** — evidencia de uso del script repo-local en tests/validación interna

Funciones concretas del flujo todavía no identificadas con sustento.

**Estado:** parcial

### Unknowns

* Qué hace internamente `/home/reydem/scripts/git-acp.sh`
* Si el flujo real que interesa documentar es el de la sesión efectiva observada o el del repo bajo `devbox`
* Si `devbox.json` activa un `alias.acp` alternativo y bajo qué condiciones
* Qué decisiones toma el script
* Qué comandos dispara
* Qué side effects produce
* Dónde termina realmente
* Cuál es la primera decisión significativa del flujo
* Si el script externo y el del repo comparten comportamiento o solo nombre

**Estado:** confirmada

### Sospechas de legacy / seams de compatibilidad

Sospechas actuales, no hechos:

* convivencia de dos mecanismos para `acp`:

  * uno global externo (`~/.gitconfig` + `~/scripts/git-acp.sh`)
  * otro repo-local condicionado por `devbox`
* posible seam de compatibilidad entre script externo y script del repo

Nada de esto está demostrado como legacy todavía.

**Estado:** parcial

### Evidencia

Referencias concretas observadas por Codex:

* repo root:

  * `/webapps/ihh-devtools`
* config efectiva:

  * `/home/reydem/.gitconfig:2`
* script efectivo observado:

  * `/home/reydem/scripts/git-acp.sh`
* candidatos repo-locales:

  * `/webapps/ihh-devtools/bin/git-acp.sh`
  * `/webapps/ihh-devtools/devbox.json`
  * `/webapps/ihh-devtools/02_git_acp_post_push.bats`

Comandos reportados por Codex:

* `git rev-parse --show-toplevel`
* `git config --show-origin --get-regexp '^alias\.acp$'`
* `git config --global --show-origin --get-regexp '^alias\.acp$'`
* `git config --local --show-origin --get-regexp '^alias\.acp$'`
* `git config --system --show-origin --get-regexp '^alias\.acp$'`
* `type -a git-acp`
* `which -a git-acp acp git-acp.sh`
* `type -a git`
* búsquedas `rg` sobre el repo y sobre archivos rc de shell
* `env | rg '^GIT_CONFIG_(COUNT|KEY_|VALUE_)'`
* `env | rg '^DEVBOX|^PATH='`
* `readlink -f /home/reydem/scripts/git-acp.sh`
* `cmp -s /home/reydem/scripts/git-acp.sh /webapps/ihh-devtools/bin/git-acp.sh`
* `wc -c /home/reydem/scripts/git-acp.sh /webapps/ihh-devtools/bin/git-acp.sh`

Hallazgos concretos citables:

* `alias.acp !~/scripts/git-acp.sh` en `~/.gitconfig`
* sin salida para alias local en `.git/config`
* sin salida para alias de sistema
* `git-acp not found` por `type -a`
* `git-acp not found` / `acp not found` / `git-acp.sh not found` por `which -a`
* ausencia de variables `GIT_CONFIG_*` activas en el entorno observado

**Estado:** confirmada

### Criterio de salida para promover a spec-first

Todavía no corresponde promover a spec-first.

Qué quedó suficientemente claro:

* cuál es el repo relevante
* cuál es el trigger
* cuál es la definición efectiva observada de `git acp` en esta sesión
* cuál es el primer script que se ejecuta en esa resolución observada

Qué sigue abierto:

* flujo interno del script efectivo
* decisiones principales del flujo
* side effects
* outputs
* error modes
* relación real con el mecanismo de `devbox`

Si los unknowns bloquean o no la promoción:

* **sí bloquean** cualquier promoción seria a spec-first por ahora

Mínima aclaración necesaria para promover más adelante:

* cerrar Bloque 2, 3 y 4 con:

  * entrypoint efectivo fijado,
  * columna vertebral,
  * camino feliz razonablemente sustentado,
  * side effects principales,
  * unknowns residuales acotados

**Estado:** abierta

---

## Separación obligatoria

### Confirmado

* El repo relevante es `/webapps/ihh-devtools`
* En la sesión observada, `git acp` está definido por alias Git global en `/home/reydem/.gitconfig`
* El alias observado apunta a `~/scripts/git-acp.sh`
* El script `/home/reydem/scripts/git-acp.sh` existe fuera del repo
* No hay evidencia de alias local en `.git/config`
* No hay evidencia de alias de sistema para `acp`
* No hay evidencia de resolución por PATH para `git-acp`
* No hay evidencia de alias o función shell relacionada en rc files
* El repo sí contiene candidatos internos relacionados con `acp`
* El script externo y el script del repo no son el mismo archivo

### Probable

* El repo soporta una resolución alternativa de `acp` bajo `devbox`
* Existen dos mecanismos convivientes para `acp`

### Sospecha

* El mecanismo repo-local condicionado por `devbox` podría sustituir al alias global en otras sesiones
* El script externo podría ser una variante histórica o paralela del script del repo

### Descartado

* Que hoy `git acp` entre por alias local del repo
* Que hoy `git acp` entre por un ejecutable `git-acp` encontrado por PATH
* Que hoy `git acp` dependa de alias o función definida en rc de shell

### No sustentado

* Qué hace internamente el flujo después de entrar a `/home/reydem/scripts/git-acp.sh`
* Qué decide el flujo
* Qué toca exactamente
* Dónde termina
* Que `devbox.json` sea el mecanismo activo en esta sesión
* Que ambos scripts sean equivalentes funcionalmente

---

## Regla final aplicada al estado actual

La plantilla ya permite responder con evidencia a una parte de la pregunta guía:

> Cuando alguien ejecuta `git acp`, en la sesión observada entra por un alias Git global en `~/.gitconfig`, que deriva a `~/scripts/git-acp.sh`.

Todavía **no** permite responder con evidencia completa:

* qué decide,
* qué toca,
* y dónde termina.

Por eso discovery **no está cerrado** y corresponde pasar al **Bloque 2** con ese entrypoint provisional sustentado.

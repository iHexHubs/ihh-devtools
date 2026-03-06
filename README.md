

# Método de trabajo para analizar flujos

Esta sección sirve para documentar un flujo real del proyecto mientras se inspecciona con editor, terminal o Codex.

**Objetivo del método:**

* entender un flujo concreto sin tener que entender todo el repositorio;
* identificar entrypoints, decisiones, side effects y archivos relevantes;
* detectar ruido, código heredado o zonas que no participan en el flujo;
* dejar una ficha reutilizable para otros repositorios.

**Regla principal:**
analizar **un flujo a la vez**.

---

# Plantilla universal de análisis de flujos

## Metadatos del flujo

* **Repositorio:**
* **Fecha:**
* **Autor de la revisión:**
* **Nombre del flujo:**
* **Pregunta principal que quiero responder:**
* **Comando o entrada real del usuario:**
* **Nivel de confianza actual:** bajo / medio / alto

---

## Minuto 0–5: fija el objetivo

### Propósito

Definir exactamente qué flujo se quiere entender y qué se espera obtener al terminar.

### Plantilla

* **Flujo objetivo:**
* **Por qué estoy revisando este flujo:**
* **Qué quiero poder explicar al final:**
* **Qué no voy a intentar entender todavía:**
* **Sospecha inicial de problema / legacy / ruido:**

### Resultado esperado de esta fase

* una definición corta del flujo;
* una pregunta concreta de revisión;
* una frontera clara de lo que queda fuera.

---

## Minuto 5–10: localiza el entrypoint real

### Propósito

Encontrar por dónde entra el control al sistema para este flujo.

### Plantilla

* **Entry point probable:**
* **Archivo del entrypoint:**
* **Función del entrypoint:**
* **Comando o trigger que lo activa:**
* **Cómo confirmé que este es el entrypoint:**
* **Archivos candidatos alternativos que descarté:**

### Señales a buscar

* `main()`
* `case`
* `dispatch`
* `source`
* `exec`
* subcomandos
* scripts en `bin/`
* tareas o aliases en `Taskfile`, `Makefile`, scripts CI

### Resultado esperado de esta fase

* un entrypoint principal;
* 2–5 archivos iniciales a revisar.

---

## Minuto 10–20: lee solo la columna vertebral

### Propósito

Identificar los archivos esenciales del flujo antes de entrar a detalles.

### Plantilla

* **Archivo 1:**

  * rol: entrypoint / dispatcher / lógica / config / helper / side effect
  * por qué entra en el flujo:
* **Archivo 2:**

  * rol:
  * por qué entra en el flujo:
* **Archivo 3:**

  * rol:
  * por qué entra en el flujo:
* **Archivo 4:**

  * rol:
  * por qué entra en el flujo:
* **Archivo 5:**

  * rol:
  * por qué entra en el flujo:

### Preguntas guía

* ¿este archivo decide algo?
* ¿este archivo solo redirige?
* ¿este archivo transforma datos?
* ¿este archivo toca red, disco, git, docker, k8s, etc.?
* ¿este archivo parece ser solo soporte?

### Resultado esperado de esta fase

* una lista corta de archivos esenciales;
* una clasificación básica por rol.

---

## Minuto 20–30: traza el camino feliz

### Propósito

Reconstruir la secuencia principal de ejecución sin meterse todavía en ramas raras.

### Plantilla

* **Secuencia principal del flujo:**
  `archivo/función -> archivo/función -> archivo/función -> ...`

* **Paso 1:**

  * archivo:
  * función:
  * qué hace:

* **Paso 2:**

  * archivo:
  * función:
  * qué hace:

* **Paso 3:**

  * archivo:
  * función:
  * qué hace:

* **Paso 4:**

  * archivo:
  * función:
  * qué hace:

* **Paso 5:**

  * archivo:
  * función:
  * qué hace:

### Decisiones importantes en el camino feliz

* **Decisión 1:**
* **Decisión 2:**
* **Decisión 3:**

### Side effects observados

* **Filesystem:**
* **Git:**
* **Red:**
* **Procesos externos:**
* **Variables de entorno relevantes:**

### Resultado esperado de esta fase

* un flujo principal claro;
* lista de decisiones y side effects.

---

## Minuto 30–35: detecta ruido y posible legacy

### Propósito

Separar lo esencial de lo accesorio.

### Plantilla

* **Archivos esenciales para este flujo:**
* **Archivos de soporte:**
* **Archivos que parecen ruido para este flujo:**
* **Funciones que parecen wrappers o duplicaciones:**
* **Compatibilidades heredadas detectadas:**
* **Documentación que no coincide con el código:**
* **Sospechas de legacy (sin afirmar todavía):**

### Señales típicas

* funciones nunca usadas en el flujo revisado;
* helpers enormes de los que solo se usan 1–2 funciones;
* varias formas de hacer lo mismo;
* nombres legacy;
* “fallbacks” que ya parecen camino principal;
* ramas documentadas que no coinciden con el comportamiento actual.

### Resultado esperado de esta fase

* una separación entre núcleo y periferia;
* una lista de sospechas, no conclusiones definitivas.

---

## Minuto 35–40: valida con una ejecución segura

### Propósito

Confirmar que el flujo reconstruido existe de verdad en runtime.

### Plantilla

* **Comando de validación usado:**
* **Modo seguro usado:** dry-run / help / test / lectura de logs / otro
* **Salida observada:**
* **Coincide con el flujo trazado:** sí / no / parcialmente
* **Qué parte quedó confirmada:**
* **Qué parte sigue sin validarse:**
* **Riesgos de ejecutar este flujo en real:**

### Ejemplos de validación segura

* `--help`
* `DEVTOOLS_DRY_RUN=1 ...`
* tests existentes
* modo verbose
* lectura de logs
* inspección de archivos temporales o stdout/stderr

### Resultado esperado de esta fase

* una validación mínima del flujo;
* diferencia entre flujo teórico y flujo real.

---

## Minuto 40–45: cierra con una ficha de flujo

### Propósito

Dejar una ficha corta, útil y reutilizable.

### Plantilla final

* **Nombre del flujo:**
* **Entry point real:**
* **Secuencia principal:**
* **Archivo/funcción que toma la primera decisión fuerte:**
* **Archivos esenciales:**
* **Archivos de soporte:**
* **Side effects principales:**
* **Variables de entorno relevantes:**
* **Errores o branches importantes:**
* **Ruido detectado:**
* **Sospecha de legacy:**
* **Qué entendí bien:**
* **Qué no entendí aún:**
* **Siguiente archivo o branch a revisar:**

---

# Plantilla rápida de una sola página

Usar esta versión cuando se quiera una revisión express.

## Ficha rápida de flujo

* **Flujo:**
* **Entry point:**
* **Comando real:**
* **Camino feliz:**
* **Primera decisión importante:**
* **Side effects:**
* **Archivos esenciales:**
* **Archivos que puedo ignorar por ahora:**
* **Sospecha de legacy o ruido:**
* **Validación segura ejecutada:**
* **Siguiente paso:**

---

# Cómo usar esta plantilla con Codex

Prompt recomendado:

```text
No quiero cambios de código.
No quiero tests.
No quiero refactors.

Quiero entender un solo flujo del repo.

Flujo objetivo: [poner aquí el flujo]

Dime:
1. entrypoint más probable
2. 3 a 5 archivos clave
3. función central
4. side effects esperados
5. qué puedo ignorar por ahora
```

Prompt para continuar:

```text
No implementes nada.
No edites nada.

Ya revisé estos archivos:
- [archivo 1]
- [archivo 2]

Con base en eso:
1. corrige mi secuencia del flujo si hace falta
2. dime cuál es la siguiente decisión importante
3. dime qué archivo debo abrir ahora
```

---

# Notas de revisión para este repositorio

## Flujo candidato 1

* **Nombre:** `devtools apps sync`
* **Entrada:** `bin/devtools apps sync`
* **Estado de revisión:** pendiente / en curso / revisado

## Flujo candidato 2

* **Nombre:** `git-promote`
* **Entrada:** `bin/git-promote.sh`
* **Estado de revisión:** pendiente / en curso / revisado

## Flujo candidato 3

* **Nombre:** `git-acp + post-push`
* **Entrada:** `bin/git-acp.sh`
* **Estado de revisión:** pendiente / en curso / revisado

```

Si quieres, te lo puedo devolver en una segunda pasada ya **adaptado a `ihh-devtools`**, con secciones prellenadas para:
- `devtools apps sync`
- `git-promote`
- `git-acp`
```

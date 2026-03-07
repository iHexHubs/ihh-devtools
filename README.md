# Método de trabajo para analizar flujos

Esta guía sirve para documentar **un flujo real** dentro de cualquier repositorio mientras lo inspeccionas con editor, terminal, logs, debugger o una herramienta de ayuda como Codex.

## Objetivo del método

* entender un flujo concreto sin tener que entender todo el repositorio;
* identificar entrypoints, decisiones, side effects y archivos relevantes;
* separar núcleo, soporte y ruido;
* detectar posibles zonas legacy o ramas que ya no participan en el flujo;
* dejar una ficha reutilizable para futuras revisiones.

## Regla principal

Analiza **un flujo a la vez**.

---

# Plantilla universal de análisis de flujos

## Metadatos del flujo

* **Repositorio:**
* **Tipo de proyecto:** CLI / API / frontend / worker / monorepo / librería / script / otro
* **Fecha:**
* **Autor de la revisión:**
* **Nombre del flujo:**
* **Pregunta principal que quiero responder:**
* **Entrada real del usuario o trigger real:**
* **Entorno revisado:** local / dev / staging / CI / producción / lectura estática
* **Nivel de confianza actual:** bajo / medio / alto

---

## Minuto 0–5: fija el objetivo

### Propósito

Definir exactamente qué flujo quieres entender y qué necesitas poder explicar al terminar.

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
* **Función, handler, ruta o comando inicial:**
* **Trigger que lo activa:**
* **Cómo confirmé que este es el entrypoint:**
* **Candidatos alternativos que descarté:**

### Señales a buscar

* `main()`
* handlers HTTP
* controladores
* routers
* `case`
* `dispatch`
* `source`
* `exec`
* subcomandos
* jobs o consumers
* scripts en `bin/` o `scripts/`
* tareas en `Makefile`, `Taskfile`, `package.json`, CI/CD, cron, workers, colas, hooks

### Resultado esperado de esta fase

* un entrypoint principal;
* entre 2 y 5 archivos iniciales a revisar.

---

## Minuto 10–20: lee solo la columna vertebral

### Propósito

Identificar los archivos esenciales del flujo antes de entrar a detalles.

### Plantilla

* **Archivo 1:**

  * rol: entrypoint / router / controller / service / use case / config / helper / side effect
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
* ¿este archivo solo enruta o delega?
* ¿este archivo transforma datos?
* ¿este archivo valida entrada?
* ¿este archivo accede a red, disco, base de datos, colas, caché o procesos externos?
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
  * función / método / handler:
  * qué hace:

* **Paso 2:**

  * archivo:
  * función / método / handler:
  * qué hace:

* **Paso 3:**

  * archivo:
  * función / método / handler:
  * qué hace:

* **Paso 4:**

  * archivo:
  * función / método / handler:
  * qué hace:

* **Paso 5:**

  * archivo:
  * función / método / handler:
  * qué hace:

### Decisiones importantes en el camino feliz

* **Decisión 1:**
* **Decisión 2:**
* **Decisión 3:**

### Datos que entran y salen

* **Input principal del flujo:**
* **Transformaciones importantes:**
* **Output esperado:**
* **Estado persistido o publicado:**

### Side effects observados

* **Filesystem:**
* **Base de datos:**
* **Red / APIs externas:**
* **Colas / eventos / mensajería:**
* **Procesos externos:**
* **Logs / métricas / tracing:**
* **Variables de entorno relevantes:**

### Resultado esperado de esta fase

* un flujo principal claro;
* lista de decisiones y side effects;
* idea básica del movimiento de datos.

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
* **Configuraciones que influyen pero no explican el flujo:**
* **Documentación que no coincide con el código:**
* **Sospechas de legacy, sin afirmarlo todavía:**

### Señales típicas

* funciones nunca usadas en el flujo revisado;
* helpers enormes de los que solo se usan 1 o 2 funciones;
* varias formas de hacer lo mismo;
* nombres que sugieren transición o compatibilidad;
* fallbacks que parecen haberse vuelto el camino principal;
* ramas documentadas que no coinciden con el comportamiento actual;
* código marcado como temporal que sigue siendo crítico.

### Resultado esperado de esta fase

* una separación entre núcleo y periferia;
* una lista de sospechas, no conclusiones definitivas.

---

## Minuto 35–40: valida con una ejecución segura

### Propósito

Confirmar que el flujo reconstruido existe de verdad en runtime o al menos en ejecución controlada.

### Plantilla

* **Comando, request, evento o prueba de validación usada:**
* **Modo seguro usado:** dry-run / help / verbose / entorno local / test / lectura de logs / mock / inspección estática
* **Salida observada:**
* **Coincide con el flujo trazado:** sí / no / parcialmente
* **Qué parte quedó confirmada:**
* **Qué parte sigue sin validarse:**
* **Riesgos de ejecutar este flujo en real:**

### Ejemplos de validación segura

* `--help`
* `--dry-run`
* tests existentes
* modo verbose
* inspección de logs
* ejecución con mocks
* llamada local contra entorno controlado
* lectura de stdout/stderr
* inspección de archivos temporales o registros de auditoría

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
* **Archivo o función que toma la primera decisión fuerte:**
* **Archivos esenciales:**
* **Archivos de soporte:**
* **Dependencias externas involucradas:**
* **Side effects principales:**
* **Variables de entorno relevantes:**
* **Errores o branches importantes:**
* **Ruido detectado:**
* **Sospecha de legacy:**
* **Qué entendí bien:**
* **Qué no entendí aún:**
* **Siguiente archivo, branch o ejecución a revisar:**

---

# Plantilla rápida de una sola página

Úsala cuando quieras una revisión express.

## Ficha rápida de flujo

* **Flujo:**
* **Entry point:**
* **Entrada real o trigger real:**
* **Camino feliz:**
* **Primera decisión importante:**
* **Datos que entran y salen:**
* **Side effects:**
* **Archivos esenciales:**
* **Archivos que puedo ignorar por ahora:**
* **Sospecha de legacy o ruido:**
* **Validación segura ejecutada:**
* **Siguiente paso:**

---

# Cómo usar esta plantilla con Codex o con otra IA

## Prompt inicial recomendado

```text
No quiero cambios de código.
No quiero tests.
No quiero refactors.

Quiero entender un solo flujo del repo.

Flujo objetivo: [poner aquí el flujo]

Dime:
1. entrypoint más probable
2. 3 a 5 archivos clave
3. función o módulo central
4. side effects esperados
5. qué puedo ignorar por ahora
```

## Prompt para continuar la revisión

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

## Prompt para validar hipótesis

```text
No cambies código.

Esta es mi hipótesis del flujo:
[pegar secuencia]

Quiero que me digas:
1. qué parte parece correcta
2. qué parte no está sustentada todavía
3. qué ejecución segura o lectura puntual me confirmaría el siguiente paso
```

---

# Registro de flujos candidatos

Usa esta parte para tener pendientes dentro de cualquier repo.

## Flujo candidato 1

* **Nombre:**
* **Entrada o trigger:**
* **Estado de revisión:** pendiente / en curso / revisado

## Flujo candidato 2

* **Nombre:**
* **Entrada o trigger:**
* **Estado de revisión:** pendiente / en curso / revisado

## Flujo candidato 3

* **Nombre:**
* **Entrada o trigger:**
* **Estado de revisión:** pendiente / en curso / revisado

## Flujo candidato 4

* **Nombre:**
* **Entrada o trigger:**
* **Estado de revisión:** pendiente / en curso / revisado

---

# Criterios prácticos para que siga siendo genérica

## Qué sí meter

* entrypoint real;
* camino feliz;
* decisiones clave;
* side effects;
* archivos esenciales;
* cosas que puedes ignorar por ahora.

## Qué no meter demasiado pronto

* arquitectura completa del repo;
* todas las dependencias;
* toda la jerarquía de carpetas;
* ramas raras no confirmadas;
* refactors o soluciones antes de entender el flujo.

---

# Idea base del método

La idea no es entender todo el sistema.
La idea es poder responder bien esta pregunta:

**“Cuando pasa X, ¿por dónde entra, qué decide, qué toca y dónde termina?”**

---


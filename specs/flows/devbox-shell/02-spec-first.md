# Spec First

## Flow id
`devbox-shell`

## Intención
`devbox shell` debería abrir una shell de trabajo contextualizada al repositorio y dejar visible si el entorno quedó suficientemente verificado o preparado para usar esa experiencia contextualizada. El flujo debería asumir la responsabilidad de detectar el workspace correcto, exponer herramientas efímeras del repo y gatear la ruta "lista" cuando la verificación requerida no se satisface, sin exigir al operador conocer los handoffs internos del hook o del wizard.

## Contrato visible para el usuario
- Si el operador invoca `devbox shell` dentro de un repo válido con este flujo configurado, el sistema debería resolver el workspace correcto antes de contextualizar la sesión.
- El flujo debería preparar una shell con contexto del repo y herramientas efímeras relevantes para trabajar en ese repo.
- El flujo debería comunicar de forma visible si la sesión quedó lista/contextualizada o si esa ruta fue omitida por falta de verificación o preparación suficiente.
- El flujo puede ofrecer ayudas interactivas de conveniencia cuando hay TTY, pero esas ayudas no forman parte del contrato esencial.

**Conflicto con el estado actual**
- El comportamiento observado fuera de la variante estricta tolera fallos del wizard sin bloquear toda la shell, lo que tensiona esta propuesta contractual si se interpretara que toda shell abierta equivale a sesión lista/contextualizada.

## Preconditions
- El operador debe ejecutar el flujo desde un repo Git válido que contenga este `devbox.json`.
- El entorno debe poder resolver el workspace y acceder a los artefactos mínimos del flujo declarados por el repo.
- Para la ruta que declara la sesión como lista/contextualizada, deben estar disponibles los prerequisitos mínimos que el gatekeeper necesita para verificar o preparar el entorno.
- Si el flujo requiere interacción o verificación externa, el entorno debe ofrecer esas capacidades; de lo contrario, la experiencia puede degradarse a una shell no lista o a una verificación parcial.

**No contractual por ahora**
- La ubicación exacta del archivo de perfil.
- La existencia del marker como obligación visible para el usuario.
- La semántica interna exacta del binario `devbox`.

## Inputs
- Comando de entrada: `devbox shell`.
- Estado del repo y del workspace actual.
- Presencia o ausencia de TTY.
- Variables de control del flujo, como `DEVTOOLS_SKIP_WIZARD` y `DEVTOOLS_SKIP_VERSION_CHECK`.
- Estado previo de preparación/verificación del entorno cuando el repo ya fue usado antes.

**Distinguir**
- Obligatorio: invocar el flujo en un repo válido con su configuración presente.
- Contextual: TTY, marker de setup, perfil persistido, overrides de contrato.
- No cerrado como contractual: cualquier path legacy o tolerancia heredada que hoy el código acepte.

## Outputs
- Una shell abierta con contexto del repo.
- Exposición efímera de herramientas o aliases del repo necesarios para trabajar en esa sesión.
- Señal visible para el operador sobre si la sesión quedó lista/contextualizada o si esa ruta fue omitida.
- Mensajes de orientación suficientes para entender el estado general del flujo.

**No se eleva automáticamente a output contractual**
- El texto exacto de banners o mensajes.
- El prompt exacto o el uso de Starship.
- Cualquier side effect incidental del wizard que no sea parte visible y estable del contrato.

## Invariants
- El flujo debería resolver el workspace antes de decidir cómo contextualizar la sesión.
- El flujo no debería tratar la sesión como lista/contextualizada si la verificación requerida para esa ruta falla.
- La contextualización de herramientas del repo debería ser efímera respecto de la sesión, no depender de dejar configuración permanente como condición de éxito contractual.
- La diferencia entre "shell abierta" y "sesión lista/contextualizada" debería permanecer visible para el operador.
- Las ayudas visuales o interactivas no deberían redefinir el resultado contractual principal del flujo.

## Failure modes
- Si el entorno no satisface los prerequisitos mínimos de verificación/preparación, el flujo debería dejar visible que la ruta lista/contextualizada no quedó disponible.
- Si falta el gatekeeper o no puede completar la verificación requerida, eso debería interpretarse como fallo de preparación del entorno contextualizado, no como confirmación silenciosa de readiness.
- Si faltan herramientas mínimas o el repo no es válido, el flujo debería fallar de forma comprensible para el operador.

**Distinción importante**
- Fallo contractual: el operador no puede confiar en que la sesión quedó lista/contextualizada.
- Fallo interno observado pero no contractual por ahora: wording exacto, secuencia interna del wizard, detalles de red/SSH o persistencia incidental.

## No-goals
- No promete autenticación exitosa con servicios externos en toda ejecución.
- No promete reparar automáticamente cualquier problema de Git, SSH, red o configuración local.
- No promete una implementación visual específica del prompt, del selector de rol o de la UI interactiva.
- No promete preservar como contrato los seams/legacy observados, como ramas de submódulo o rutas anidadas históricas.
- No promete que todos los side effects actuales del wizard formen parte de la responsabilidad contractual del flujo.

## Ejemplos
- Ejemplo válido:
  - Un operador entra con `devbox shell` en el repo, el flujo resuelve el workspace, prepara la sesión y la verificación requerida resulta satisfactoria.
  - Resultado esperado: el operador queda en una shell contextualizada y recibe una señal visible de que la sesión quedó lista.
- Ejemplo de degradación válida:
  - Un operador entra con `devbox shell`, pero la verificación requerida para la ruta contextualizada falla.
  - Resultado esperado: la shell puede abrirse, pero el flujo deja visible que omitió la ruta lista/contextualizada y el operador no debe asumir readiness.
- Ejemplo provisional:
  - Un operador entra en modo no interactivo o con saltos de wizard.
  - Resultado esperado provisional: la shell puede degradarse sin menú enriquecido ni confirmación fuerte de readiness. Este caso sigue sujeto a contraste posterior.

## Acceptance candidates
- El flujo determina el workspace antes de preparar la contextualización visible de la sesión.
- El flujo diferencia de forma observable entre "sesión lista/contextualizada" y "sesión abierta sin readiness confirmado".
- Si la verificación requerida falla, el flujo no declara la sesión como lista/contextualizada.
- El flujo expone al operador herramientas/contexto del repo de forma efímera durante la sesión.
- Las ayudas interactivas son opcionales respecto del contrato principal y su ausencia no debería redefinir el significado de readiness.
- Los seams legacy observados no se tratan todavía como obligaciones contractuales maduras.

## Preguntas abiertas
- ¿La rama no estricta, que hoy tolera fallos del wizard, debe preservarse como comportamiento permitido o recortarse en fases posteriores?
- ¿La ubicación contractual del perfil debe ser abstracta o debe cerrarse explícitamente más adelante frente al seam entre `profile_file` y `.devtools/.git-acprc`?
- ¿Qué parte exacta de los side effects del wizard debe quedar fuera del contrato principal de `devbox shell` y tratarse solo como mecanismo interno?
- ¿El marker de setup debe seguir siendo solo detalle interno/optimizador o merece semántica contractual visible?
- ¿Cómo debería expresarse contractualmente la experiencia no interactiva sin depender de detalles accidentales del estado actual?

## Criterio de salida para promover a spec-anchored
- Esta spec puede promover a `spec-anchored` si la siguiente fase toma este contrato como base y resuelve, sin mezclar implementación, estas tensiones principales:
  - la divergencia entre la propuesta contractual de readiness visible y la tolerancia observada fuera de la variante estricta;
  - el seam de perfil/legacy sin convertirlo todavía en obligación contractual;
  - la separación entre outputs contractuales y side effects incidentales del wizard.
- No hace falta reabrir discovery completo para promover; basta con anclar técnicamente el contrato y contrastar las zonas abiertas donde hoy hay tensión con el estado observado.
- No debería promoverse si la siguiente fase intentara tratar los seams legacy, los mensajes exactos de UI o la tolerancia actual del código como contrato ya cerrado sin justificación adicional.

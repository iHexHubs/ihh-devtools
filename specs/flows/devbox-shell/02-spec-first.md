# Spec First

## Flow id
`devbox-shell`

## Intención
`devbox shell` deberia servir como entrada a una shell de desarrollo contextualizada para este repositorio.

Su responsabilidad contractual propuesta es:
- preparar una sesion de shell asociada al repo;
- cargar el contexto y herramientas necesarias para trabajar dentro del repo;
- dejar visible si la sesion quedo efectivamente lista o si quedo retenida por requisitos de verificacion o setup;
- no presentar como "lista/contextualizada" una sesion cuyo gate de verificacion requerido no quedo satisfecho.

Claro:
- el flujo existe para entrar a una shell de trabajo del repo, no para iniciar directamente servicios del producto.

Provisional:
- la frontera exacta entre "verificacion minima" y "setup mutante" todavia no esta completamente cerrada como contrato.

En conflicto con el estado actual:
- hoy el mismo comando puede rozar ramas con side effects mas fuertes que una simple entrada al shell.

## Contrato visible para el usuario
Un usuario u operador que ejecuta `devbox shell` correctamente dentro de este repo deberia poder asumir lo siguiente:

- la invocacion intenta abrir una shell de desarrollo contextualizada para este repo;
- la sesion carga contexto del repo y herramientas auxiliares necesarias para trabajar desde esa shell;
- si el entorno cumple la verificacion requerida, la sesion se presenta como lista/contextualizada;
- si la verificacion requerida falla, el flujo no deberia comunicar falsamente que la sesion quedo lista;
- en modo interactivo y cuando la sesion si queda lista, puede aparecer una capa de contextualizacion adicional de la sesion;
- el flujo puede mostrar mensajes informativos, pero el wording exacto de esos mensajes no forma parte del contrato.

Claro:
- el usuario deberia poder distinguir entre exito contextualizado y estado no listo.

Provisional:
- no esta completamente cerrado si una verificacion fallida debe dejar una shell utilizable no lista, o si deberia cortar antes con una semantica de fallo mas fuerte.

En conflicto con el estado actual:
- la rama sin marker parece tolerar fallos y continuar, mientras la rama estricta retiene la ruta lista/contextualizada.

## Preconditions
Preconditions contractuales propuestas:

- la invocacion ocurre dentro de este repo o de un `cwd` que permita resolver la raiz efectiva del repo;
- `devbox` esta disponible y puede procesar `devbox.json`;
- existe la configuracion del repo necesaria para inicializar la shell de desarrollo;
- `git` esta disponible;
- si el flujo exige verificacion de setup previa, deben estar disponibles las herramientas minimas para esa verificacion;
- si la sesion debe quedar lista tras verificacion, las credenciales y accesos requeridos por esa verificacion deben estar en estado saludable.

Claro:
- entrar al flujo fuera de un repo valido no deberia considerarse ejecucion valida;
- una sesion "lista/contextualizada" puede exigir mas que la mera disponibilidad de `devbox`.

Provisional:
- el detalle exacto de las precondiciones externas impuestas por el binario `devbox`;
- si `gum` y herramientas del full path forman parte del contrato normal o solo de una rama de compatibilidad o setup extendido.

No contractual por ahora:
- la existencia del marker `.devtools/.setup_completed` como requisito visible para usuario;
- la ruta exacta del archivo de perfil o del vendor dir.

## Inputs
Inputs contractuales propuestos del flujo:

- comando base: `devbox shell`;
- contexto de ejecucion: `cwd` dentro del repo;
- estado local previo de setup o verificacion del repo;
- disponibilidad o no de TTY;
- estado de autenticacion y conectividad requerido por la verificacion cuando esa verificacion sea aplicable.

Inputs observados pero no cerrados como contrato firme:
- `DEVTOOLS_SKIP_WIZARD`;
- `DEVTOOLS_SKIP_VERSION_CHECK`;
- `DEVBOX_ENV_NAME`;
- ramas derivadas de ausencia de marker o de setup incompleto.

Claro:
- la presencia o ausencia de TTY afecta el comportamiento del flujo y debe tratarse como input relevante.

Provisional:
- si los env vars observados son inputs soportados deliberadamente o seams operativos heredados.

No permitido asumir como contrato:
- que cualquier flag o variable interna observada hoy seguira siendo estable solo porque el codigo actual la usa.

## Outputs
Outputs contractuales propuestos:

- apertura de una shell asociada al repo;
- carga de contexto del repo y herramientas de trabajo visibles dentro de la sesion;
- senal visible de si la sesion quedo lista/contextualizada o no;
- disponibilidad de utilidades efimeras de trabajo asociadas a la sesion;
- contextualizacion adicional de la sesion cuando aplique el modo interactivo y la verificacion haya quedado satisfecha.

Outputs incidentales observados pero no cerrados como garantia:
- wording exacto de banners o mensajes;
- implementacion concreta del prompt;
- detalles exactos del menu interactivo;
- side effects de setup profundo como escritura de `.env`, cambio de remote, alta de llaves o cambios globales de Git.

Claro:
- el contrato si puede prometer un resultado observable de preparacion de sesion;
- el contrato no deberia prometer efectos globales o mutaciones fuertes como resultado normal de cualquier entrada al shell.

En conflicto con el estado actual:
- el full path observado puede producir side effects materiales que parecen mas propios de un flujo de setup o reparacion que de una entrada cotidiana al shell.

## Invariants
Invariants contractuales propuestos:

- el flujo conserva como foco la entrada a una shell contextualizada del repo;
- la sesion no debe presentarse como lista/contextualizada si el gate de verificacion aplicable no quedo satisfecho;
- la contextualizacion visible debe corresponder al repo resuelto, no a un contexto arbitrario;
- los aliases o configuraciones de apoyo cargados para la sesion no deberian requerir persistencia global para que la entrada basica al shell sea valida;
- el comportamiento no interactivo no deberia depender de interaccion humana obligatoria.

Claro:
- "no comunicar ready si no hubo verificacion satisfecha" es el invariant mas fuerte y util de esta spec.

Provisional:
- el nivel exacto de degradacion aceptable cuando falla la verificacion;
- si debe existir siempre una shell no lista como fallback o si eso depende de la rama.

## Failure modes
Failure modes contractuales propuestos:

- si la invocacion no ocurre desde un repo valido, el flujo debe fallar como entrada valida al shell contextualizado;
- si faltan herramientas minimas requeridas para la rama que corresponde ejecutar, el flujo debe comunicar fallo de precondicion;
- si la verificacion requerida falla, el flujo debe comunicar que la sesion no quedo lista/contextualizada;
- si el flujo no puede localizar los componentes minimos necesarios para su gate de setup o verificacion, no debe reportar exito contextualizado.

Claro:
- el significado contractual del fallo principal es "no quedo lista la sesion contextualizada".

Provisional:
- el exit code exacto y la forma exacta de degradacion en todas las ramas;
- si la rama sin marker puede considerarse exito parcial aunque absorba fallos internos.

En conflicto con el estado actual:
- hoy algunas ramas parecen absorber fallos y continuar, lo que vuelve ambigua la semantica contractual de exito o fallo del comando.

## No-goals
Este flujo no deberia prometer:

- arrancar servicios del producto;
- reparar por completo credenciales de GitHub o SSH como garantia normal de entrada al shell;
- garantizar cambios globales de Git, firma o llaves SSH;
- garantizar migracion de remotes;
- garantizar que `.devtools` sea gestionado como submodulo valido;
- garantizar una implementacion concreta del prompt o de `starship`;
- resolver automaticamente todos los problemas de setup historico o legacy.

Claro:
- el flujo es de entrada a shell contextualizada, no de bootstrap integral irreversible.

## Ejemplos
### Ejemplo 1: setup previo saludable, sesion interactiva
Un usuario ejecuta `devbox shell` desde `/webapps/ihh-devtools`, el repo esta en estado verificable y la verificacion requerida pasa.

Resultado esperado:
- se abre una shell contextualizada del repo;
- la sesion queda marcada como lista;
- el usuario ve senales de contexto del repo y puede usar herramientas cargadas para esa sesion.

### Ejemplo 2: setup previo existe, pero la verificacion falla
Un usuario ejecuta `devbox shell` desde el repo, pero la validacion requerida de credenciales o SSH no queda satisfecha.

Resultado esperado:
- el flujo no debe comunicar que la sesion quedo lista/contextualizada;
- debe quedar visible que la verificacion requerida fallo;
- cualquier degradacion adicional de la experiencia queda abierta mientras no se cierre mejor la semantica de esta rama.

### Ejemplo 3: invocacion no interactiva
Una ejecucion no TTY invoca `devbox shell` en contexto automatizado.

Resultado esperado:
- el flujo no deberia requerir interaccion humana para la rama aplicable;
- la verificacion minima, si corresponde, deberia seguir una ruta no interactiva;
- quedan abiertos el cierre exacto del resultado y la semantica de exito o fallo.

### Ejemplo 4: repo sin estado previo suficiente de setup
Una ejecucion entra al flujo sin estado previo suficiente para la ruta de shell lista.

Resultado esperado:
- el flujo puede requerir una ruta de setup o reparacion antes de considerar lista la sesion;
- no debe prometer contexto listo si todavia depende de un setup no satisfecho;
- queda abierto cuanto de ese setup debe vivir en este mismo comando y cuanto deberia separarse mejor contractualmente.

## Acceptance candidates
- Ejecutar `devbox shell` desde este repo en un entorno previamente verificado deberia producir una shell contextualizada del repo y dejar visible que la sesion quedo lista.
- Si la verificacion requerida para la ruta lista/contextualizada falla, el flujo no deberia presentar la sesion como lista.
- Una ejecucion sin TTY no deberia depender de un menu interactivo para realizar la verificacion minima aplicable.
- La entrada al shell deberia resolver el contexto del repo antes de cargar herramientas de apoyo de la sesion.
- Las utilidades de apoyo cargadas para la sesion deberian estar disponibles dentro de esa sesion sin requerir que queden persistidas como configuracion global.
- El flujo no deberia exigir como contrato visible que el usuario conozca rutas internas como `.devtools/.setup_completed` o archivos internos de perfil.

Provisional:
- convertir la rama sin marker en acceptance candidate maduro requiere aclarar si su semantica deseada es exito degradado, setup guiado o fallo explicito;
- convertir la rama `DEVTOOLS_SKIP_WIZARD` en acceptance candidate maduro requiere decidir si ese input es contractual o interno.

## Preguntas abiertas
- ¿Cual debe ser exactamente la semantica contractual del camino `verify-only` dentro de `devbox shell`, incluyendo el resultado visible y el exit status del comando?
- ¿`DEVTOOLS_SKIP_WIZARD` es un input soportado del flujo o un seam operativo que no debe elevarse a contrato?
- ¿El drift entre `profile_file: .git-acprc` en root y el estado observado en `.devtools/.git-acprc` debe resolverse a favor de uno de los dos, o mantenerse como compatibilidad tolerada?
- ¿El intento de tratar `.devtools` como submodulo sin `.gitmodules` forma parte de un contrato intencional, de un legado tolerado o de una anomalia a corregir en otra fase?
- ¿Que comportamiento contractual deberia asumirse si `starship` existe pero `STARSHIP_CONFIG` apunta a un archivo inexistente?
- ¿Cual debe ser la semantica exacta de las ramas no verificadas: sin marker, no-TTY, fallo GH, fallo SSH?
- ¿La rama de full setup con side effects materiales debe seguir formando parte del mismo contrato de `devbox shell` o deberia considerarse solo compatibilidad heredada o reparacion?
- ¿Hasta que punto el menu de rol y el cambio de `DEVBOX_ENV_NAME` forman parte del contrato visible y no solo de la experiencia actual?

## Criterio de salida para promover a spec-anchored
Este contrato queda cerca de promovible para `spec-anchored` si se acepta el siguiente marco:

- ya estan suficientemente definidas la intencion principal del flujo, la distincion entre sesion lista y no lista, y el foco contractual en entrada a shell contextualizada del repo;
- ya existe una base util de preconditions, inputs, outputs, invariants, failure modes y no-goals;
- los acceptance candidates sobre entrada contextualizada, gate de verificacion y no dependencia de interaccion para no-TTY ya tienen forma utilizable;
- no bloquea la promocion mantener abiertos detalles de wording, prompt exacto y forma concreta del menu interactivo.

Antes de promover con seguridad convendria aclarar al menos uno de estos puntos:
- la semantica contractual real de `verify-only` en `devbox shell`;
- el tratamiento contractual del drift `profile_file` root vs legacy;
- el papel contractual del intento de submodulo sin `.gitmodules`;
- la semantica deseada de la rama sin marker y de los fallos GH o SSH.

Si esa aclaracion minima no se consigue todavia, la promocion a `spec-anchored` seria posible solo aceptando explicitamente que esos puntos pasen como conflictos abiertos a mapear, no como contrato cerrado.

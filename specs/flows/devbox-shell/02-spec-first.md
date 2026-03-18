# Spec First

## Flow id
`devbox-shell`

## Intención
El flujo `devbox shell` debería garantizar que, al entrar al shell del repo, el operador obtiene una sesion utilizable para trabajar en este repositorio con preparacion efimera del entorno y con una senal visible de si la sesion quedo `ready` o degradada.

La responsabilidad contractual central del flujo no es completar siempre una configuracion persistente del operador, sino preparar el contexto operativo del repo y explicitar el resultado de la compuerta de readiness antes de asumir que la sesion quedo lista.

## Contrato visible para el usuario
Un operador que ejecuta `devbox shell` correctamente en el contexto valido del repo puede asumir que el flujo intentara preparar el entorno efimero necesario para trabajar en este repositorio y que comunicara si la sesion quedo lista para operar o si quedo degradada.

El operador puede asumir que el flujo puede validar o guiar partes de su setup, pero no debe asumir como garantia universal que toda entrada al shell completara configuraciones persistentes, mutara Git, cree archivos locales o reprovisione credenciales. Esas capacidades pueden existir, pero no forman el exito base contractual de toda entrada al shell.

El operador no debe asumir como contrato central el prompt exacto, el menu exacto, el texto exacto de salida, el chequeo remoto de version ni la sincronizacion best-effort de `.devtools`.

## Preconditions
- Ejecutar `devbox shell` desde un contexto valido del repo o work tree asociado a este flujo.
- El repo debe ser accesible como repo Git utilizable para preparar la sesion de trabajo.
- La definicion contractual del repo para este flujo debe estar disponible, incluyendo la ruta esperada para `.devtools`.
- Debe existir un entorno base en el que `devbox shell` pueda iniciar; los internals del binario `devbox` y su provision de herramientas no forman parte del contrato del repo.
- Si el operador espera que la validacion o configuracion guiada de autenticacion y SSH llegue a buen termino, debe contar con herramientas, conectividad y credenciales acordes; eso condiciona esas ramas, no el nucleo minimo del contrato.

## Inputs
- El comando de entrada `devbox shell`.
- El contexto de ejecucion del repo: cwd, work tree Git y disponibilidad de `.devtools` en la ruta esperada por el flujo.
- El estado previo relevante del operador y del repo, por ejemplo marker de setup previo, archivos locales de perfil y configuracion Git existente.
- Variables de entorno que modifican ramas del flujo, en particular las que permiten saltar wizard, saltar chequeos no centrales o variar la experiencia segun interactividad.
- La presencia o ausencia de TTY interactivo.

## Outputs
- Una sesion shell preparada de forma efimera para trabajar en el repo.
- Una comunicacion visible de si la sesion quedo `ready` o degradada.
- Contexto operativo del repo cargado en la sesion, incluyendo ajustes efimeros del entorno y ayudas de uso que no requieren persistencia.
- En algunas ramas, validacion o configuracion guiada del setup del operador con posibles side effects persistentes; esto es salida posible del flujo, pero no garantia universal del exito base.
- En caso de degradacion, una salida que no oculte que la sesion no alcanzo readiness completa.

## Invariants
- El flujo debe distinguir entre preparacion efimera del entorno y mutaciones persistentes del setup del operador.
- El flujo debe comunicar el estado final de readiness en vez de asumirlo implicitamente.
- El contrato del flujo debe seguir siendo repo-centrico: prepara una sesion utilizable para operar este repo, no cualquier workspace arbitrario.
- Los comportamientos best-effort observados no deben redefinir por si solos el exito contractual base.
- La ausencia de una configuracion persistente completa no debe reescribirse como incumplimiento automatico del flujo si la sesion utilizable del repo puede quedar preparada y su estado comunicado.

## Failure modes
- El flujo puede terminar en estado degradado cuando la compuerta de readiness no se satisface.
- Si faltan piezas necesarias para la validacion o configuracion guiada, el flujo puede informar fallo o degradacion de esas ramas sin que eso convierta automaticamente toda entrada al shell en invalida.
- La falta de interactividad puede impedir ramas guiadas y reducir el flujo a validacion o preparacion no interactiva.
- Fallos de red, GitHub, SSH o estado de credenciales pueden impedir readiness completa o configuracion guiada.
- Sigue abierto si ciertos fallos del primer arranque deberian tratarse como bloqueo contractual duro o como degradacion aceptable; esa frontera no debe maquillarse como resuelta.

## No-goals
- Garantizar el prompt exacto, el menu exacto o la redaccion exacta de mensajes.
- Garantizar como parte central del contrato el chequeo remoto de version.
- Garantizar como parte central del contrato la sincronizacion o actualizacion best-effort de `.devtools`.
- Garantizar que toda entrada al shell complete side effects persistentes sobre Git, SSH, `.env`, `.git-acprc` o remotes.
- Definir en esta fase el anclaje tecnico exacto al codigo, la instrumentacion de validacion o la implementacion futura del flujo.

## Ejemplos
- Ejemplo valido y solido: el operador entra con `devbox shell` en el repo, el flujo prepara el entorno efimero del repo y comunica que la sesion quedo `ready`; el operador puede continuar trabajando en el repo sin depender de que se hayan escrito archivos persistentes.
- Ejemplo valido y solido: el operador entra en una rama no interactiva o con restricciones de setup, el flujo prepara lo que puede de forma efimera y comunica que la sesion quedo degradada; el resultado visible no oculta la degradacion.
- Ejemplo provisional: en primer arranque interactivo, el flujo ofrece configuracion guiada de auth, SSH, Git y perfil, produce side effects persistentes y luego deja la sesion `ready`. Este ejemplo es plausible y consistente con discovery, pero su lugar exacto dentro del contrato visible sigue abierto.
- Ejemplo de fallo esperado: faltan credenciales o conectividad para ramas de autenticacion y el flujo no alcanza readiness completa; el contrato exige visibilidad de esa condicion, no fingir exito.

## Acceptance candidates
- Al ejecutar `devbox shell` en un contexto valido del repo, el flujo deja una sesion utilizable para operar este repositorio o comunica explicitamente que quedo degradada.
- El flujo aplica preparacion efimera del entorno como parte de su responsabilidad contractual base.
- El flujo no depende contractualmente del prompt exacto, del menu exacto ni del texto exacto de mensajes para considerarse correcto.
- El flujo no exige como exito base universal que se produzcan mutaciones persistentes del setup del operador.
- Si una rama del flujo no alcanza readiness completa, el resultado visible lo comunica y no lo presenta como sesion lista.
- El chequeo remoto de version y el sync/update best-effort de `.devtools` no son criterio central de aceptacion del flujo.

## Preguntas abiertas
- Primer arranque: sigue abierto si la configuracion guiada del primer arranque debe quedar dentro del contrato visible principal o si debe tratarse como capacidad opcional y condicionada.
- Mutaciones persistentes: sigue abierto que nivel de escritura sobre `.env`, `.git-acprc`, Git config, llaves SSH o remote debe considerarse tolerado, opcional o explicitamente fuera del nucleo contractual.
- Workspace anidado: sigue abierto si el flujo debe definirse solo respecto del repo actual o si debe reconocer como contrato visible una semantica de workspace/superproyecto.
- Severidad de fallos: sigue abierto que subconjunto de fallos debe bloquear contractualmente la readiness y cual puede resolverse como degradacion aceptable.
- Estado actual vs contrato: hoy existen ramas observadas que realizan side effects fuertes; el contrato propuesto no las eleva automaticamente a exito base y esa divergencia debe mantenerse visible.

## Criterio de salida para promover a spec-anchored
Este artefacto queda promovible a `spec-anchored` si se conserva esta frontera contractual:

- el nucleo del flujo es preparar una sesion utilizable del repo y comunicar `ready` o degradada;
- la preparacion efimera del entorno forma parte del contrato;
- la configuracion guiada con side effects persistentes puede existir, pero no se trata como exito base universal;
- el prompt exacto, el menu exacto, el chequeo remoto de version y el submodule sync/update best-effort quedan fuera de la garantia contractual central;
- las preguntas abiertas y conflictos con el estado actual permanecen visibles para anclaje posterior.

No deberia promoverse si la siguiente fase pretende cerrar por inercia cualquiera de estas preguntas abiertas como si ya estuvieran decididas por el comportamiento actual.

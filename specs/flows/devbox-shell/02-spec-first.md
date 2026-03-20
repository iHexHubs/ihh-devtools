# Spec First

## Flow id
`devbox-shell`

## Intención
El flujo `devbox shell` debería garantizar una entrada válida a una shell Devbox asociada a este repositorio, con entorno base del repo y con intento de contextualización para uso de devtools locales.

La responsabilidad contractual del flujo no es solo abrir una shell con paquetes, sino dejar al usuario en un entorno repo-local utilizable para trabajo de desarrollo u operación local, con una ruta permitida y condicionada de verificación o bootstrap del contexto local cuando el flujo entra por el wizard completo.

El contrato no fija como obligación que toda invocación complete una experiencia interactiva plena ni que toda invocación produzca el mismo grado de contextualización.

## Contrato visible para el usuario
Si el usuario ejecuta `devbox shell` desde este repo, puede asumir que:

- obtiene una shell Devbox del repositorio, con variables de entorno base definidas por el repo;
- el flujo intentará preparar contexto local de devtools para esa sesión;
- la ruta de “sesión lista/contextualizada” depende de condiciones del entorno, del modo de ejecución y del resultado de la verificación local;
- el flujo puede, cuando entra por la ruta completa del wizard, ejecutar bootstrap persistente local como comportamiento permitido y condicionado;
- una invocación no interactiva o de mera verificación puede quedar en una salida más acotada que una sesión interactiva completa.

El usuario no debe asumir, solo por ejecutar `devbox shell`, que siempre verá selector de rol, prompt contextualizado, aliases visibles, autenticación reparada o configuración persistente completada.

Separación explícita:

- Contrato visible: shell Devbox repo-local con contextualización intentada y condicionada.
- Comportamiento actual no elevado automáticamente a contrato: mensajes exactos del hook, branding, ruta interna de resolución de scripts, layout interno exacto de archivos legacy y secuencia precisa del wizard.

## Preconditions
- `devbox` debe estar instalado y disponible en `PATH`.
- El comando debe ejecutarse dentro de un working tree válido del repo objetivo.
- El repo debe contener `devbox.json`.
- Debe existir `git` como herramienta base del flujo.
- Para la ruta de verificación o bootstrap completo pueden requerirse herramientas y acceso externos adicionales, como `gh`, `ssh` y credenciales válidas.
- Para la experiencia interactiva completa debe existir TTY.

No se propone como precondition contractual que exista `.gitmodules` ni que el repo esté obligado a resolver devtools desde una única ruta interna.

## Inputs
- Comando principal: `devbox shell`.
- Flags permitidos que pueden modular el comportamiento sin redefinir el contrato base: `--help`, `--print-env`, `--pure`, `--config`, `--env`, `--env-file`.
- Estado local del repo y del entorno: presencia o ausencia de marker de setup previo, disponibilidad de TTY, herramientas externas instaladas, estado Git local y archivos de configuración ya existentes.
- Variables de entorno moduladoras observadas en el flujo actual: `DEVTOOLS_SKIP_WIZARD`, `DEVTOOLS_SKIP_VERSION_CHECK`, `DEVTOOLS_ASSUME_YES`.

Distinción contractual:

- Input contractual: invocar `devbox shell` desde el repo con entorno suficiente para abrir la shell Devbox.
- Input tolerado o modulador: flags y variables que alteran ramas de verificación o bootstrap.
- Input incidental del estado actual: ubicación exacta de scripts auxiliares o de archivos legacy.

## Outputs
- Una shell Devbox válida para este repo o, en modos no interactivos, una salida consistente con la modalidad invocada.
- Variables de entorno base del repo disponibles en la sesión o en la salida equivalente del modo usado.
- Intento de contextualización local del entorno de devtools para la sesión.
- Si la ruta completa del wizard aplica y las condiciones lo permiten, el flujo puede producir bootstrap persistente local.

Outputs visibles que sí pertenecen al contrato:

- existencia de un entorno Devbox repo-local;
- existencia de una decisión de flujo entre verificación limitada y ruta más completa de contextualización/bootstrap;
- posibilidad de que la sesión quede lista o no lista según la verificación.

Outputs visibles que no quedan fijados como obligación contractual en v1:

- texto exacto de consola;
- prompt exacto;
- selector de rol;
- cantidad exacta de aliases/herramientas cargadas;
- ubicación exacta del archivo de perfil persistente.

Conflicto visible con el estado actual:

- el estado observado mezcla contrato repo más nuevo y persistencia legacy en `.devtools`; por eso la ubicación final del perfil no se fija como output contractual cerrado en esta fase.

## Invariants
- El flujo sigue siendo repo-local: su validez depende del repo actual y de su `devbox.json`.
- La shell base de Devbox forma parte del núcleo contractual, aunque la contextualización adicional falle o quede limitada.
- La contextualización ampliada no debe tratarse como garantizada en toda invocación; depende de condiciones observables del entorno.
- La ruta de verificación no debe confundirse con la ruta de bootstrap completo.
- Los detalles internos de compatibilidad o legado no redefinen por sí solos el contrato visible del flujo.

## Failure modes
- Si `devbox` o `git` no están disponibles, el flujo no cumple sus preconditions y no puede satisfacer el contrato.
- Si faltan herramientas o credenciales requeridas para la ruta de verificación o bootstrap, la sesión puede no alcanzar estado “lista/contextualizada”.
- Si no hay TTY, el flujo puede degradarse legítimamente a una ruta de mera verificación o salida no interactiva.
- Si la verificación requerida falla, el flujo puede omitir la ruta “lista/contextualizada”.
- Si no se encuentra el componente de bootstrap esperado, el flujo puede quedar en una shell base o parcialmente contextualizada, según la rama aplicable.

No se fijan todavía como contrato v1 los códigos de salida exactos ni los mensajes exactos de error de cada rama.

## No-goals
- No garantizar experiencia interactiva completa en toda invocación.
- No garantizar reparación automática de autenticación, SSH o configuración local en todos los casos.
- No garantizar que la contextualización completa ocurra en modos no interactivos o de mera verificación.
- No garantizar una ruta interna exacta para scripts, markers o archivos auxiliares.
- No convertir compatibilidades legacy observadas en obligación contractual permanente.
- No definir en esta fase el anclaje técnico exhaustivo entre contrato y archivos del repo.

## Ejemplos
- Ejemplo válido sólido:
  Un usuario ejecuta `devbox shell` dentro del repo, con `devbox` y `git` disponibles. El flujo abre una shell Devbox del repo y hace un intento legítimo de contextualización local. Si la verificación requerida resulta satisfactoria, la sesión puede quedar lista para trabajo local.

- Ejemplo válido sólido:
  Un usuario ejecuta `devbox shell --print-env`. El flujo entrega una salida útil para el entorno base de Devbox del repo, pero eso no equivale contractualmente a una sesión interactiva completa ni prueba toda la contextualización efímera.

- Ejemplo de fallo esperado:
  Un usuario ejecuta `devbox shell` sin TTY o sin credenciales/herramientas requeridas para verificación. El flujo puede no alcanzar la ruta “lista/contextualizada” y seguir siendo consistente con el contrato si la shell base o la salida degradada corresponden al modo invocado.

- Ejemplo provisional:
  Un usuario con setup previo ejecuta `devbox shell` en sesión interactiva y obtiene una experiencia más completa de contextualización. Este caso es coherente con el contrato propuesto, pero sus detalles visibles exactos siguen dependiendo del estado actual y no se fijan aquí como obligación.

## Acceptance candidates
- Al ejecutar `devbox shell` desde este repo, el flujo inicia una shell Devbox asociada al `devbox.json` del repositorio.
- El flujo expone o prepara el entorno base del repo como parte de esa shell o de la modalidad equivalente invocada.
- El flujo distingue entre una ruta de verificación limitada y una ruta potencialmente más completa de contextualización/bootstrap.
- La condición de “sesión lista/contextualizada” depende de verificación y contexto, y no se promete como resultado universal.
- El contrato permite bootstrap persistente local cuando el flujo entra por la ruta completa del wizard, pero no lo exige en toda invocación.
- Una invocación no interactiva o de mera verificación no se interpreta como evidencia suficiente de experiencia interactiva completa.
- El contrato visible no depende de fijar una ubicación interna exacta para scripts o archivos legacy.

Acceptance candidates todavía prematuros:

- fijar la ubicación contractual definitiva de `.git-acprc`;
- fijar mensajes exactos, prompt exacto o menú exacto como parte del contrato;
- fijar el alcance exacto de todos los side effects persistentes del wizard.

## Preguntas abiertas
- ¿Cómo debe tratarse contractualmente la coexistencia entre `./.git-acprc` y `.devtools/.git-acprc` mientras el estado actual visible sigue mostrando persistencia legacy?
- ¿Cuál es el alcance contractual exacto del bootstrap persistente frente a la ruta de mera verificación: qué debe considerarse permitido, esperado o incidental?
- ¿Qué nivel mínimo de contextualización visible debe seguir considerándose suficiente cuando la verificación falla pero la shell base sí abre?
- ¿Hasta qué punto la salida de `--print-env` representa una modalidad contractual autónoma del flujo y no solo una herramienta de inspección parcial?

Conflictos visibles con el estado actual que permanecen abiertos:

- el contrato repo declara `./.git-acprc`, pero el estado observado conserva `.devtools/.git-acprc`;
- el flujo actual mezcla señales de layout contractual más nuevo con compatibilidad legacy en `.devtools`.

## Criterio de salida para promover a spec-anchored
Este spec-first queda promovible a `spec-anchored` si se mantiene como autoridad funcional v1 el siguiente núcleo:

- `devbox shell` garantiza shell Devbox repo-local con entorno base del repo;
- el flujo intenta contextualización local de devtools;
- la ruta “lista/contextualizada” es condicionada, no absoluta;
- el bootstrap persistente local está permitido cuando aplica la ruta completa del wizard, pero no queda prometido en toda invocación;
- las divergencias entre contrato nuevo y persistencia legacy quedan visibles y no maquilladas.

La siguiente fase debe anclar este contrato al código real sin reescribirlo por inercia y sin cerrar por su cuenta las preguntas abiertas sobre ubicación contractual del perfil y alcance exacto del bootstrap persistente.

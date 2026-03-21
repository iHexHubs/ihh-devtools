# Spec First

## Flow id
`devbox-shell`

## Intencion
El flujo debe garantizar una entrada de shell local de devbox gobernada por el repo, capaz de:
- resolver correctamente la raiz de trabajo;
- exponer el toolchain Devbox necesario para el repo;
- aplicar una ruta estricta de verificacion cuando existe marker interactivo;
- y ofrecer una subfrontera no interactiva `devbox shell --print-env` util para consumidores internos que necesitan toolchain sin abrir una sesion interactiva.

## Contrato visible para el usuario
- Un operador que entra con `devbox shell` en la raiz del repo debe obtener una sesion contextualizada por el repo, no una shell generica.
- Si existe `.devtools/.setup_completed`, hay TTY y no se salta el wizard, la ruta lista/contextualizada solo debe habilitarse si la verificacion del wizard satisface la variante estricta.
- Si la verificacion estricta falla, el flujo debe hacerlo visible y no debe presentar la sesion como lista/contextualizada.
- Un consumidor no interactivo puede usar `devbox shell --print-env` para obtener exports de toolchain y variables necesarias para ejecutar comandos dependientes del entorno Devbox.
- El flujo puede emitir mensajes auxiliares, pero no debe ocultar el estado de verificacion ni la disponibilidad real del entorno.

## Preconditions
- El comando se ejecuta dentro de un repo Git valido.
- `devbox` esta disponible.
- `devbox.json` esta presente en la raiz.
- Para la ruta estricta:
  - existe `.devtools/.setup_completed`;
  - hay TTY;
  - el wizard no fue saltado;
  - el wizard puede verificar GH CLI y SSH.
- Para `print-env`, Devbox debe poder resolver el entorno del repo.

## Inputs
- comando base: `devbox shell`
- variante no interactiva: `devbox shell --print-env`
- estado TTY
- presencia o ausencia de `.devtools/.setup_completed`
- flags o env vars:
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `--verify-only`
  - `--force`
- contrato del repo:
  - `devtools.repo.yaml`
  - `.devtools/.git-acprc`

## Outputs
- entorno Devbox listo para el repo;
- ruta lista/contextualizada habilitada o no habilitada segun el gate;
- mensajes de verificacion, bienvenida y ayuda contextual;
- bloque de `export ...` para la subfrontera `--print-env`;
- disponibilidad de toolchain relevante para el repo, incluyendo `git-cliff` para el consumidor de changelog.

## Invariants
- La raiz de trabajo debe resolverse antes de intentar localizar herramientas del repo o del vendor dir.
- La variante estricta no puede habilitar la ruta lista/contextualizada si la verificacion requerida falla.
- La resolucion de contrato del repo debe priorizar `devtools.repo.yaml` y luego las rutas de compatibilidad definidas por el runtime.
- `devbox shell --print-env` debe seguir siendo consumible por workflows no interactivos que necesiten toolchain Devbox.
- La frontera principal del flujo sigue siendo CLI/shell local; no debe degradarse artificialmente a otra superficie mas comoda.

## Failure modes
- ejecucion fuera de repo Git;
- herramientas requeridas ausentes;
- GH CLI no autenticado;
- SSH no valida para el host configurado;
- imposibilidad de resolver el entorno Devbox para `print-env`;
- sesion presentada como lista/contextualizada sin haber pasado el gate estricto;
- ruptura del consumer fallback de `common.sh` al no poder evaluar `print-env`.

## No-goals
- arrancar `devbox-app`;
- garantizar semantica interna de Nix o de Devbox fuera de la frontera observable;
- fijar el texto exacto del prompt o de mensajes cosméticos;
- convertir side effects internos tolerados en promesas contractuales completas;
- mezclar este contrato con Context-Driven o Agentic QA.

## Ejemplos
- Escenario 1: operador interactivo con `.devtools/.setup_completed` y credenciales sanas entra con `devbox shell` y obtiene ruta lista/contextualizada.
- Escenario 2: operador interactivo con marker pero verificacion fallida entra con `devbox shell` y recibe mensaje de verificacion fallida sin ruta lista/contextualizada.
- Escenario 3: `lib/promote/workflows/common.sh` llama `devbox shell --print-env`, evalua los exports y ejecuta `git-cliff`.

## Acceptance candidates
- La variante estricta solo habilita la ruta lista/contextualizada tras verificacion satisfactoria.
- La variante no interactiva `--print-env` exporta suficiente toolchain para consumidores internos.
- La resolucion de root y de contrato del repo ocurre antes de los pasos del wizard que dependen de esas rutas.
- Los side effects tolerados deben permanecer visibles y no pueden ocultarse como si fueran neutros.
- El contrato deja visible cuando la cobertura ejecutable es parcial.

## Preguntas abiertas
- `devbox shell --print-env` representa o no el `init_hook` interactivo completo.
- La escritura global de `init.defaultBranch=main` debe considerarse parte tolerada del flujo o side effect fuera de contrato.
- El uso de `.starship.toml` ausente es tolerancia segura o seam que debe seguir visible.

## Criterio de salida para promover a spec-anchored
- El flujo puede promover si el anclaje localiza con claridad:
  - entrypoint repo-controlado;
  - root resolution;
  - gate estricto;
  - resolucion de contrato/profile;
  - consumidor real de `print-env`.
- Los unknowns abiertos no bloquean la fase siguiente mientras sigan visibles y no se conviertan en promesas contractuales cerradas.

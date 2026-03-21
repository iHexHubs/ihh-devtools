# Spec First

## Flow id
`devbox-shell`

## Intencion
- Proteger contractualmente el flujo por el cual este repo usa `devbox shell` para exponer un entorno base consumible y, cuando aplica, una sesion contextualizada cuya condicion de "lista" depende de una verificacion explicita del setup wizard.
- Preservar una frontera honesta para dos consumidores reales:
  - operador humano que entra al shell del repo;
  - automatizacion que importa el entorno mediante `devbox shell --print-env`.
- Mantener separado del contrato principal todo lo que sea soporte, compatibilidad heredada o detalle interno de tooling.

## Contrato visible para el usuario
- `devbox shell --help` debe seguir exponiendo al menos las flags visibles que este flujo protege: `--print-env`, `--config` y `--env`.
- `devbox shell --print-env` debe seguir siendo la salida contractual base para automatizacion del repo.
- La salida contractual base de `--print-env` debe incluir, como minimo:
  - `DEVBOX_ENV_NAME="IHH"` como valor base por defecto del repo antes de cualquier eleccion interactiva de rol;
  - `DEVBOX_PROJECT_ROOT="<repo_root>"` resolviendo al root del repo en tiempo de ejecucion.
- Cuando la variante del flujo exija verificacion (`DEVTOOLS_SPEC_VARIANT=1`), el shell no debe presentarse como listo/contextualizado sin exito del wizard.
- Cuando la verificacion requerida falle o el wizard no pueda correr en esa variante, el flujo debe dejar visible una senal explicita de omision de la ruta lista/contextualizada.
- La ruta de archivo de perfiles usada por el wizard debe resolverse desde el contrato repo-local y no por hardcode legacy del vendor dir.

## Preconditions
- El consumidor corre el flujo dentro del repo correcto.
- Existe `devbox.json` valido para el repo.
- Devbox puede procesar `devbox.json`.
- Para la rama contextualizada que requiere verificacion:
  - el repo debe localizar `setup-wizard.sh`;
  - las herramientas requeridas por el wizard deben estar disponibles para la rama ejecutada;
  - la condicion contextual de marker/TTY/skip-wizard define si hay gate estricto o no.

## Inputs
- Comando principal:
  - `devbox shell`
  - `devbox shell --print-env`
- Variables de entorno que cambian el comportamiento:
  - `DEVTOOLS_SKIP_WIZARD`
  - `DEVTOOLS_SKIP_VERSION_CHECK`
  - `DEVTOOLS_CONTRACT_FILE`
  - `DEVTOOLS_PROFILE_CONFIG`
- Estado contextual:
  - presencia de `.devtools/.setup_completed`
  - TTY o no TTY
  - contrato repo-local (`devtools.repo.yaml`)

## Outputs
- Ayuda CLI que hace visible las flags protegidas.
- Script de entorno exportable para `--print-env`.
- Senal explicita de:
  - shell listo/contextualizado cuando la verificacion requerida se satisface;
  - omision de ruta lista/contextualizada cuando esa verificacion falla o no puede ejecutarse.
- Entorno contractual para consumidores repo-locales que dependen de PATH/herramientas disponibles dentro del shell de Devbox.

## Invariants
- La frontera principal sigue siendo CLI/shell local; no se rebaja a una API ni a una subrutina interna.
- `--print-env` conserva su papel de frontera observable para automatizacion del repo.
- El valor base contractual de `DEVBOX_ENV_NAME` es `IHH` antes de cualquier seleccion interactiva de rol.
- `DEVBOX_PROJECT_ROOT` debe seguir resolviendo al root del repo.
- El flujo no puede declarar la sesion "lista" en la variante con gate estricto si la verificacion requerida no pasa.
- La resolucion del archivo de perfiles debe seguir el contrato repo-local.

## Failure modes
- Falla de `devbox shell --print-env`, que bloquea a consumidores repo-locales dependientes de ese entorno.
- Falla de verificacion del wizard en la variante estricta, que debe impedir la ruta lista/contextualizada.
- Imposibilidad de localizar o ejecutar el wizard en la variante estricta, que debe producir omision explicita y no falso exito.
- Falla por herramientas requeridas ausentes en el wizard cuando la rama correspondiente necesita esas herramientas.

## No-goals
- No garantiza exito de `gh auth` ni de conectividad SSH mas alla del gate observable del wizard.
- No garantiza el texto completo ni el orden exacto de toda la salida generada por Devbox.
- No garantiza el numero exacto de aliases Git efimeros cargados.
- No convierte en contrato principal:
  - el menu interactivo de roles;
  - el prompt;
  - la ruta legacy `.devtools/.git-acprc`;
  - la compatibilidad con submodulos heredados sin `.gitmodules`.

## Ejemplos
- Ejemplo 1:
  - Dado un consumidor automatizado del repo,
  - cuando ejecuta `devbox shell --print-env`,
  - entonces puede importar un entorno que incluye `DEVBOX_ENV_NAME="IHH"` y `DEVBOX_PROJECT_ROOT="<repo_root>"`.
- Ejemplo 2:
  - Dado un shell humano con marker y gate estricto activo,
  - cuando la verificacion del wizard falla,
  - entonces el flujo no debe presentarse como listo/contextualizado y debe avisar la omision.
- Ejemplo 3:
  - Dado el wiring contractual del repo,
  - cuando el wizard resuelve el archivo de perfiles,
  - entonces debe usar la ruta derivada del contrato repo-local y no un hardcode legacy.

## Acceptance candidates
- `devbox shell --help` conserva `--print-env`, `--config` y `--env`.
- `devbox shell --print-env` expone `DEVBOX_ENV_NAME="IHH"` y `DEVBOX_PROJECT_ROOT="<repo_root>"`.
- El gate de readiness conserva:
  - arranque provisional en `DEVBOX_SESSION_READY=0` bajo variante estricta;
  - `--verify-only` en no TTY o marker presente;
  - mensaje explicito de omision cuando la verificacion no satisface la variante.
- El wizard y `step-04-profile.sh` conservan el uso de `devtools_profile_config_file()` y `DEVTOOLS_WIZARD_RC_FILE`.

## Preguntas abiertas
- El mensaje exacto y el orden completo de salida de Devbox no quedaron re-observados en esta corrida.
- No quedo demostrado si algun consumidor fuera del flujo principal aun depende de `.devtools/.git-acprc`.
- No se fijan como contrato principal los detalles del menu interactivo de rol; quedan como comportamiento accesorio mientras no surja un consumidor contractual explicito.

## Criterio de salida para promover a spec-anchored
- Queda suficientemente fijado:
  - cual es la frontera visible;
  - que promesa minima protege la automatizacion;
  - que promesa minima protege la variante contextualizada con gate;
  - que el profile file contractual debe resolverse desde `devtools.repo.yaml`.
- Debe verificarse en `spec-anchored`:
  - donde vive cada responsabilidad importante;
  - que partes ya estan claramente sostenidas por codigo y artefactos generados;
  - que seams o divergencias existen entre contrato aprobado y estado actual.
- Los unknowns abiertos no bloquean promocion porque no impiden anclar la promesa central a superficies reales del repo.

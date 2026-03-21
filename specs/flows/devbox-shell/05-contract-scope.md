# 05-contract-scope

- Flow id: `devbox-shell`
- Familia metodologica: `Contract-Driven`
- Estado: `approved`

## Autoridad de Entrada
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Objetivo Contractual del Flujo
- Proteger el contrato observable por el cual este repo expone un shell Devbox consumible y una salida `--print-env` util para automatizacion, sin declarar como contrato principal detalles internos o legacy que no pertenecen honestamente a la frontera CLI/shell local.

## Frontera Contractual Real

### Frontera principal
- `devbox shell` como flujo CLI/shell local del repo, con variante contractual observable `devbox shell --print-env`.

### Provider
- `devbox.json` + `shell.init_hook` materializado en `.devbox/gen/scripts/.hooks.sh`, mas el wiring repo-local de `bin/setup-wizard.sh`, `lib/core/contract.sh` y `lib/wizard/step-04-profile.sh`.

### Consumer(s)
- operador humano que entra al shell del repo;
- automatizacion repo-local que importa `devbox shell --print-env`;
- consumidor localizado: `lib/promote/workflows/common.sh`;
- verificador contractual localizado: `tests/contracts/devbox-shell/run-contract-checks.sh`.

### Dentro del contrato
- flags visibles de ayuda relevantes para el flujo;
- existencia de `--print-env` como superficie observable;
- exports base minimos del repo en `--print-env`;
- gate de readiness cuando la variante estricta exige verificacion;
- resolucion contractual del profile file del wizard;
- mensaje explicito de omision cuando la variante estricta no satisface la verificacion requerida.

### Fuera del contrato
- exito real de GH auth o SSH;
- comportamiento completo interno de Devbox fuera del repo;
- numero exacto de aliases Git efimeros;
- texto completo de todos los mensajes de welcome/prompt;
- limpieza o migracion del legacy `.devtools/.git-acprc`;
- integracion real con CI en esta corrida.

### Cobertura esperada
- `parcial`

## Modo de Adopcion
- Modo: `hibrida`
- Justificacion: `la frontera principal es CLI/shell local y no cae honestamente en un dialecto contractual ejecutable soportado por Specmatic`
- Relacion con la frontera principal: `la frontera principal se gobierna con manifiesto contractual y validacion primaria via Bats`
- Motivo de adopcion hibrida, si aplica: `no existe una subfrontera tipada y defendible que justifique declarar cobertura Specmatic en este flujo`

## Clasificacion de la Frontera
- Tipo de frontera: `CLI`
- Subtipo operativo: `shell local`
- Naturaleza: `workflow observable orientado a entorno`

## Dialecto Contractual Adoptado
- Dialecto: `no aplica a la frontera principal`
- Razon: `la frontera principal no es HTTP, eventos, GraphQL, gRPC, SOAP ni otro dialecto contractual ejecutable soportado de forma honesta por Specmatic`

## Contrato Canonico del Flujo
- Tipo de contrato: `shell-local workflow contract manifest`
- Archivo canonico: `specs/contracts/devbox-shell/interface-contract.yaml`
- Ejecutable directamente: `no`
- Descripcion: `manifiesto tipado que fija frontera principal, consumers, herramienta primaria, compatibilidad y alcance real de cobertura`

## Contrato Ejecutable Canonico
- Tipo de contrato: `no aplica a la frontera principal`
- Archivo canonico: `no aplica`
- Resolucion: `la validacion ejecutable primaria vive en tests Bats del flujo`

## Herramienta Primaria de Validacion
- Herramienta primaria: `Bats`
- Superficie validada: `CLI/shell local y salida observable de --print-env`
- Relacion con Specmatic: `no aplica`

## Rol de interface-contract.yaml
- `interface-contract.yaml` actua como manifiesto obligatorio de resolucion para adopcion hibrida.
- No actua como contrato ejecutable directo de Specmatic.

## Consumidores y Necesidades

### Consumidores relevantes
- operador humano del repo
- automatizacion repo-local
- `lib/promote/workflows/common.sh`
- `tests/contracts/devbox-shell/run-contract-checks.sh`

### Necesidades del consumidor
- poder descubrir flags relevantes en help;
- poder importar entorno base del repo via `--print-env`;
- no recibir una falsa senal de shell "listo" cuando la verificacion requerida falla;
- depender del profile file resuelto por contrato y no de un hardcode legacy.

### Escenarios minimos a proteger
- help expone las flags protegidas;
- `--print-env` expone `DEVBOX_ENV_NAME="IHH"` y `DEVBOX_PROJECT_ROOT="<repo_root>"`;
- gating de readiness conserva `DEVBOX_SESSION_READY=0` antes de verificar en variante estricta;
- no TTY y marker presente fuerzan `--verify-only`;
- wiring del profile file conserva `devtools_profile_config_file()` y `DEVTOOLS_WIZARD_RC_FILE`.

### Degradaciones inaceptables
- eliminar `--print-env` como frontera observable;
- ocultar o saltarse el gate de readiness;
- volver a hardcodear `.devtools/.git-acprc` como ruta contractual primaria;
- presentar cobertura metodologica como si Specmatic validara el contrato principal.

## Compatibilidad

### Promesa de compatibilidad
- Los consumidores del flujo pueden seguir tratando `devbox shell --print-env` como frontera contractual base del repo y seguir esperando el gate observable de readiness bajo la variante estricta.

### Cambios compatibles
- ampliar documentacion o ejemplos sin cambiar la frontera principal;
- agregar checks contractuales adicionales que no rebajen ni contradigan la promesa vigente;
- mejorar trazabilidad de consumers y riesgos.

### Cambios de ruptura
- quitar flags protegidas de help;
- quitar exports base protegidos;
- convertir el gate estricto en exito silencioso;
- mover o hardcodear la ruta contractual del profile file sin declararlo.

### Reglas a materializar
- consumers, compatibilidad y assertions deben quedar materializados en `specs/contracts/devbox-shell/`.

## Artefactos Contractuales Requeridos
- `specs/contracts/devbox-shell/contract-map.yaml`
- `specs/contracts/devbox-shell/interface-contract.yaml`
- `specs/contracts/devbox-shell/consumer-needs.yaml`
- `specs/contracts/devbox-shell/compatibility-rules.yaml`
- `specs/contracts/devbox-shell/examples/`
- `specs/contracts/devbox-shell/schemas/`
- `specs/contracts/devbox-shell/assertions/`
- `tests/contracts/devbox-shell/`
- `.ci/contract-checks.yaml`

## Validacion Contractual Prevista
- Validacion principal: `Bats` sobre help, `--print-env`, gating y wiring contractual.
- Validacion complementaria: `jq` + `grep` dentro de la suite contractual para inspeccionar `devbox.json`.
- Validacion con Specmatic: `no aplica`
- Coverage prevista:
  - completa sobre los checks contractuales materializados;
  - parcial respecto al runtime total del shell y la rama interactiva no re-ejecutada;
  - fuera de alcance para la semantica interna completa de Devbox y la verificacion de red real.

## Riesgos y Limites
- riesgo de falsa cobertura si se presenta la suite Bats como validacion total del runtime;
- riesgo de deriva si se usa el helper `setup-wizard.sh` como sustituto de la frontera principal;
- riesgo de confusion por la coexistencia entre `.git-acprc` contractual y `.devtools/.git-acprc` legacy;
- limite metodologico: esta adopcion no ejecuta el flujo real ni integra CI real.

## Unknowns

### No bloquean
- orden exacto de toda la salida runtime de Devbox;
- consumidores no localizados del profile file legacy.

### Condicionan
- futura integracion de CI real;
- futura limpieza del seam legacy del profile file.

### Bloquean
- ninguno para materializar la adopcion hibrida del flujo.

## Criterio de Salida hacia Contract Adoption
- La frontera principal queda delimitada y no se rebaja a subfronteras mas comodas.
- La adopcion queda fijada como `hibrida`.
- La herramienta primaria queda fijada como `Bats`.
- `Specmatic` queda explicitamente marcado como `no aplica` para esta frontera principal.
- El arbol contractual puede materializarse sin necesidad de implementacion de producto.

# 05-contract-scope

- Flow id: `devbox-shell`
- Familia metodologica: `Contract-Driven`
- Estado: `draft`

## Autoridad de Entrada
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Objetivo Contractual del Flujo
- Proteger contractualmente la frontera observable del shell local `devbox shell` para este repo y la subfrontera `devbox shell --print-env` usada por consumidores no interactivos.
- Preservar la promesa central de que el repo controla root resolution, gate estricto, resolucion contractual de perfil/vendor y exposicion de toolchain suficiente para consumidores reales.
- Hacer visible, no invisible, la cobertura parcial y los side effects tolerados del flujo actual.

## Frontera Contractual Real

### Frontera principal
- `devbox shell` como flujo CLI / shell local gobernado por `devbox.json`, `bin/setup-wizard.sh` y libs core asociadas.

### Provider
- El repo `ihh-devtools` a traves de `devbox.json`, `bin/setup-wizard.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh` y `lib/core/config.sh`.

### Consumer(s)
- Operador interactivo que entra al shell del repo.
- `lib/promote/workflows/common.sh`, que consume `devbox shell --print-env` para disponer de `git-cliff`.

### Dentro del contrato
- resolucion de root/workspace relevante para el repo;
- decision entre variante estricta y permisiva;
- gate estricto cuando hay marker + TTY + verificacion valida;
- visibilidad del fallo cuando la verificacion estricta no satisface el gate;
- resolucion contractual de `vendor_dir` y `profile_file`;
- subfrontera `devbox shell --print-env` como export surface consumible por workflows internos;
- trazabilidad del consumer fallback en `common.sh`.

### Fuera del contrato
- internals de Devbox/Nix fuera de la superficie observable;
- texto exacto de mensajes cosmeticos o del prompt;
- detalles internos de cada paso de wizard mas alla de los checks observables relevantes;
- cobertura total de la sesion interactiva a partir de `print-env`;
- activacion de otras familias metodologicas.

### Cobertura esperada
- `parcial`

## Modo de Adopcion
- Modo: `hibrida`
- Justificacion: `la frontera principal es CLI/shell local y no cae honestamente en una superficie contractual estandar soportada directamente por Specmatic`
- Relacion con la frontera principal: `la frontera principal sigue siendo contractual, pero su validacion ejecutable primaria debe ser nativa del runtime shell/CLI`
- Motivo de adopcion hibrida, si aplica: `Specmatic no ofrece un dialecto directo honesto para esta frontera principal y no debe forzarse una API ficticia`

## Clasificacion de la Frontera
- Tipo de frontera: `CLI | shell local`
- Justificacion: el usuario entra por un comando local, el repo controla `devbox.json` y el wizard, y la experiencia principal ocurre en una shell contextualizada.

## Dialecto Contractual Adoptado
- Dialecto: `no aplica a la frontera principal`
- Justificacion: `la frontera principal no es HTTP, eventos, GraphQL, gRPC, SOAP ni otra superficie contractual estandar soportada directamente por Specmatic`
- Alternativas descartadas: `OpenAPI, AsyncAPI, GraphQL SDL, proto y WSDL para la frontera principal`
- Observaciones de cobertura: `se adopta un manifiesto tipado YAML para la resolucion contractual y un harness ejecutable Bats para validacion nativa shell/CLI; Specmatic queda en alcance nulo`

## Contrato Canonico del Flujo
- Tipo de contrato: `cli-shell-observable-contract`
- Artefacto canonico: `specs/contracts/devbox-shell/assertions/cli-contract.yaml`
- Ejecutable directamente: `no`
- Deriva a contrato ejecutable separado: `si`

## Contrato Ejecutable Canonico
- Tipo de contrato: `bats shell contract harness`
- Archivo canonico: `tests/contracts/devbox-shell/devbox-shell-contract.bats`
- Resolucion desde interface-contract.yaml: `si`

## Herramienta Primaria de Validacion
- Herramienta primaria: `Bats`
- Justificacion: permite validar una frontera CLI/shell local y una subfrontera observable `print-env` sin falsear la naturaleza del flujo.
- Superficie que valida: semantica observable del shell repo-controlado y export surface de `devbox shell --print-env`.
- Relacion con Specmatic: `no aplica`

## Rol de interface-contract.yaml
- Rol: `manifiesto tipado`
- Razon: `en adopcion hibrida debe resolver sin ambiguedad la frontera principal, la herramienta primaria, el contrato canonico, la cobertura declarada y el alcance nulo de Specmatic`

## Consumidores y Necesidades

### Consumidores relevantes
- operador interactivo del repo
- `lib/promote/workflows/common.sh`

### Necesidades del consumidor
- el operador necesita una sesion contextualizada cuyo estado listo/no listo no quede oculto;
- el consumer de changelog necesita exports suficientes para ejecutar `git-cliff` sin abrir una sesion interactiva;
- ambos consumidores necesitan que root/profile/vendor se resuelvan de forma estable y trazable.

### Escenarios minimos a proteger
- entrada interactiva con marker y verificacion satisfactoria;
- entrada interactiva con marker y verificacion fallida;
- llamada no interactiva a `devbox shell --print-env` para `git-cliff`.

### Degradaciones inaceptables
- habilitar ruta lista/contextualizada sin haber pasado el gate estricto;
- romper `print-env` para el consumer de changelog;
- vender como total una cobertura que solo es parcial;
- degradar la frontera principal a una API o dialecto falso.

## Compatibilidad

### Promesa de compatibilidad
- Mantener estable la frontera observable del shell local y la subfrontera `print-env` en lo que afecta a sus consumidores reales, sin congelar texto cosmetico ni internals de Devbox.

### Cambios compatibles
- agregar exports auxiliares sin romper los requeridos;
- enriquecer mensajes o theming sin ocultar el estado del gate;
- refactorizar implementacion interna mientras se preserven root resolution, gate y consumer fallback;
- ampliar cobertura contractual sin reescribir la frontera principal.

### Cambios de ruptura
- eliminar o renombrar la entrada `devbox shell` para este flujo;
- romper el gate estricto o invertir su semantica visible;
- hacer que `devbox shell --print-env` deje de proveer el toolchain requerido por `common.sh`;
- sustituir la frontera principal por una superficie contractual distinta para acomodar tooling;
- ocultar side effects/materialidad relevante como si no existieran.

### Reglas a materializar
- las necesidades del operador y del consumer `common.sh` deben reflejarse en `consumer-needs.yaml`;
- la promesa de compatibilidad y sus rupturas deben reflejarse en `compatibility-rules.yaml`;
- la cobertura parcial y el alcance nulo de Specmatic deben quedar explicitados en `interface-contract.yaml`, `contract-map.yaml`, `tests/contracts/` y `.ci/contract-checks.yaml`.

## Artefactos Contractuales Requeridos
- `specs/contracts/devbox-shell/contract-map.yaml` - obligatorio
- `specs/contracts/devbox-shell/interface-contract.yaml` - obligatorio
- `specs/contracts/devbox-shell/consumer-needs.yaml` - obligatorio
- `specs/contracts/devbox-shell/compatibility-rules.yaml` - obligatorio
- `specs/contracts/devbox-shell/examples/` - obligatorio
- `specs/contracts/devbox-shell/schemas/` - obligatorio
- `specs/contracts/devbox-shell/assertions/` - obligatorio
- `tests/contracts/devbox-shell/` - obligatorio
- `.ci/contract-checks.yaml` - obligatorio

## Validacion Contractual Prevista
- Validacion principal: Bats valida la semantica observable del flujo shell/CLI y la subfrontera `print-env` en un harness controlado.
- Validacion con Specmatic: `no aplica`
- Cobertura ejecutable prevista: `parcial; cubre decision contractual observable, consumer fallback y export surface no interactiva`
- Cobertura parcial o fuera de alcance: `sesion interactiva completa con TTY real, prompt final y dependencias GH/SSH en entornos reales`
- Checks minimos requeridos: semantica de variante estricta, checks del wizard relevantes al contrato, consumer fallback de `common.sh`, exports requeridos de `print-env` y ausencia de falsa cobertura declarada.

## Riesgos y Limites
- Riesgo de falsa cobertura: presentar `print-env` como si cubriera toda la sesion interactiva.
- Riesgo de dialecto incorrecto: `forzar OpenAPI u otra superficie incompatible solo para acomodar Specmatic`
- Riesgo de compatibilidad debil: `no distinguir entre cambios cosmeticos y rupturas reales del gate o del consumer fallback`
- Riesgo de bloqueo ilegitimo por tooling: `detener la familia por no tener dialecto directo en Specmatic`
- Limites explicitos: `la adopcion materializada sera hibrida, la cobertura ejecutable sera parcial y Specmatic queda fuera de alcance en esta corrida`

## Unknowns

### No bloquean
- comportamiento final del prompt cuando falta `.starship.toml`
- relevancia futura de la rama de submodulo en otros checkouts

### Condicionan
- grado exacto de equivalencia entre la sesion interactiva y `devbox shell --print-env`
- aceptabilidad contractual del side effect global `init.defaultBranch=main`

### Bloquean
- ninguno identificado para pasar a adopcion materializada

## Criterio de Salida hacia Contract Adoption
- El flujo puede pasar legitimamente a `06-contract-adoption.md` cuando:
  - exista `interface-contract.yaml` como manifiesto tipado de adopcion hibrida;
  - el contrato canonico y el ejecutable canonico queden identificados sin ambiguedad;
  - consumers, compatibilidad, examples, schemas y assertions queden materializados;
  - `tests/contracts/devbox-shell/` y `.ci/contract-checks.yaml` respondan a la frontera real;
  - el alcance nulo de Specmatic y la cobertura parcial real queden declarados explicitamente.

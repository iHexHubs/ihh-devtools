# 05-contract-scope

- Flow id: `devbox-shell`
- Familia metodológica: `Contract-Driven`
- Estado: `approved`

## Autoridad de Entrada
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Objetivo Contractual del Flujo
- Proteger contractualmente que `devbox shell` siga siendo una entrada repo-local a una shell Devbox de este repositorio, con entorno base del repo y con intento condicionado de contextualizacion local de devtools.
- Proteger que la ruta "sesion lista/contextualizada" no se afirme como garantia universal, sino como resultado condicionado por TTY, marker, verificacion y disponibilidad del wizard.
- Proteger que el bootstrap persistente local siga siendo comportamiento permitido solo en la ruta full del wizard y no se confunda con obligacion de toda invocacion.

## Frontera Contractual Real

### Frontera principal
- Workflow local disparado por `devbox shell` dentro de este repo, que entra por `devbox.json:shell.init_hook`, expone entorno base repo-local y decide entre salida limitada o contextualizacion condicionada.

### Provider
- El repositorio `ihh-devtools` como provider del flujo, a traves de `devbox.json`, `bin/setup-wizard.sh`, `lib/core/contract.sh` y `lib/wizard/step-04-profile.sh`.

### Consumer(s)
- Usuario humano interactivo que abre una shell de trabajo repo-local.
- Consumidor no interactivo o de inspeccion que invoca `devbox shell --help` o `devbox shell --print-env`.

### Dentro del contrato
- Que `devbox shell` siga usando el `devbox.json` del repo como base de entorno.
- Que el entorno base del repo siga exponiendose para la shell o para la modalidad equivalente invocada.
- Que el flujo siga intentando contextualizacion local de devtools sin prometerla universalmente.
- Que la afirmacion de readiness siga siendo condicionada por verificacion y contexto, no por simple presencia de legado.
- Que la resolucion contractual de `profile_file` y `vendor_dir` siga subordinada al contrato repo (`devtools.repo.yaml`) y no quede redefinida silenciosamente por artefactos legacy.

### Fuera del contrato
- Textos exactos de consola, branding, selector de rol, prompt exacto y cantidad exacta de aliases efimeros.
- Ubicacion exacta de scripts auxiliares mientras el flujo preserve la frontera repo-local aprobada.
- Limpieza completa del legado `.devtools`, refactors del wizard o cambios de UX.
- Validacion exhaustiva de toda la experiencia interactiva con red, credenciales reales o PTY completa.

### Cobertura esperada
- `parcial`

## Modo de Adopcion
- Modo: `hibrida`
- Justificacion: la frontera principal es un workflow `CLI` y `shell local`, observable y contractual, pero no puede expresarse de forma honesta como OpenAPI, AsyncAPI, GraphQL SDL, `proto`, WSDL ni Arazzo sin degradar la interfaz real.
- Relacion con la frontera principal: `Specmatic` no puede actuar honestamente como validador principal de esta frontera porque la promesa central del flujo no es HTTP ni otra superficie estandar soportada.
- Motivo de adopcion hibrida, si aplica: la familia no se bloquea; la frontera principal se gobierna con manifiesto tipado y validacion nativa en `Bats`, dejando explicito que `Specmatic` no tiene cobertura aplicable en esta adopcion inicial.

## Clasificacion de la Frontera
- Tipo de frontera: `shell local`
- Justificacion: el flujo protege una sesion CLI repo-local, con entrada por `devbox shell`, entorno efimero, gating por TTY/marker y posibilidad condicionada de bootstrap local.

## Dialecto Contractual Adoptado
- Dialecto: `no aplica a la frontera principal`
- Justificacion: la frontera principal no es una API ni un bus de eventos; su promesa central depende de semantica de shell local, entorno efimero y ejecucion condicionada del wizard.
- Alternativas descartadas: `OpenAPI`, `AsyncAPI`, `GraphQL SDL`, `proto`, `WSDL` y `Arazzo` se descartan porque obligarian a falsear una interfaz local como si fuera una interfaz remota o una secuencia de operaciones de API.
- Observaciones de cobertura: se materializa un manifiesto tipado como contrato canonico no ejecutable directamente y una validacion contractual nativa en `Bats`; no se identifica subfrontera honestamente soportable por `Specmatic` sin rebajar la frontera principal.

## Contrato Canonico del Flujo
- Tipo de contrato: `manifiesto tipado del workflow shell local`
- Artefacto canonico: `specs/contracts/devbox-shell/interface-contract.yaml`
- Ejecutable directamente: `no`
- Deriva a contrato ejecutable separado: `no`

## Contrato Ejecutable Canonico
- Tipo de contrato: `no aplica a la frontera principal`
- Archivo canonico: `no aplica`
- Resolucion desde interface-contract.yaml: `no aplica`

## Herramienta Primaria de Validacion
- Herramienta primaria: `Bats`
- Justificacion: `Bats` es una herramienta nativa y ejecutable para shell local, y puede correrse dentro del propio entorno expuesto por `devbox shell --print-env` sin fingir que la frontera es una API.
- Superficie que valida: ejecucion segura de la frontera observable (`devbox shell --help`, `devbox shell --print-env`) y resolucion contractual repo-local de `profile_file`/`vendor_dir`.
- Relacion con Specmatic: `no aplica`

## Rol de interface-contract.yaml
- Rol: `manifiesto tipado`
- Razon: debe resolver sin ambiguedad la adopcion hibrida, el tipo de frontera, la herramienta primaria, el alcance real de `Specmatic` y la relacion con compatibilidad, examples y assertions.

## Consumidores y Necesidades

### Consumidores relevantes
- Operador o desarrollador que necesita entrar a una shell Devbox repo-local valida.
- Consumidor de inspeccion o automatizacion local que necesita validar el entorno base mediante `--help` o `--print-env` sin ejecutar bootstrap completo.

### Necesidades del consumidor
- Que la shell base repo-local siga abriendo contra el `devbox.json` del repo.
- Que el entorno base del repo, incluido `DEVBOX_ENV_NAME=IHH`, siga estando disponible en la modalidad limitada observable.
- Que la ruta "sesion lista/contextualizada" siga dependiendo de verificacion y contexto, no de una promesa absoluta.
- Que la ruta no interactiva o de inspeccion no produzca una falsa afirmacion de readiness completa.

### Escenarios minimos a proteger
- `devbox shell --help` sigue exponiendo la superficie CLI esperada del subcomando.
- `devbox shell --print-env` sigue exponiendo el entorno base del repo.
- La resolucion de `profile_file` desde `devtools.repo.yaml` sigue apuntando a `./.git-acprc` como autoridad contractual, aunque persistan compatibilidades legacy.

### Degradaciones inaceptables
- Que `devbox shell` deje de ser repo-local o deje de depender de `devbox.json`.
- Que `--print-env` deje de exponer el entorno base del repo.
- Que la readiness se afirme universalmente sin verificacion.
- Que `.devtools/.git-acprc` o `.devtools/.setup_completed` pasen a gobernar silenciosamente el contrato aprobado.

## Compatibilidad

### Promesa de compatibilidad
- Se preserva la promesa v1 de shell base repo-local con entorno base del repo e intento condicionado de contextualizacion local.

### Cambios compatibles
- Cambios internos en busqueda de scripts, mensajes, prompt o aliases, mientras no alteren la promesa contractual visible.
- Compatibilidad temporal con artefactos legacy, solo si queda explicitamente subordinada al contrato repo y no gobierna readiness ni persistencia por si sola.
- Ajustes internos del wizard que preserven la separacion entre shell base, verificacion limitada y bootstrap full.

### Cambios de ruptura
- Eliminar `shell.init_hook` o desacoplar `devbox shell` del `devbox.json` del repo.
- Convertir la readiness en garantia universal.
- Requerir la ruta full del wizard para toda invocacion, incluida la modalidad limitada.
- Cambiar la autoridad contractual de `profile_file` o `vendor_dir` sin actualizar el contrato materializado.

### Reglas a materializar
- Mantener separadas shell base, verificacion limitada y bootstrap full.
- Mantener `profile_file=.git-acprc` como autoridad contractual, aunque exista compatibilidad legacy.
- No promocionar `--print-env` como evidencia suficiente de contextualizacion completa.
- No tratar compatibilidad legacy como fuente normativa de readiness.

## Artefactos Contractuales Requeridos
- `specs/contracts/devbox-shell/contract-map.yaml` - `obligatorio`
- `specs/contracts/devbox-shell/interface-contract.yaml` - `obligatorio`
- `specs/contracts/devbox-shell/consumer-needs.yaml` - `obligatorio`
- `specs/contracts/devbox-shell/compatibility-rules.yaml` - `obligatorio`
- `specs/contracts/devbox-shell/examples/` - `obligatorio`
- `specs/contracts/devbox-shell/schemas/` - `obligatorio`
- `specs/contracts/devbox-shell/assertions/` - `obligatorio`
- `tests/contracts/devbox-shell/` - `obligatorio`
- `.ci/contract-checks.yaml` - `obligatorio`

## Validacion Contractual Prevista
- Validacion principal: `checks en Bats sobre la frontera observable segura y sobre la resolucion contractual repo-local`
- Validacion con Specmatic: `no aplica`
- Cobertura ejecutable prevista: `ayuda CLI, modalidad --print-env, resolucion de profile_file/vendor_dir y guardas contractuales de compatibilidad visibles`
- Cobertura parcial o fuera de alcance: `PTY interactiva completa, credenciales reales GH/SSH, selector de rol, prompt final y side effects persistentes reales del wizard`
- Checks minimos requeridos: `help del subcomando`, `print-env expone DEVBOX_ENV_NAME=IHH`, `resolucion contractual de profile_file`, `reglas de compatibilidad declaradas y asserts de no falsa readiness`

## Riesgos y Limites
- Riesgo de falsa cobertura: `confundir help/print-env con cobertura total del workflow interactivo`
- Riesgo de dialecto incorrecto: `forzar OpenAPI o Arazzo sobre una frontera shell local`
- Riesgo de compatibilidad debil: `permitir que .devtools siga gobernando readiness o persistencia por inercia`
- Riesgo de bloqueo ilegitimo por tooling: `detener la familia por ausencia de soporte directo de Specmatic`
- Limites explicitos: `esta adopcion no cubre la PTY completa ni valida side effects persistentes reales con red/credenciales`

## Unknowns

### No bloquean
- Texto exacto del menu de rol, prompt final y branding visible.
- Exit codes exhaustivos de todas las ramas interactivas.

### Condicionan
- Alcance exacto del `init_hook` bajo `devbox shell --print-env` respecto de exports efimeros adicionales.
- Modo exacto de compatibilidad futura entre `.git-acprc` y `.devtools/.git-acprc` si el legado se mantiene temporalmente.

### Bloquean
- Ninguno identificado con base suficiente para impedir la adopcion hibrida.

## Criterio de Salida hacia Contract Adoption
- El flujo puede pasar a `06-contract-adoption.md` cuando la carpeta `specs/contracts/devbox-shell/` materialice el manifiesto tipado, necesidades del consumidor, reglas de compatibilidad, examples/schemas/assertions, la validacion contractual en `tests/contracts/devbox-shell/` y el enforcement en `.ci/contract-checks.yaml`, dejando explicito que la herramienta primaria es `Bats`, que `Specmatic` no aplica a la frontera principal ni a subfronteras identificadas, y que la cobertura final sigue siendo parcial pero metodologicamente valida.

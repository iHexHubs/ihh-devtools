# 06-contract-adoption

- Flow id: `devbox-shell`
- Familia metodológica: `Contract-Driven`
- Estado: `approved`

## Autoridad de Entrada
- Contract scope: `specs/flows/devbox-shell/05-contract-scope.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Resumen de Adopcion Contractual
- Se adopto contractualmente el flujo `devbox shell` como workflow `shell local` repo-local.
- La adopcion es `hibrida`: el contrato principal observable vive como manifiesto tipado en `specs/contracts/devbox-shell/interface-contract.yaml`; no existe contrato ejecutable canonico en un dialecto soportado por `Specmatic`.
- Quedo materializado el arbol contractual completo esperado por la familia: memoria metodologica `05/06`, carpeta contractual, tests contractuales y enforcement en `.ci`.
- La adopcion minima alcanzada consiste en: contrato canonico materializado, consumers y compatibilidad materializados, examples/schemas/assertions materializados, suite contractual Bats ejecutada con exito y CI contractual definido.

## Estado de Artefactos Materializados
- `specs/contracts/devbox-shell/contract-map.yaml`: `presente`
- `specs/contracts/devbox-shell/interface-contract.yaml`: `presente`
- `specs/contracts/devbox-shell/consumer-needs.yaml`: `presente`
- `specs/contracts/devbox-shell/compatibility-rules.yaml`: `presente`
- `specs/contracts/devbox-shell/examples/`: `presente`
- `specs/contracts/devbox-shell/schemas/`: `presente`
- `specs/contracts/devbox-shell/assertions/`: `presente`
- `tests/contracts/devbox-shell/`: `presente`
- `.ci/contract-checks.yaml`: `presente`

## Contrato Canonico Adoptado
- Tipo: `manifiesto tipado del workflow shell local`
- Archivo o artefacto canonico: `specs/contracts/devbox-shell/interface-contract.yaml`
- Ejecutable directamente: `no`
- Relacion con contrato ejecutable: `no existe contrato ejecutable canonico separado; la validacion ejecutable se deriva a la suite Bats`

## Contrato Ejecutable Adoptado
- Dialecto: `no aplica a la frontera principal`
- Archivo canonico: `no aplica`
- Resolucion en Specmatic: `no aplica`
- Rol de interface-contract.yaml: `manifiesto tipado`

## Herramienta Primaria de Validacion Adoptada
- Herramienta primaria: `Bats`
- Superficie validada: `help de devbox shell, print-env, resolucion contractual repo-local y guardas estructurales de readiness/profile wiring`
- Tipo de checks principales: `suite Bats ejecutada dentro del entorno expuesto por devbox shell --print-env`
- Relacion con Specmatic: `no aplica`

## Contract Map Adoptado
- Indice rector: `specs/contracts/devbox-shell/contract-map.yaml`
- Artefactos gobernados: `interface-contract`, `consumer-needs`, `compatibility-rules`, `examples`, `schemas`, `assertions`, `tests/contracts/devbox-shell` y `.ci/contract-checks.yaml`
- Relacion con contrato canonico: `declara que interface-contract.yaml es el contrato canonico del flujo`
- Relacion con herramienta primaria y Specmatic: `ancla Bats como validador principal y declara Specmatic como no aplicable`

## Consumidores y Compatibilidad Materializados
- Consumers cubiertos: `interactive_repo_operator` y `non_interactive_inspector`
- Necesidades cubiertas: `shell repo-local`, `entorno base visible`, `readiness condicionada`, `modalidad segura de inspeccion`
- Compatibilidad ejecutable: `help surface`, `print-env`, `vendor_dir=.devtools`, `profile_file=.git-acprc`, guardas verify-only/readiness`
- Compatibilidad declarativa o condicionada: `limites de PTY completa`, `subordinacion del legado .devtools`, `no usar print-env como prueba de readiness completa`

## Examples, Schemas y Assertions
- Examples: `help-surface.yaml`, `print-env-surface.yaml`, `interactive-readiness-conditional.yaml`
- Schemas: `contract-example.schema.json` y `devtools-repo-contract.schema.json`
- Assertions: `core-assertions.yaml`
- Relacion con el contrato canonico: `los examples describen escenarios consumidos, los schemas fijan estructuras auxiliares y las assertions fijan invariants contractuales y limites de cobertura`

## Validacion Contractual Adoptada
- Checks principales de la herramienta primaria: `suite Bats con 5 checks sobre help, print-env, resolucion contractual, wiring del profile y readiness guards`
- Checks principales con Specmatic: `no aplica`
- Compatibilidad verificada: `surface CLI minima, entorno base, resolucion de profile_file/vendor_dir y permanencia de las guardas de readiness`
- Cobertura contractual real: `parcial pero ejecutable para la superficie segura y repo-local`
- Cobertura parcial o fuera de alcance: `PTY interactiva completa, selector de rol, prompt final, credenciales GH/SSH y side effects persistentes reales`
- Limitaciones conocidas: `la cobertura de readiness sigue siendo estructural; no sustituye una PTY viva con credenciales`

## Tests Contractuales Adoptados
- Ubicacion: `tests/contracts/devbox-shell/`
- Tipo de checks: `suite Bats y runner repo-local`
- Relacion con el contrato canonico: `ejecutan los escenarios y assertions derivadas del manifiesto tipado`
- Relacion con la herramienta primaria: `Bats es la herramienta primaria y el runner la bootstrapea desde devbox shell --print-env`
- Relacion con Specmatic: `no aplica`

## Enforcement en CI
- Ubicacion: `.ci/contract-checks.yaml`
- Herramienta primaria ejecutada: `Bats`
- Checks obligatorios: `bootstrap del entorno repo-local`, `suite Bats contractual`
- Condiciones de falla: `caida de help/print-env`, ruptura de resolucion contractual o desaparicion de guardas de readiness`
- Relacion con el contrato y la compatibilidad: `el archivo enlaza al manifiesto tipado y a compatibility-rules.yaml como autoridad operativa`
- Relacion con Specmatic: `no aplica`

## Cobertura Contractual Final

### Cobertura completa
- Superficie `devbox shell --help`
- Superficie `devbox shell --print-env`
- Resolucion contractual de `vendor_dir` y `profile_file`

### Cobertura parcial
- Guardas de readiness y verify-only observadas como estructura contractual
- Wiring entre `setup-wizard.sh` y `step-04-profile.sh`
- Compatibilidad legacy explicitamente subordinada al contrato

### Fuera de alcance
- PTY interactiva completa
- Reparacion viva de GH/SSH
- Mutaciones persistentes reales del wizard sobre estado local del usuario

## Riesgos Residuales
- Riesgo de falsa cobertura si alguien trata `--print-env` como evidencia suficiente de readiness completa.
- Riesgo de compatibilidad si el legado `.devtools` vuelve a imponerse como fuente normativa sin actualizar el contrato materializado.
- Riesgo propio de adopcion hibrida: no existe contrato ejecutable directo para `Specmatic`, por lo que la disciplina depende de mantener explicita la frontera shell local y sus limites.

## Unknowns

### No bloquean
- Texto final exacto del menu de rol, branding y prompt.
- Exit codes exhaustivos de todas las ramas interactivas.

### Condicionan
- Alcance exacto de los exports efimeros adicionales bajo `--print-env`.
- Estrategia futura para retirar o encapsular compatibilidad legacy sin reabrir el contrato base.

### Bloquean
- Ninguno identificado para esta adopcion.

## Criterio de Adopcion Suficiente
- Puede afirmarse que `devbox-shell` quedo adoptado contractualmente porque la familia dejo explicitos la frontera contractual real, el modo `hibrida`, el dialecto `no aplica a la frontera principal`, el contrato canonico materializado, el rol de `interface-contract.yaml`, las necesidades del consumidor, las reglas de compatibilidad, la cobertura real, que valida `Bats`, que vive en `tests/contracts/devbox-shell/`, que vive en `.ci/contract-checks.yaml` y que `Specmatic` no aplica honestamente a esta frontera ni a subfronteras identificadas en esta adopcion.

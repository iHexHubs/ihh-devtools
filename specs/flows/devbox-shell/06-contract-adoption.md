# 06-contract-adoption

- Flow id: `devbox-shell`
- Familia metodologica: `Contract-Driven`
- Estado: `approved`

## Autoridad de Entrada
- Contract scope: `specs/flows/devbox-shell/05-contract-scope.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Resumen de Adopcion Contractual
- Se adopto `Contract-Driven` para `devbox-shell` en modo `hibrida`.
- Se materializo un contrato canonico basado en manifiesto tipado para una frontera `CLI` / `shell local`.
- La validacion contractual primaria adoptada es `Bats`, reutilizando la suite contractual existente del flujo y conectandola explicitamente a assets canonicos de contrato.
- `Specmatic` queda marcado como `no aplica` para la frontera principal y no se materializa contrato ejecutable directo bajo esa herramienta.
- La adopcion minima alcanzada consiste en: frontera delimitada, consumers y compatibilidad materializados, tests contractuales trazados, enforcement declarativo de CI y cobertura real honestamente clasificada.

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
- Tipo: `shell-local workflow contract manifest`
- Archivo o artefacto canonico: `specs/contracts/devbox-shell/interface-contract.yaml`
- Ejecutable directamente: `no`
- Relacion con contrato ejecutable: `los checks ejecutables viven en tests Bats y estan gobernados por contract-map.yaml`

## Contrato Ejecutable Adoptado
- Dialecto: `no aplica a la frontera principal`
- Archivo canonico: `no aplica`
- Resolucion en Specmatic: `no aplica`
- Rol de interface-contract.yaml: `manifiesto tipado de resolucion para adopcion hibrida`

## Herramienta Primaria de Validacion Adoptada
- Herramienta primaria: `Bats`
- Superficie validada: `CLI/shell local y salida observable de --print-env, mas wiring contractual e init_hook inspeccionado por jq/grep dentro de la suite`
- Tipo de checks principales: `help flags, exports base, readiness gate y profile resolution wiring`
- Relacion con Specmatic: `no aplica`

## Contract Map Adoptado
- Indice rector: `specs/contracts/devbox-shell/contract-map.yaml`
- Artefactos gobernados: `interface-contract.yaml`, `consumer-needs.yaml`, `compatibility-rules.yaml`, `examples/`, `schemas/`, `assertions/`, `tests/contracts/devbox-shell/`, `.ci/contract-checks.yaml`
- Relacion con contrato canonico: `identifica interface-contract.yaml como contrato canonico de la frontera`
- Relacion con herramienta primaria y Specmatic: `fija Bats como herramienta primaria y Specmatic deshabilitado`

## Consumidores y Compatibilidad Materializados
- Consumers cubiertos: `human-operator`, `repo-automation`, `lib/promote/workflows/common.sh`, `tests/contracts/devbox-shell/run-contract-checks.sh`
- Necesidades cubiertas: `help visible`, `print-env usable`, `gate de readiness honesto`, `profile file contractual`
- Compatibilidad ejecutable: `checks Bats sobre flags, exports, gating y wiring`
- Compatibilidad declarativa o condicionada: `rama interactiva completa, consumers legacy no localizados y limites del runtime Devbox`

## Examples, Schemas y Assertions
- Examples: `specs/contracts/devbox-shell/examples/*.yaml`
- Schemas: `specs/contracts/devbox-shell/schemas/*.yaml`
- Assertions: `specs/contracts/devbox-shell/assertions/*.yaml`
- Relacion con el contrato canonico: `documentan y estructuran la frontera canonica sin pretender sustituirla por un dialecto que no aplica`

## Validacion Contractual Adoptada
- Checks principales de la herramienta primaria: `suite Bats del flujo y wrapper run-contract-checks.sh`
- Checks principales con Specmatic: `no aplica`
- Compatibilidad verificada: `flags protegidas, exports base, readiness gate, profile resolution wiring`
- Cobertura contractual real: `la superficie observable materializada en los checks`
- Cobertura parcial o fuera de alcance: `rama interactiva completa, runtime interno de Devbox, red real y CI real`
- Limitaciones conocidas: `no hay corrida nueva en este run; la adopcion sigue siendo metodologica/contractual`

## Tests Contractuales Adoptados
- Ubicacion: `tests/contracts/devbox-shell/`
- Tipo de checks: `Bats + wrapper bash`
- Relacion con el contrato canonico: `ejecutan los escenarios minimos protegidos por interface-contract.yaml y assertions/`
- Relacion con la herramienta primaria: `son la implementacion ejecutable primaria del contrato`
- Relacion con Specmatic: `no aplica`

## Enforcement en CI
- Ubicacion: `.ci/contract-checks.yaml`
- Herramienta primaria ejecutada: `Bats`
- Checks obligatorios: `run-contract-checks.sh` y presencia/coherencia de assets contractuales
- Condiciones de falla: `cualquier check requerido no pasa o desaparece la superficie contractual protegida`
- Relacion con el contrato y la compatibilidad: `traza cada check a la compatibilidad prometida`
- Relacion con Specmatic: `no aplica`

## Cobertura Contractual Final

### Cobertura completa
- help flags protegidas
- exports base de `--print-env`
- gate observable de readiness en variante estricta
- wiring contractual del profile file

### Cobertura parcial
- rama interactiva de rol/prompt
- side effects de version/submodulo/red
- consumidores legacy no localizados del profile file

### Fuera de alcance
- runtime interno total de Devbox
- integracion real de CI
- evaluacion runtime de GH/SSH

## Riesgos Residuales
- sigue existiendo confusion potencial entre `.git-acprc` contractual y `.devtools/.git-acprc` legacy;
- la ausencia de corrida nueva limita el grado de certeza sobre orden exacto del output runtime;
- cualquier intento futuro de introducir `Specmatic` sin una subfrontera real soportada degradaria la honestidad metodologica de esta adopcion.

## Unknowns

### No bloquean
- orden exacto del output completo de Devbox;
- existencia de consumidores externos no localizados del profile file legacy.

### Condicionan
- futura integracion del manifiesto CI con workflow real;
- futura limpieza del seam legacy.

### Bloquean
- ninguno para considerar suficiente la adopcion contractual materializada en esta corrida.

## Criterio de Adopcion Suficiente
- La frontera contractual real esta explicitamente fijada.
- La adopcion hibrida esta explicitamente declarada.
- La herramienta primaria real de validacion esta explicitamente declarada.
- `Specmatic` queda explicitamente declarado como `no aplica` para la frontera principal.
- Consumers, compatibilidad, examples, schemas, assertions, tests y enforcement declarativo quedan materializados y trazables.

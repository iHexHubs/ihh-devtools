# 06-contract-adoption

- Flow id: `devbox-shell`
- Familia metodologica: `Contract-Driven`
- Estado: `draft`

## Autoridad de Entrada
- Contract scope: `specs/flows/devbox-shell/05-contract-scope.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Spec-as-source: `specs/flows/devbox-shell/04-spec-as-source.md`

## Resumen de Adopcion Contractual
- Se adopto contractualmente el flujo `devbox-shell` como frontera principal CLI/shell local con subfrontera observable `devbox shell --print-env`.
- La adopcion es `hibrida`.
- Quedo materializado el arbol contractual completo bajo `specs/contracts/devbox-shell/`, `tests/contracts/devbox-shell/` y `.ci/contract-checks.yaml`.
- Quedo pendiente solo ampliar cobertura futura si se quiere mas paridad con la sesion interactiva completa.
- La adopcion minima alcanzada consiste en contrato canonico, manifiesto de resolucion, consumers, compatibilidad, examples/schemas/assertions, tests contractuales y enforcement de CI con cobertura parcial honesta.

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
- Tipo: `cli-shell-observable-contract`
- Archivo o artefacto canonico: `specs/contracts/devbox-shell/assertions/cli-contract.yaml`
- Ejecutable directamente: `no`
- Relacion con contrato ejecutable: `deriva a un harness Bats que valida la frontera shell/CLI y la subfrontera print-env`

## Contrato Ejecutable Adoptado
- Dialecto: `bats shell contract harness | no aplica a la frontera principal como dialecto Specmatic`
- Archivo canonico: `tests/contracts/devbox-shell/devbox-shell-contract.bats`
- Resolucion en Specmatic: `no aplica`
- Rol de interface-contract.yaml: `manifiesto tipado de resolucion en adopcion hibrida`

## Herramienta Primaria de Validacion Adoptada
- Herramienta primaria: `Bats`
- Superficie validada: `gate observable de la variante estricta, export surface de print-env y trazabilidad del consumer common.sh`
- Tipo de checks principales: `checks estructurales sobre el repo + corrida controlada de print-env en copia temporal`
- Relacion con Specmatic: `no aplica`

## Contract Map Adoptado
- Indice rector: `specs/contracts/devbox-shell/contract-map.yaml`
- Artefactos gobernados: `interface-contract.yaml`, `consumer-needs.yaml`, `compatibility-rules.yaml`, `examples/`, `schemas/`, `assertions/`, `tests/contracts/devbox-shell/`, `.ci/contract-checks.yaml`
- Relacion con contrato canonico: declara `assertions/cli-contract.yaml` como contrato canonico.
- Relacion con herramienta primaria y Specmatic: declara `Bats` como herramienta primaria y `Specmatic` con alcance nulo.

## Consumidores y Compatibilidad Materializados
- Consumers cubiertos: `interactive-operator` y `promote-changelog-fallback`
- Necesidades cubiertas: `visibilidad del gate estricto`, `toolchain util por print-env`, `root/profile/vendor resolubles`
- Compatibilidad ejecutable: `Bats verifica gate, print-env y fallback de common.sh`
- Compatibilidad declarativa o condicionada: `cosmetica del prompt`, `cobertura total de la sesion interactiva`, `aceptacion del side effect global de init.defaultBranch`

## Examples, Schemas y Assertions
- Examples: `interactive-ready.yaml`, `interactive-verify-failure.yaml`, `print-env-noninteractive.yaml`
- Schemas: `cli-scenario.schema.json`, `normalized-print-env.schema.json`
- Assertions: `cli-contract.yaml`, `runtime-invariants.yaml`
- Relacion con el contrato canonico: los examples fijan escenarios, los schemas tipan auxiliares y las assertions alojan el contrato canonico y sus invariantes.

## Validacion Contractual Adoptada
- Checks principales de la herramienta primaria: 5/5 Bats en verde, cubriendo gate estricto, verify-only del wizard, trazabilidad de `common.sh`, `print-env` en copia temporal y ausencia de aliases persistentes.
- Checks principales con Specmatic: `no aplica`
- Compatibilidad verificada: `semantica del gate`, `subfrontera print-env`, `consumer fallback de git-cliff`
- Cobertura contractual real: `parcial y explicitamente declarada`
- Cobertura parcial o fuera de alcance: `sesion interactiva completa con TTY real, GH/SSH reales y prompt final`
- Limitaciones conocidas: `los checks dinamicos requieren que Devbox pueda resolver paquetes en la copia temporal`

## Tests Contractuales Adoptados
- Ubicacion: `tests/contracts/devbox-shell/`
- Tipo de checks: `Bats + helper de copia temporal`
- Relacion con el contrato canonico: cada test deriva de `assertions/cli-contract.yaml` y `runtime-invariants.yaml`.
- Relacion con la herramienta primaria: `Bats` es el ejecutor canonico.
- Relacion con Specmatic: `no aplica`

## Enforcement en CI
- Ubicacion: `.ci/contract-checks.yaml`
- Herramienta primaria ejecutada: `Bats`
- Checks obligatorios: `devbox-shell-contract-bats`
- Condiciones de falla: fallo de la suite, cambio del alcance no-aplica de Specmatic sin revisar el contrato, o falsa presentacion de cobertura completa.
- Relacion con el contrato y la compatibilidad: enforcea el contrato canonico, las rules de compatibilidad y la cobertura parcial declarada.
- Relacion con Specmatic: `no aplica`

## Cobertura Contractual Final

### Cobertura completa
- Ninguna declarada. La adopcion evita afirmar cobertura total que hoy no es honesta.

### Cobertura parcial
- gate observable de la variante estricta;
- verify-only del wizard como parte contractual visible;
- export surface de `devbox shell --print-env`;
- trazabilidad del consumer `lib/promote/workflows/common.sh`;
- no persistencia de aliases Git en la corrida no interactiva observada.

### Fuera de alcance
- UX interactiva completa con TTY real y credenciales reales;
- internals de Devbox/Nix fuera de la superficie observable;
- prompt/theming final;
- otras familias metodologicas.

## Riesgos Residuales
- riesgo de falsa cobertura si alguien toma `print-env` como sustituto total de la sesion interactiva;
- riesgo de aceptar sin discutir el side effect global de `init.defaultBranch=main`;
- riesgo de depender de red para resolver paquetes de Devbox en copias temporales frias;
- riesgo de futura deriva si se intenta introducir Specmatic sin una subfrontera realmente compatible.

## Unknowns

### No bloquean
- fallback exacto del prompt sin `.starship.toml`
- utilidad real de la rama de submodulo en otros checkouts

### Condicionan
- grado exacto de paridad entre `print-env` y la sesion interactiva
- aceptacion contractual del side effect global de Git

### Bloquean
- ninguno identificado para esta adopcion

## Criterio de Adopcion Suficiente
- El flujo puede considerarse adoptado contractualmente de forma suficiente cuando:
  - la frontera principal queda explicitada como CLI/shell local;
  - la adopcion hibrida queda declarada sin bloquear la familia;
  - el contrato canonico y el ejecutable canonico quedan identificados sin ambiguedad;
  - `interface-contract.yaml` resuelve la adopcion;
  - consumers, compatibilidad, examples, schemas y assertions quedan materializados;
  - `tests/contracts/devbox-shell/` valida la superficie real disponible;
  - `.ci/contract-checks.yaml` enforcea esa misma realidad;
  - y la cobertura parcial queda declarada sin maquillaje.

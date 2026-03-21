# Spec as Source — `devbox-shell`

## Flow id
`devbox-shell`

## Spec de referencia

### Intencion funcional relevante
- Proteger el flujo por el cual este repo usa `devbox shell` para exponer un entorno base y, cuando corresponde, una sesion contextualizada condicionada por verificacion.

### Contrato visible relevante
- `devbox shell --help` mantiene visibles `--print-env`, `--config` y `--env`.
- `devbox shell --print-env` sigue exponiendo al menos `DEVBOX_ENV_NAME="IHH"` y `DEVBOX_PROJECT_ROOT="<repo_root>"`.
- La variante estricta no declara la sesion lista sin exito del wizard.
- La ruta del archivo de perfiles del wizard sigue resolviendose desde el contrato repo-local.

### Invariants relevantes
- La frontera principal sigue siendo CLI/shell local.
- `--print-env` sigue siendo la frontera observable para automatizacion.
- El profile file no vuelve a hardcodearse a la ruta legacy del vendor dir.

### Failure modes relevantes
- falla de `--print-env` para consumidores repo-locales;
- falla o ausencia del wizard en variante estricta;
- herramientas requeridas ausentes en la rama correspondiente del wizard.

### Candidatos de aceptacion heredados relevantes
- flags de help visibles;
- exports base presentes en `--print-env`;
- gate de readiness conservado;
- wiring contractual del profile file conservado.

## Partes del codigo que ya cumplen
- `devbox.json` ya declara `DEVBOX_ENV_NAME=IHH` y el `init_hook`.
- `.devbox/gen/scripts/.hooks.sh` ya conserva el gate por `DEVTOOLS_SPEC_VARIANT`, marker y no TTY.
- `bin/setup-wizard.sh` ya resuelve `PROFILE_CONFIG_FILE` mediante `devtools_profile_config_file "$REAL_ROOT"`.
- `lib/wizard/step-04-profile.sh` ya consume `DEVTOOLS_WIZARD_RC_FILE`.
- `tests/contracts/devbox-shell/devbox-shell-contract.bats` ya expresa checks base alineados con la frontera observable.
- `lib/promote/workflows/common.sh` ya consume `devbox shell --print-env` como frontera de entorno para automatizacion.

## Gaps a cerrar

### Gaps claros
- Faltaba cerrar y persistir el backbone SDD del flujo dentro del repo.
- Faltaba activar explicitamente `Contract-Driven` para esta frontera CLI/shell local.
- Faltaba materializar un arbol contractual canonico bajo `specs/contracts/devbox-shell/` y `.ci/contract-checks.yaml`.

### Gaps parciales
- La cobertura contractual existente via Bats no estaba formalmente conectada a documentos canonicos de contrato, compatibilidad y consumers.
- La persistencia del archivo legacy `.devtools/.git-acprc` no estaba reflejada como seam y riesgo visible.

### Gaps dependientes de decision abierta
- Integrar la ejecucion real de `.ci/contract-checks.yaml` en GitHub Actions queda pendiente de una fase posterior de implementacion.

## Cambios necesarios derivados del spec
- Crear y cerrar `01-discovery.md`, `02-spec-first.md`, `03-spec-anchored.md` y `04-spec-as-source.md`.
- Activar `Contract-Driven` en modo honesto para esta frontera.
- Materializar:
  - `05-contract-scope.md`
  - `06-contract-adoption.md`
  - `specs/contracts/devbox-shell/`
  - `.ci/contract-checks.yaml`
- Dejar la relacion entre contrato canonico, consumers, compatibilidad y tests contractuales explicitamente trazada.

## Cambios opcionales
- Migrar o retirar el archivo legacy `.devtools/.git-acprc` cuando exista autorizacion para tocar comportamiento o datos locales.
- Integrar ejecucion real del manifiesto `.ci/contract-checks.yaml` con la pipeline del repo.
- Añadir validacion runtime adicional para la rama interactiva, si luego se autoriza evaluacion.

## Cambios explicitamente fuera de alcance
- Modificar `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh` o la logica de runtime del shell.
- Ejecutar el flujo real, pruebas de red, evaluacion o review.
- Activar `Context-Driven` o `Agentic QA`.
- Convertir una subfrontera mas comoda en sustituto del contrato principal CLI/shell local.

## Superficies principales de intervencion

### Superficies principales
- `specs/flows/devbox-shell/`
- `specs/contracts/devbox-shell/`
- `tests/contracts/devbox-shell/`
- `.ci/contract-checks.yaml`

### Superficies secundarias
- `AGENTS.md`

### Zonas de alto riesgo
- presentar cobertura Bats parcial como si fuera cobertura total de todo el runtime Devbox;
- presentar `Specmatic` como herramienta principal cuando no aplica honestamente a la frontera principal;
- tocar archivos de producto o runtime bajo el pretexto de materializacion metodologica.

## Seams, compatibilidades y zonas de riesgo
- Seam confirmado: el hook tolera submodulo/.gitmodules aunque el repo actual no tenga `.gitmodules`.
- Seam confirmado: existen rutas redundantes y compatibilidad anidada para scripts corporativos.
- Riesgo visible: el contrato repo-local ya apunta a `.git-acprc` root, pero persiste `.devtools/.git-acprc` en el snapshot actual.
- Riesgo visible: parte de la promesa observable se sostiene por artefactos generados y tests existentes, no por corrida nueva en este run.

## Validacion obligatoria

### Comportamientos observables a validar
- ayuda CLI minima protegida;
- exports base de `--print-env`;
- gate de readiness en variante estricta;
- wiring contractual del profile file.

### Divergencias que deben quedar cerradas
- la documentacion contractual debe declarar explicitamente la coexistencia de `.git-acprc` contractual y `.devtools/.git-acprc` legacy.
- la adopcion contractual debe declarar explicitamente si `Specmatic` aplica o no.

### Evidencias minimas de cumplimiento
- documentos SDD y Contract-Driven consistentes entre si;
- contrato canonico y mapa contractual materializados;
- tests contractuales y CI manifest trazados al contrato canonico;
- cobertura parcial y fuera de alcance declaradas honestamente.

### Riesgos de validacion insuficiente
- falsa apariencia de cobertura completa;
- falsa apariencia de adopcion directa con `Specmatic`;
- omision de consumers reales de `--print-env`.

## Candidatos de aceptacion listos para ejecucion metodologica
- El arbol metodologico del flujo queda completo y trazable.
- La adopcion contractual queda declarada como `hibrida`.
- El contrato canonico identifica herramienta primaria, consumers, compatibilidad y coverage real.
- `tests/contracts/devbox-shell/` queda alineado con el contrato materializado.

## Criterio de cumplimiento

### Cumplimiento minimo
- El backbone SDD queda cerrado.
- `Contract-Driven` queda activado explicitamente.
- La frontera contractual principal queda delimitada sin forcing de dialecto.
- La cobertura real de la validacion queda declarada sin inflarla.

### Cumplimiento deseable
- El repo deja trazada una ruta directa entre consumers, contrato, tests y enforcement declarativo de CI.
- Los seams legacy quedan visibles para futuras decisiones sin mezclarse con el contrato principal.

### Falsa apariencia de cumplimiento
- Declarar que `Specmatic` cubre la frontera principal cuando no hay dialecto honesto.
- Declarar cobertura completa del runtime solo porque existen tests Bats parciales.
- Mezclar cambios de producto o CI real como si fueran parte obligatoria de esta corrida metodologica.

## Criterio de terminado
- Todos los artefactos metodologicos solicitados existen dentro del repo.
- Cada artefacto deriva legitimamente del anterior y mantiene la frontera correcta.
- La familia `Contract-Driven` queda activada y materializada sin mezclar otras familias.
- No se realizan cambios de implementacion, evaluacion ni review.

## Unknowns

### No bloquean
- orden exacto de toda la salida de Devbox en runtime real;
- grado de uso actual de `.devtools/.git-acprc` por consumidores no localizados.

### Condicionan
- la futura integracion de `.ci/contract-checks.yaml` con CI real;
- una futura limpieza del seam legacy del profile file.

### Bloquean
- ninguno para iniciar `Contract-Driven` en modo hibrido y alcance metodologico.

## Evidencia
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Repo / archivos / modulos: `devbox.json`, `.devbox/gen/scripts/.hooks.sh`, `bin/setup-wizard.sh`, `lib/core/contract.sh`, `lib/wizard/step-04-profile.sh`, `lib/promote/workflows/common.sh`, `tests/contracts/devbox-shell/*`, `devtools.repo.yaml`
- Divergencias / seams / riesgos: `.devtools/.git-acprc`, ausencia de `.gitmodules`, hook con rutas legacy/anidadas
- Otras referencias relevantes: `AGENTS.md`

## Criterio de salida para iniciar Contract-Driven

### Trabajo autorizado
- delimitar la frontera contractual principal;
- decidir adopcion directa o hibrida;
- materializar el arbol contractual del flujo;
- derivar tests contractuales y enforcement declarativo de CI;
- declarar honestamente la cobertura y los limites.

### Trabajo prohibido o fuera de alcance
- modificar el runtime del shell;
- ejecutar CI real;
- tocar producto, wizard o comportamiento de Devbox;
- activar `Context-Driven` o `Agentic QA`.

### Validaciones obligatorias antes de declarar cumplimiento
- consistencia entre `05`, `06`, `specs/contracts/devbox-shell/`, `tests/contracts/devbox-shell/` y `.ci/contract-checks.yaml`;
- coherencia entre frontera declarada, herramienta primaria y alcance real de `Specmatic`.

### Riesgos a vigilar durante trabajo posterior
- falsa cobertura completa;
- degradar la frontera principal a una subfrontera documental mas comoda;
- esconder la condicion legacy del profile file.

### Unknowns que no bloquean avanzar
- detalle exacto de runtime fuera del corte estatico;
- futura limpieza de legacy path.

### Unknowns que si bloquean avanzar
- ninguno identificado en esta corrida.

### Aclaracion minima pendiente, si aplica
- no aplica para iniciar `Contract-Driven` en modo hibrido.

## Preparacion separada para Context-Driven y Agentic QA

### Context-Driven
- reservado;
- no activo en esta fase;
- no modifica la frontera ni los artefactos de `Contract-Driven`.

### Agentic QA
- reservado;
- no activo en esta fase;
- no redefine validacion contractual ni cobertura declarada.

### Limite metodologico actual
- `No activo en esta fase; solo preparacion separada.`

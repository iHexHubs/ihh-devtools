# Spec as Source - `devbox-shell`

## Flow id
`devbox-shell`

## Spec de referencia

### Intencion funcional relevante
- Entrar a una shell local de Devbox gobernada por el repo.
- Exponer una subfrontera no interactiva `devbox shell --print-env` para consumidores internos.

### Contrato visible relevante
- Gate estricto cuando hay marker + TTY + verificacion valida.
- `print-env` util para toolchain de consumidores internos.
- No presentar la sesion como lista/contextualizada si la verificacion estricta falla.

### Invariants relevantes
- root resolution antes de wizard/config;
- resolucion contractual del profile file;
- no degradar la frontera principal CLI/shell a otra superficie artificial.

### Failure modes relevantes
- falta de repo Git;
- falta de herramientas requeridas;
- GH/SSH invalidos;
- fallo al obtener `print-env`.

### Candidatos de aceptacion heredados relevantes
- gate estricto verificable;
- `print-env` consumible para `git-cliff`;
- side effects tolerados visibles y no maquillados.

## Partes del codigo que ya cumplen
- `devbox.json` localiza root, decide variante y controla el gate principal del shell.
- `bin/setup-wizard.sh` ya implementa verify-only con chequeos concretos de GH/SSH.
- `lib/core/contract.sh` ya resuelve `vendor_dir` y `profile_file` desde el contrato del repo.
- `lib/promote/workflows/common.sh` ya consume `devbox shell --print-env` como fallback real para `git-cliff`.
- La corrida segura en copia temporal confirmo que `print-env` devuelve exports reales de toolchain.

## Gaps a cerrar

### Gaps claros
- No existe memoria contractual materializada del flujo.
- No existe decision contractual explicita sobre adopcion directa vs hibrida.
- No existe definicion materializada de consumidores, compatibilidad ni cobertura real.

### Gaps parciales
- La cobertura observable de `print-env` respecto de la sesion interactiva sigue parcial.
- Los side effects tolerados del flujo siguen visibles en codigo, pero no clasificados contractualmente.

### Gaps dependientes de decision abierta
- Si `Specmatic` cubre alguna subfrontera honesta o si su alcance debe declararse nulo.

## Cambios necesarios derivados del spec
- Crear `05-contract-scope.md` y fijar frontera contractual real.
- Clasificar la adopcion como `hibrida` si la frontera principal sigue siendo CLI/shell local.
- Materializar `interface-contract.yaml`, `contract-map.yaml`, `consumer-needs.yaml` y `compatibility-rules.yaml`.
- Materializar `examples/`, `schemas/` y `assertions/` para el flujo.
- Derivar validacion contractual nativa en `tests/contracts/devbox-shell/`.
- Definir enforcement contractual en `.ci/contract-checks.yaml`.
- Cerrar la familia en `06-contract-adoption.md`.

## Cambios opcionales
- Harness interactivo con TTY real para cubrir mas de la ruta estricta.
- Wiring futuro de `.ci/contract-checks.yaml` a un runner CI concreto.
- Formalizacion separada del prompt si mas adelante se vuelve contractual.

## Cambios explicitamente fuera de alcance
- Refactorizar `devbox.json`, `bin/setup-wizard.sh` o `lib/core/*.sh`.
- Cambiar el comportamiento del producto.
- Crear artefactos de Context-Driven o Agentic QA.
- Convertir esta fase en implementation, evaluation o review.

## Superficies principales de intervencion

### Superficies principales
- `specs/flows/devbox-shell/05-contract-scope.md`
- `specs/flows/devbox-shell/06-contract-adoption.md`
- `specs/contracts/devbox-shell/`
- `tests/contracts/devbox-shell/`
- `.ci/contract-checks.yaml`

### Superficies secundarias
- `devbox.json`
- `bin/setup-wizard.sh`
- `lib/core/contract.sh`
- `lib/core/config.sh`
- `lib/promote/workflows/common.sh`

### Zonas de alto riesgo
- Diferencia entre shell interactiva y `print-env`
- Side effects locales/globales tolerados por el runtime actual
- Falsa cobertura si se usa tooling no compatible con la frontera principal

## Seams, compatibilidades y zonas de riesgo
- `devbox.json` conserva una rama de submodulo para `.devtools` que hoy opera como seam.
- `lib/core/config.sh` mezcla contrato actual con rutas legacy de config.
- `print-env` existe y sirve al consumidor real, pero no debe venderse como espejo total de la sesion interactiva.
- El gate estricto depende de GH/SSH reales; esa dependencia debe seguir visible en la familia contractual.

## Validacion obligatoria

### Comportamientos observables a validar
- decision de variante estricta basada en marker + TTY + skip wizard;
- no habilitar ruta lista/contextualizada si la verificacion estricta falla;
- `print-env` devuelve exports de toolchain para consumidores internos;
- `common.sh` sigue dependiendo de `print-env` para fallback de `git-cliff`.

### Divergencias que deben quedar cerradas
- ninguna divergencia fuerte de comportamiento; si se detecta, debe declararse sin reescribir el contrato por inercia.

### Evidencias minimas de cumplimiento
- contrato materializado con adopcion hibrida honesta;
- tests contractuales nativos del shell/CLI;
- cobertura parcial declarada sin exageracion;
- `Specmatic` marcado como `no aplica` o subordinado solo si existe subfrontera honesta.

### Riesgos de validacion insuficiente
- asumir que `print-env` cubre la sesion interactiva completa;
- esconder side effects tolerados;
- forzar un dialecto solo por tooling.

## Candidatos de aceptacion listos para ejecucion metodologica
- `devbox shell` es la frontera principal CLI/shell local del flujo.
- `devbox shell --print-env` es una subfrontera observable consumida por `common.sh`.
- La adopcion contractual debe ser `hibrida` salvo aparicion de una subfrontera honestamente soportada por Specmatic.
- La validacion primaria debe vivir en tests shell/CLI nativos, no en una API ficticia.

## Criterio de cumplimiento

### Cumplimiento minimo
- frontera contractual real delimitada;
- consumidores y compatibilidad materializados;
- validacion primaria shell/CLI definida y trazable;
- cobertura real declarada con honestidad;
- `.ci/contract-checks.yaml` gobernado por el contrato, no por QA generica.

### Cumplimiento deseable
- harness reproducible para la subfrontera `print-env`;
- mayor cobertura de la rama interactiva estricta con TTY controlado.

### Falsa apariencia de cumplimiento
- decir que `Specmatic` cubre el flujo principal;
- decir que `print-env` cubre toda la sesion interactiva;
- listar archivos sin aclarar frontera, consumers ni compatibilidad.

## Criterio de terminado
- alcance recortado para el trabajo contractual;
- gaps y seams identificados;
- validacion obligatoria derivada desde el spec;
- criterio de cumplimiento fijado;
- unknowns clasificados;
- base suficiente para abrir `Contract-Driven` sin renegociar autoridad.

## Unknowns

### No bloquean
- fallback exacto del prompt sin `.starship.toml`

### Condicionan
- cobertura parcial entre `print-env` y la sesion interactiva completa

### Bloquean
- ninguno identificado para iniciar `Contract-Driven`

## Evidencia
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Repo / archivos / modulos: `devbox.json`, `bin/setup-wizard.sh`, `lib/core/git-ops.sh`, `lib/core/contract.sh`, `lib/core/config.sh`, `lib/promote/workflows/common.sh`
- Divergencias / seams / riesgos: rama de submodulo en repo sin `.gitmodules`, side effect global de `init.defaultBranch`, equivalencia parcial de `print-env`
- Otras referencias relevantes: corrida segura de `devbox shell --print-env` en copia temporal

## Criterio de salida para iniciar Contract-Driven

### Trabajo autorizado
- delimitar frontera contractual real;
- fijar adopcion hibrida;
- materializar contrato canonico, consumers, compatibilidad, examples, schemas, assertions;
- derivar validacion contractual shell/CLI y enforcement en CI.

### Trabajo prohibido o fuera de alcance
- modificar `devbox.json`, wizard o consumers del producto;
- abrir Context-Driven o Agentic QA;
- presentar `Specmatic` como cobertura principal del flujo.

### Validaciones obligatorias antes de declarar cumplimiento
- tests shell/CLI nativos para el contrato materializado;
- verificacion de la subfrontera `print-env`;
- comprobacion de que el consumer real `common.sh` sigue trazado al contrato.

### Riesgos a vigilar durante trabajo posterior
- falsa cobertura;
- forcing de dialecto;
- ocultar side effects tolerados;
- ampliar alcance hacia implementation.

### Unknowns que no bloquean avanzar
- prompt/theming final;
- alcance exacto de la rama de submodulo en otros checkouts

### Unknowns que si bloquean avanzar
- ninguno identificado

### Aclaracion minima pendiente, si aplica
- mantener la cobertura de `print-env` declarada como parcial respecto de la sesion interactiva.

## Preparacion separada para Context-Driven y Agentic QA
- No activadas.
- Solo queda visible que cualquier futura activacion debe partir del contrato ya materializado y no redefinir la frontera principal del flujo.

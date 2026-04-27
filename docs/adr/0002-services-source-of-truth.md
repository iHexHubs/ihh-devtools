# ADR 0002: Fuente de verdad de servicios y jerarquía de resolución

## Status

Aceptado — 2026-04-27

## Context

`ihh-devtools` necesita una fuente declarativa única para resolver la
información operativa de cada servicio o componente del ecosistema
(identificador, ruta en el repo, imagen Docker, manifiestos GitOps,
health checks, etc.). Hoy esa información se obtiene de varias formas
inconsistentes, y la consecuencia visible es la deuda técnica de los
**~40 hardcodings literales `pmbok` en `lib/promote/workflows/**`**
(8 archivos), bloqueador de SEC-2B-Phase2.

Hechos relevantes al momento de escribir esta decisión:

- El consumer principal `erd-ecosystem` ya tiene
  `ecosystem/services.yaml` operativo, con shape
  `services: [{ id, kind, path, image, k8s, ... }]`. Es la SSoT
  presente, en uso por workflows productivos.
- El schema v1.1 publicado por este toolset
  (`schema/v1.1/contract.json`) define `components: [{ id, kind, path,
  image, runtime, health_check }]` dentro de `contract.yaml`. Cubre el
  mismo dominio con un shape muy cercano, pero no idéntico.
- `devtools.repo.yaml` declara `registries.deploy: null` en el
  productor y como ejemplo para consumers, sin un default operativo
  documentado.
- Hoy no existe documento que prohíba explícitamente caer en
  fallback silencioso a literales como `pmbok` cuando la SSoT no
  resuelve. Esa ausencia es justamente lo que permitió que las
  ~40 menciones literales se acumularan en `lib/promote/workflows/**`.
- B-3 cerró `T-IHH-20` con una suite contractual sobre las funciones
  casi puras de los workflows. SEC-2B-Phase2 (refactor del literal
  `pmbok`) queda desbloqueado conceptualmente. Pero antes de
  implementar el helper en B-5, se necesita esta decisión registrada
  y vinculante.

Sin esta ADR, B-5 tendría que tomar tres decisiones humanas implícitas
(qué archivo es la SSoT, cuál es la jerarquía de resolución, qué hacer
si la resolución falla). Eso introduce ambigüedad y riesgo de
reintroducir literales en el helper mismo.

## Decision

### 1. Compatibilidad híbrida disciplinada

El toolset acepta dos formas equivalentes para declarar la información
operativa de servicios/componentes del consumer:

- **Forma A (presente operativa):** `<consumer>/ecosystem/services.yaml`
  con shape `services: [{ id, kind, path, image, k8s, ... }]`. Es la
  SSoT operativa hoy. Sigue válida indefinidamente.
- **Forma B (futura v2):** `<consumer>/contract.yaml` siguiendo
  `schema/v1.1/contract.json`, con `components: [{ id, kind, path,
  image, runtime, health_check }]`.

### 2. Equivalencia formal

Forma A y Forma B son **alias estables** una de la otra. En runtime el
toolset las resuelve a la misma representación interna. La diferencia
es solo de envoltura (archivo separado vs sección dentro del contract)
y de naming (`services[]` vs `components[]`).

### 3. Estado de cada forma

- **Forma A es la SSoT operativa presente.** No es transitoria ni
  obsoleta. Consumers que la tengan siguen siendo válidos sin
  migrar.
- **Forma B es la forma futura v2.** Documentada en el schema, sin
  consumer real al momento de esta ADR. La migración Forma A → Forma B
  queda como **deuda v2 explícita**, no se ejecuta en este bloque
  ni en B-5.

### 4. Jerarquía oficial de resolución (orden estricto)

Cuando un workflow del toolset necesita resolver un campo (componente
activo, app de ArgoCD, registro de imagen, etc.) sigue este orden:

1. **Variable de entorno explícita.** Mayor precedencia. Si existe,
   se usa sin consultar nada más. Ejemplos:
   - `PROMOTE_COMPONENT` para el componente activo.
   - `DEVTOOLS_PROMOTE_ARGOCD_APP` para el app de ArgoCD.
   - `DEVTOOLS_LOCAL_REGISTRY` para el registro de imagen local.
2. **Contrato declarativo del consumer.** Si la ENV var no está
   definida, se lee `<consumer>/<registries.deploy>` desde
   `devtools.repo.yaml`. Si `registries.deploy` no está cableado en el
   consumer, el toolset usa el default operativo
   `ecosystem/services.yaml`.
3. **Error claro con instrucciones.** Si ni la ENV var ni el archivo
   declarativo resuelven, el toolset emite un error con formato
   estándar (ver §6) y aborta. **Sin fallback silencioso a `pmbok`,
   `iHexHubs`, `elrincondeldetective` ni a cualquier otro literal.**

### 5. erd-ecosystem es un consumer común

`erd-ecosystem` no recibe tratamiento especial en código del toolset.

- **Cero condicionales** sobre el nombre del repo
  (`if [[ "$repo" == *erd-ecosystem* ]]`).
- **Cero condicionales** sobre el componente literal
  (`if [[ "$component" == "pmbok" ]]`).
- **Cero referencias** a `iHexHubs`, `elrincondeldetective` o
  similares en lógica de control de flujo.

Si en el futuro se necesita comportamiento iHexHubs-específico, se
condiciona al campo declarativo `identity.family == "iHexHubs"` del
contract (ya presente en schema v1.1), no a inferencia del nombre del
directorio.

### 6. Cableado de `devtools.repo.yaml`

`devtools.repo.yaml.registries.deploy` es la ruta configurable que
declara dónde vive la SSoT de servicios para el consumer. El default
operativo es `ecosystem/services.yaml`. El consumer puede sobreescribir
el default editando su propio `devtools.repo.yaml`.

### 7. Formato del error de resolución (literal vinculante)

Cuando ningún paso de la jerarquía resuelve, el helper emite:

```
❌ No se puede resolver <campo> para <componente>.
   Buscamos en este orden:
     1. ENV var <NOMBRE_VAR>
     2. <ruta_resuelta_o_default>
   Para configurar: edita <ruta> o exporta <NOMBRE_VAR>.
```

El mensaje es vinculante para B-5 y futuros helpers que consulten la
SSoT.

## Consequences

### Positivas

- **Habilita SEC-2B-Phase2 (B-5)** sin ambigüedad: el helper
  `lib/core/services.sh` tendrá contrato claro registrado en este ADR.
- **Habilita adopción por consumers no-iHexHubs** sin tocar el
  toolset: cualquier consumer puede publicar su `ecosystem/services.yaml`
  o, si lo prefiere, sobreescribir `registries.deploy` con otra ruta.
- **Cierra la deuda técnica de fallback silencioso** a `pmbok` como
  riesgo arquitectónico documentado. Cualquier introducción futura de
  un literal de ese tipo es una violación de esta ADR.
- **Cierra la ambigüedad** sobre dónde vive la SSoT. La decisión humana
  queda documentada y vinculante.
- **Preserva retrocompatibilidad total** con consumers existentes:
  ningún consumer actual está obligado a migrar de Forma A a Forma B
  para seguir funcionando.

### Negativas

- **Crea deuda v2 explícita:** la migración Forma A → Forma B
  (services.yaml separado → components[] embebido en contract.yaml)
  queda como trabajo futuro cuando se justifique operativamente. No
  hay urgencia.
- **El consumer asume la responsabilidad** de declarar
  `registries.deploy` en su propio `devtools.repo.yaml` si quiere usar
  una ruta distinta del default.

## Reglas duras (vinculantes)

- **Cero literales `pmbok`** en lógica de control de flujo de
  `lib/promote/workflows/**`. Si un workflow necesita comportamiento
  específico para un componente, lo lee del archivo declarativo o de
  ENV var, nunca del literal.
- **Cero condicionales** sobre nombre de repo, URL, directorio o
  family del consumer en el toolset, salvo `identity.family` declarado
  en el contract.
- **Cero fallbacks silenciosos** a literales. La ausencia de
  configuración produce error claro con el formato literal de §7, no
  asunción.
- **Cero modificación del schema v1.1** para acomodar este helper. Los
  campos existentes en `components[]` (id, kind, path, image, runtime,
  health_check) son suficientes para B-5.

## Lo que NO se hace en este ADR

- NO se declara `services.yaml` como obsoleto. Es la SSoT operativa
  presente, sigue válida.
- NO se declara `contract.yaml` con `components[]` como obligatorio en
  v1.1. Es la forma futura, opcional.
- NO se introduce lógica condicional sobre nombres específicos de
  repo, componente o organización en el toolset.
- NO se rompe retrocompatibilidad con consumers existentes.

## Acciones

- [x] Cablear `devtools.repo.yaml.registries.deploy` con default
  `ecosystem/services.yaml` (ESTE BLOQUE B-4).
- [x] Registrar esta ADR (B-4).
- [ ] Implementar `lib/core/services.sh` con la jerarquía oficial
  registrada aquí (B-5, SEC-2B-Phase2).
- [ ] Refactorizar `lib/promote/workflows/**` para retirar literales
  `pmbok` y consumir el helper (B-5).
- [ ] Documentar la migración Forma A → Forma B como deuda v2 cuando
  se planifique (bloque futuro, sin urgencia).

## Implementación

- **B-4 (esta ADR):** decisión registrada + cableado de
  `devtools.repo.yaml.registries.deploy`. Sin código nuevo. Sin
  modificación de schema.
- **B-5 (SEC-2B-Phase2):** `lib/core/services.sh` con la jerarquía
  oficial. Refactor de `lib/promote/workflows/**` retirando los ~40
  literales `pmbok`. Suite BATS adicional si aplica.

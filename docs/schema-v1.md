# Schema v1 del consumidor — `ihh-devtools`

Versión: **1**
Estado: **publicada (Fase 1)**
Fuente de verdad: [`schema/v1/contract.json`](../schema/v1/contract.json) y [`schema/v1/lock.json`](../schema/v1/lock.json).

## 1. Propósito

Cada repositorio que adopta `ihh-devtools` declara un **contract** que describe su identidad, convenciones del repo, esquema de release y cómo consume el toolset. Este documento es la cara humana del schema; los archivos JSON Schema bajo `schema/v1/` son la fuente de verdad.

Resuelve parcialmente la decisión **P-AMBOS-5 corregida**: el toolset es universal y agnóstico de proyecto. Cualquier acoplamiento a una app específica (p. ej. `pmbok`) se hace **vía contract**, no vía hardcoding en `lib/` o `bin/`.

Casos que el contract permite separar:

- Un meta-repo (`erd-ecosystem`) con múltiples apps.
- Un repo de la familia iHexHubs (`ihh-bookkeeping`) con su propio dominio.
- Un consumidor externo (`acme-corp/widget-factory`) con convenciones distintas (`trunk` en vez de `main`, `calver` en vez de `semver`).

## 2. Principios de diseño

1. **Strict por diseño.** `additionalProperties: false` en el top-level y en cada sub-schema. Cualquier campo no declarado falla el validador. Solo `extensions` es escape hatch controlado.
2. **Defaults explícitos.** Sin fallbacks legacy. Si un consumidor no declara un campo, el toolset no lo asume.
3. **Universal, no familiar.** El schema no asume `iHexHubs` ni `pmbok` ni cualquier otra organización. La identidad organizacional se declara en `identity.family` y/o `identity.domain`, sin efecto operativo.
4. **Justificación por funcionalidad.** Cada campo del schema está vinculado a una capacidad concreta del toolset. Sin campos especulativos.
5. **Lock generado, contract escrito a mano.** `contract.yaml` lo edita el operador del repo consumidor. `.devtools.lock` lo escribe el toolset tras vendorizar.

## 3. Estructura del contract

### 3.1 Bloques obligatorios

| Bloque | Tipo | Propósito |
|---|---|---|
| `meta` | object | Versión del schema y nombre del contract. |
| `identity` | object | Quién es responsable; metadata organizacional. |
| `git` | object | Convenciones git del repo (rama, protección, firma). |
| `release` | object | Esquema de versionado y changelog. |
| `vendor` | object | Origen del toolset y modo de consumo. |

### 3.2 Bloques opcionales

| Bloque | Tipo | Propósito |
|---|---|---|
| `components` | array | Servicios, webapps, workers que viven en este repo. |
| `commands` | object | Comandos del toolset que el repo expone (mapeo a runners). |
| `environments` | array | Entornos de despliegue (dev, staging, prod). |
| `languages` | array | Lenguajes principales del repo (`bash`, `python`, etc.). |
| `policy` | object | Punteros a docs de gobierno (ADR, CODEOWNERS, contributing). |
| `extensions` | object | Configuración para módulos del toolset, fuera del core. |

### 3.3 Campos clave por bloque

#### `meta`

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `schema_version` | sí | integer (=1) | Versión del schema v1. |
| `contract_name` | sí | string | Identidad única; regex `^[a-z][a-z0-9-]{1,62}[a-z0-9]$`. |
| `contract_revision` | no | integer ≥1 | Tracking interno, opcional. |

#### `identity`

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `owner` | sí | string | Quién responde si falla. Texto libre. |
| `family` | no | string | Organización o familia. NO operativo. |
| `domain` | no | string | Subclasificación lógica. NO operativo. |
| `contact` | no | string | Email o canal. Solo documentación. |
| `repo_url` | no | string | URL canónica. |

#### `git`

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `default_branch` | sí | string | Ej. `dev`, `main`, `trunk`. |
| `protected_branches` | no | array de string | Ramas que no aceptan push directo. |
| `commit_signing` | no | enum | `required`, `optional`, `none`. |
| `remote_canonical_url` | no | string | URL SSH/HTTPS oficial. |

#### `release`

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `scheme` | sí | enum | `semver`, `calver`, `none`. |
| `prerelease_tags_allowed` | no | boolean | Permite `-rc.N` y similares. |
| `changelog_path` | no | string | Ruta del changelog principal. |

#### `vendor`

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `source` | sí | string | Repo del toolset. Ej. `github.com/iHexHubs/ihh-devtools`. |
| `version` | sí | string | Tag git. Validado en runtime. |
| `scope` | sí | enum | `full` (tag completo) o `manifest` (filtrado). |
| `pinned_paths` | no | array | Rutas relativas al tag. Solo si `scope: manifest`. |
| `vendor_dir` | no | string | Default `.devtools`. |

#### `components` (opcional)

Cada elemento:

| Campo | Req. | Tipo | Notas |
|---|---|---|---|
| `id` | sí | string | Mismo regex que `contract_name`. |
| `kind` | sí | enum | `service`, `webapp`, `worker`, `library`, `static`. |
| `path` | sí | string | Ruta dentro del repo. |
| `image` | no | string | Referencia OCI base. |
| `runtime` | no | string | Lenguaje/runtime principal. |
| `health_check` | no | string | Endpoint de salud (si aplica). |

#### `commands` (opcional)

Mapa de nombre-de-comando → `{runner, target}`. El nombre debe coincidir con el regex `^[a-z][a-z0-9:_-]*$`. `runner` es uno de `task`, `make`, `npm`, `cargo`, `shell`.

#### `environments` (opcional)

Cada elemento: `{name, branch, auto_promote?}`. Útil para mapear entornos a ramas (p. ej. `prod` → `main`).

#### `languages` (opcional)

Lista única de strings. Enum: `bash`, `python`, `node`, `go`, `rust`, `java`, `ruby`, `php`, `other`.

#### `policy` (opcional)

Punteros a docs:

| Campo | Tipo | Notas |
|---|---|---|
| `adr_dir` | string | Ej. `docs/adr`. |
| `ownership_doc` | string | Ej. `CODEOWNERS`. |
| `contributing_doc` | string | Ej. `CONTRIBUTING.md`. |

#### `extensions` (opcional)

Único bloque con `additionalProperties: true`. Es un escape hatch para configuración que el core del toolset NO interpreta. Solo módulos opt-in en `lib/extensions/<name>/` deben consumirlos. El schema NO valida la estructura interna de `extensions`.

## 4. Estructura del lock

El lock (`schema/v1/lock.json`) lo genera el toolset al vendorizar. Lo lee el operador para auditoría. NO se edita a mano.

| Campo | Req. | Notas |
|---|---|---|
| `lock_version` | sí | const `1` |
| `contract_schema_version` | sí | const `1`; identifica qué versión del schema generó el lock. |
| `vendor.source` | sí | Coincide con `vendor.source` del contract en el momento del lock. |
| `vendor.version` | sí | Tag declarado. |
| `vendor.ref` | sí | Referencia git resuelta. |
| `vendor.sha` | sí | SHA-1 hex de 40 caracteres. |
| `vendor.scope` | sí | `full` o `manifest`. |
| `vendor.pinned_paths` | no | Lista materializada (si aplica). |
| `vendor.vendor_dir` | no | Directorio de destino. |
| `generated_at` | sí | ISO-8601. |
| `generator.name` | sí | const `ihh-devtools`. |
| `generator.version` | sí | Versión del toolset. |
| `integrity` | no | Reservado para verificación de integridad futura. |

## 5. Ejemplos

| Archivo | Rol |
|---|---|
| [`erd-ecosystem.yaml`](../schema/v1/examples/erd-ecosystem.yaml) | Contract real del meta-repo (5 servicios, 3 entornos). |
| [`ihexhubs-hypothetical.yaml`](../schema/v1/examples/ihexhubs-hypothetical.yaml) | Repo hipotético de la familia iHexHubs con dominio distinto. |
| [`external-generic.yaml`](../schema/v1/examples/external-generic.yaml) | Org ajena: branch `trunk`, scheme `calver`, scope `manifest`. |
| [`minimal.yaml`](../schema/v1/examples/minimal.yaml) | Contract más pequeño posible. Solo bloques requeridos. |
| [`invalid-missing-required.yaml`](../schema/v1/examples/invalid-missing-required.yaml) | Caso negativo: falta `vendor.version`. Debe fallar el validador. |

## 6. Cómo validar tu contract

Si tu repo usa `devbox shell`, el toolset proveerá pronto `task contract:validate`. Mientras tanto, valida manualmente:

```bash
python3 - <<'PY'
import json, yaml, sys
from jsonschema import Draft202012Validator

with open("./schema/v1/contract.json") as f:  # asume CWD = root del repo
    schema = json.load(f)

with open("ruta/a/tu/contract.yaml") as f:
    data = yaml.safe_load(f)

errors = list(Draft202012Validator(schema).iter_errors(data))
if errors:
    for e in errors:
        print(f"ERROR: {e.message} en {list(e.absolute_path)}")
    sys.exit(1)
print("OK: contract válido contra schema v1.")
PY
```

Mensaje esperado al faltar un campo requerido:

```
ERROR: 'version' is a required property en ['vendor']
```

## 7. Limitaciones conocidas de v1

- **`extensions` no se valida.** Cualquier estructura interna pasa porque `additionalProperties: true`. Es intencional para no acoplar el schema core a módulos opt-in.
- **No se verifica la existencia del tag git** declarado en `vendor.version`. Eso es responsabilidad del runtime (Fase 5), no del schema.
- **`identity.domain` es metadata, no operativo.** El toolset no debe ramificar lógica por `domain`. Si lo hiciera, se rompería P-AMBOS-5.
- **`commands` es declarativo.** El schema valida el shape, no que el target exista realmente en el `Taskfile.yaml`/`Makefile`/etc. del consumidor.
- **`pinned_paths` no se valida cuando `scope: full`.** Si alguien lo declara igual, el schema no lo rechaza (solo es informativo). El runtime puede emitir un warning.
- **No hay validación de unicidad cruzada.** Si `components[*].id` se repite, el schema actual no lo detecta. Sería un refinamiento de v1.x.

## 8. Roadmap

| Fase | Alcance |
|---|---|
| **Fase 1 (esta)** | Publicar `schema/v1/`, ejemplos y este documento. Sin tocar código operativo. |
| Fase 2 | Implementar loader en `lib/core/contract.sh` que lea el contract YAML y exponga sus campos como variables/funciones consumibles desde otros módulos. |
| Fase 3 | Reemplazar las menciones literales a `pmbok` en `lib/promote/workflows/*` por consumo del contract (p. ej. `components[*].path`). |
| Fase 4 | `erd-ecosystem` adopta el contract: añade `contract.yaml` al repo y `lib/promote/workflows/lib/apps.sh` deja de tener defaults hardcodeados. |
| Fase 5 | Resolver el tag fantasma del lock (depende de **P-AMBOS-3** sobre método de vendorización: ¿submódulo, manifest real, o git archive con filtrado?). Implementar `vendorize.sh` real o eliminar el manifest decorativo. |
| Fase 6 | Suite contractual `tests/contracts/` + `.ci/contract-checks.yaml`. Documentación final + adaptadores para consumidores legacy. |

**Recordatorios:**

- **P-AMBOS-3** (método canónico de vendorización) sigue pendiente. Bloquea Fase 5.
- La rampa de migración de los 7 repos hermanos arranca tras Fase 4. Mientras tanto, los consumidores actuales siguen funcionando con el flujo legado.
- Ningún cambio retrocompatible se introduce en v1: cualquier extensión de campos requiere bumpar a v2.

## 9. Schema v1.1 (publicado en Fase 2A)

Schema v1.1 es un **bump menor retrocompatible** que añade el campo
opcional `vendor.tree_sha` al lock. Permite detectar drift local del
contenido vendorizado: si alguien edita archivos bajo `.devtools/`
después de vendorizar, el `tree_sha` calculado al validar diferirá
del registrado.

### Diferencias clave entre v1.0 y v1.1

- `lock_version` y `contract_schema_version` siguen siendo `1`. El
  bump es a nivel de schema family, no de versión declarada.
- `vendor.sha` (existente desde v1.0): SHA1 del **commit** vendorizado.
  Detecta drift de referencia (origen).
- `vendor.tree_sha` (nuevo en v1.1, opcional): SHA1 del **tree** del
  directorio vendorizado. Detecta drift de **contenido** (modificación
  local).

### Política operativa

- Locks producidos por toolset versión < 0.2.0: NO incluyen `tree_sha`.
  Validan contra v1.1 sin problema (campo opcional).
- Locks producidos por toolset versión >= 0.2.0: incluyen `tree_sha`.
- `tree_sha` no se hace obligatorio para preservar retrocompatibilidad.
  Si en el futuro se decide hacerlo obligatorio, eso es bump
  **breaking** y requiere v2.

### Por qué no `integrity.digest`

El campo `integrity.{algorithm, digest}` ya existe en el schema. Se
podría haber reutilizado, pero se decidió crear `tree_sha` separado
porque:

- `integrity` es genérico: puede aplicar a archivos individuales,
  paquetes, manifiestos, etc.
- `tree_sha` es semánticamente específico: SHA1 del objeto tree git.
- Mezclar ambos confunde a lectores y bloquea futuras extensiones de
  `integrity` para otros propósitos.

Ver `docs/adr/0003-vendor-strategy.md` para la decisión completa.

### Archivos relevantes

- `schema/v1.1/contract.json` (copia funcional de v1.0).
- `schema/v1.1/lock.json` (v1.0 + `vendor.tree_sha` opcional).
- `schema/v1.1/examples/minimal-without-tree-sha.yaml` (caso
  retrocompatible).
- `schema/v1.1/examples/full-with-tree-sha.yaml` (caso completo
  recomendado).

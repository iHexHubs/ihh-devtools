# ihh-devtools

Toolset CLI en Bash para estandarizar el ciclo de vida de código en equipos que usan Git.

## Qué problema resuelve

Equipos con múltiples repos necesitan un flujo consistente de commits, promociones entre ramas, versionado semver y changelog. ihh-devtools se vendoriza como submódulo (`.devtools`) dentro de cada repo y expone comandos como git aliases efímeros dentro de `devbox shell`, sin contaminar la configuración global de Git.

## Comandos disponibles

| Comando | Descripción |
|---|---|
| `git acp` | Add + commit + push con gestión de identidades SSH y enforcement de feature branch |
| `git promote` | Promoción entre ramas con gates por SHA, versionado semver, changelog automático y tags |
| `git feature` | Crear/actualizar ramas `feature/*` desde `dev` |
| `git gp` | Generar prompt para IA con el diff actual |
| `git rp` | Reset + force push destructivo del último commit (solo ramas no protegidas) |
| `git sweep` | Limpieza masiva de ramas y tags obsoletos |
| `git devtools-update` | Actualizar la copia vendorizada en repos consumidores |

## Requisitos previos

- [Devbox](https://www.jetify.com/devbox) (gestiona todas las dependencias de abajo)
- Git
- SSH configurado para el host de Git
- Docker (para devbox-app de referencia)

Devbox instala automáticamente: `gh`, `gum`, `jq`, `yq`, `bats`, `git-cliff`, `starship`, `kubectl`, `helm`, `kustomize`, `argocd`, `terraform`, `awscli`.

## Instalación

### En un repo existente (como submódulo)

```bash
git submodule add <url-de-ihh-devtools> .devtools
```

### Uso

```bash
devbox shell        # Activa el entorno: aliases efímeros, wizard, prompt
git acp             # Commit y push
git promote         # Promoción entre ramas
```

Al entrar a `devbox shell` por primera vez, el **setup wizard** guía la configuración de identidades SSH/GPG y perfiles.

## Flujo de promoción

```
feature/* → dev-update → dev → staging → main
```

Cada salto tiene:
- **Gate por SHA**: verifica que el commit esperado es el que se promueve
- **Menú de seguridad**: confirmación interactiva obligatoria
- **Estrategia configurable**: merge, rebase o fast-forward según la rama
- **Versionado automático**: bump semver + tag + changelog (git-cliff)
- **Sync GitOps**: actualización de manifiestos Kustomize y sync con ArgoCD (si aplica)

## Estructura del repo

```
bin/                    Entrypoints de cada comando
lib/
  core/                 Motor compartido: semver, config, logging, git-ops
  promote/
    workflows/          Un workflow por salto de rama (to-dev.sh, to-staging.sh, etc.)
    strategies/         Estrategias de merge
  wizard/               Pasos del setup wizard
  ui/                   Banners, prompts, estilos (gum)
config/                 Archivos de configuración de ejemplo
scripts/                Scripts auxiliares (vendorize.sh)
devbox-app/             App de referencia (React + Django + Postgres + GitOps)
tests/                  Tests contractuales
.ci/                    Configuración de checks CI
```

## Configuración

### devtools.repo.yaml

Contrato del repo. Define paths canónicos y registros:

```yaml
schema_version: 1
paths:
  vendor_dir: .devtools
config:
  profile_file: .git-acprc
```

### .git-acprc

Perfil de identidad por repo. Configurado por el setup wizard. Contiene el nombre, email y clave SSH a usar en commits.

## devbox-app

El directorio `devbox-app/` contiene una aplicación de referencia (React + Django + Postgres) con manifiestos GitOps (Kustomize + ArgoCD) que sirve para validar que todo el tooling funciona end-to-end: desde `git acp` hasta el deploy en un cluster local con Minikube.

## Licencia

Consultar el archivo `LICENSE` en la raíz del repo.

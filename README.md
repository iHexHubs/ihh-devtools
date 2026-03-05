# ihh-devtools

Toolset Bash para flujos de desarrollo, CI local y utilidades Git.

## Contrato del repositorio

Devtools se configura con `devtools.repo.yaml` en la raiz del repositorio:

```yaml
schema_version: 1
registries:
  build: config/apps.yaml
  deploy: config/services.yaml
paths:
  vendor_dir: .devtools
config:
  profile_file: .git-acprc
```

Campos clave:
- `registries.build`: catálogo de apps/componentes para build/sync.
- `registries.deploy`: catálogo de servicios para deploy.
- `paths.vendor_dir`: directorio vendorizado (default `.devtools`).
- `config.profile_file`: archivo de perfiles Git (`.git-acprc` o equivalente).

Compatibilidad:
- Si falta contrato, el core intenta fallbacks legacy (`config/apps.yaml`, `config/services.yaml` y vendor dir legacy).

## Comandos principales

- `bin/devtools apps sync`
- `bin/devtools apps sync --only <app>`
- `DEVTOOLS_DRY_RUN=1 bin/devtools apps sync`
- `task ci`

## Estructura

- `bin/`: entrypoints CLI.
- `lib/`: librerías core y workflows.
- `config/`: catálogos y configuración local del tool.
- `scripts/`: scripts auxiliares de CI/automatización.

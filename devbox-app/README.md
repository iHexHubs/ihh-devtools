# devbox-app

Aplicacion minima React + Django + Postgres para validar builds locales, despliegue en Minikube y flujo GitOps con Argo CD.

## Servicios

- `frontend`: React + Vite servido por Nginx.
- `backend`: Django + DRF.
- `db`: Postgres.

## Docker Compose

```bash
cd devbox-app
cp .env.example .env
docker compose up --build
```

Pruebas rapidas:

```bash
curl http://localhost:8000/health
open http://localhost:8080
```

## GitOps + release tag unico

El overlay de Minikube usa un tag comun para:

- `ghcr.io/ihexhubs/devbox-app-backend`
- `ghcr.io/ihexhubs/devbox-app-frontend`

Actualiza ambos con:

```bash
task app:devbox:gitops:pin-tag TAG=<TAG>
```

Ejemplo:

```bash
task app:devbox:gitops:pin-tag TAG=ihh-devtools-v0.1.0.rc.1-build.1-rev.1
```

## Argo CD

El `Application` esta en:

- `devbox-app/gitops/argocd/application.yaml`

Por defecto usa `targetRevision: local`. Para fijar un tag:

```bash
argocd app set devbox-app --revision <TAG>
argocd app sync devbox-app
```

## Minikube bootstrap

```bash
task cluster:up
task app:devbox:argocd:deploy REV=<TAG>
```

Si el repo no define `cluster:up`, crea/usa el entrypoint oficial del toolset en `Taskfile` o `bin/` y evita scripts ad-hoc en `devbox-app/scripts`.

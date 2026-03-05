## v0.1.1-rc.2

# Notas de lanzamiento — `dev` → `origin/staging`

**Origen:** `dev`
**Destino:** `origin/staging`

Esta entrega es una **actualización grande de la plataforma de promoción (`git promote`) y del vendorizado de `devtools`**, con foco en **determinismo en CI**, **compatibilidad offline/no-interactiva**, **gates por SHA**, y una expansión importante de **flujos `local`/GitOps** (overlays, bootstrap, gateway, túneles y “doctor”).

---

## Lo más importante para el usuario final

* **Promociones más confiables:** `git promote` ahora es más determinístico (CI/offline), con mejores guardrails, menos estados “misteriosos” y una secuencia más segura para push/tag.
* **Gate por SHA reforzado:** se valida de forma más estricta que los workflows requeridos hayan corrido sobre el commit objetivo antes de mover ambientes sensibles.
* **Staging/Prod con política de imágenes más estricta:** se detectan/bloquean imágenes sin registry calificado (y se refuerza el estándar `ghcr.io`).
* **Mejor experiencia local:** se incorpora un flujo local más completo (bootstrap, overlays como `local-basic`, gateway con routing por `Host`, túneles resilientes y comandos de diagnóstico tipo `local:doctor`).

---

## Funciones (novedades)

### Devtools / Promote

* **`git promote local` más robusto y transaccional**, con fases `prepare/publish` y rollback best-effort.
* **Dispatcher de contexto** para ejecutar `promote`/workflows desde el repo raíz correcto, mejorando consistencia en monorepos.
* **Detección de runtime local** (p. ej. `kind`/`minikube`/`docker-desktop`) para decidir estrategias de build/load en función del contexto de `kubectl`.
* **Preflight de ArgoCD y tag remoto** para endurecer la estrategia “segura” antes de operar en flujos sensibles.
* **Comandos de tareas integrados** (p. ej. `promote:local`) que unifican `git promote local` con smokes/validaciones.

### GitOps / Kubernetes / Local

* **Nuevo overlay `local-basic`** (sin observabilidad) y soporte de bootstrap asociado.
* **Gateway local centralizado (Traefik)** para routing por `Host` y smoke más realista con `pmbok.localhost` / `api.pmbok.localhost`.
* **Túneles resilientes** para ArgoCD/PMBOK con tareas `task tunnels:*` y soporte de `systemd --user` + runbook.
* **Políticas de registry (Kyverno)** para auditoría/estandarización de imágenes hacia `ghcr.io` en `staging/main`.

---

## Correcciones (bugfixes)

### Promote / Gate / Tags

* Limpieza de **worktrees temporales y stale**, reduciendo colisiones y estados residuales.
* Robustez en resolución **`local/tag`** y mitigación de conflictos con tags remotos.
* **Modo CI/offline:** degradación a `offline_noop` cuando `git fetch` falla, evitando fallos duros por red.
* **Dry-run sin efectos secundarios:** ya no requiere event file, evita publicar remoto y omite sync ArgoCD.
* **Secuencia más segura de release:** crea/pushea tags **solo después** de un push exitoso de la rama.
* **Gates por SHA end-to-end:** se ejecutan como guardia obligatoria y se revalidan faltantes tras watch.
* **Reglas de `targetRevision` para ArgoCD:** se refuerza el contrato `-rev.N` (permitiendo compatibilidad con tags con `+` cuando aplica).

### Devtools / CI UX

* Respeto estricto de `CI`/`NONINTERACTIVE` para evitar prompts sin TTY.
* Mejoras para ejecución local de `act`: fallback por restricciones de red/sockets y mejoras de diagnóstico.
* Correcciones menores de UX/logs para abortos y reporte de limpieza de ramas (local/remoto).

### Apps

* **Frontend:** corrección de typo en título de login en `apps/pmbok/frontend/src/components/LoginPage.tsx`.

---

## Mantenimiento (chore/refactor/docs/tests)

### Refactors internos

* Modularización de `to-local` (helpers extraídos: git/k8s/argocd/build/env/utils/ci-gate) para reducir acoplamiento y facilitar evolución.
* Centralización de checks (p. ej. helpers de “repo limpio” / gates / watchers) para evitar duplicación.

### Calidad y pruebas

* Expansión fuerte de suites: `promote.bats`, pruebas de semver/version-strategy, smoke tests y runners reproducibles.
* Nuevos checks automatizados para drift entre tareas y documentación (`local:doctor:*`), y para evitar `ports:` en Compose apps.

### Documentación

* Runbooks y guías prácticas: cierre de tarea (gate/promote), bootstrap local, routing local, ImagePullBackOff, variables clave, contrato de tags.

### Higiene del repo

* `chore(gitignore)`: se ignora `<vendor_dir>/run/tunnels.pids`.
* Actualizaciones de vendorizado/pins de `.devtools` y normalización de toolchain (incluyendo cambios relacionados con ArgoCD y utilidades CI).

---

## Cambios de comportamiento a tener en cuenta

* **Staging/Prod más estrictos con imágenes:** se valida/bloquea “imagen sin registry” en overlays (p. ej. `devops/k8s/overlays/staging/kustomization.yaml`), lo que puede frenar promociones si hay `newName:` sin dominio/registry.
* **Semver/build:** se refuerza el formateo de tags y estrategias de `-rev.N`/build; si tienes automatizaciones que asumían `+build`, revisa compatibilidad (hay señales de soporte legacy, pero conviene validar pipelines).
* **Gates por SHA obligatorios:** si falta el workflow requerido (ej. monorepo `ci.yaml`), la promoción puede abortar por seguridad.

---

## Verificación recomendada en `origin/staging`

* Ejecutar `git promote staging` y confirmar que el **gate por SHA** se resuelve correctamente (workflows requeridos presentes).
* Validar que el overlay `staging` renderiza y que **todas las imágenes están calificadas** (ej. `ghcr.io/...`).
* Smoke básico de PMBOK (frontend + API) y verificación de sync/health en ArgoCD.
* En CI: validar ruta “offline/noop” y que no haya prompts en ejecución no interactiva.


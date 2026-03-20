# Spec as Source — `devbox-shell`

## Flow id
`devbox-shell`

## Spec de referencia

### Intención funcional relevante
- La autoridad funcional de esta fase sigue siendo `02-spec-first.md`.
- `devbox shell` debe abrir una shell Devbox repo-local asociada a este repositorio.
- El flujo debe exponer el entorno base del repo e intentar contextualización local de devtools.
- La ruta "sesión lista/contextualizada" es condicionada; no es una obligación universal de toda invocación.

### Contrato visible relevante
- El usuario obtiene una shell Devbox del repo o una salida equivalente a la modalidad invocada.
- El flujo puede degradarse legítimamente a verificación limitada o a salida no interactiva.
- La ruta full puede producir bootstrap persistente local cuando aplica.
- El contrato visible no fija como obligación el menú de rol, el prompt exacto, los textos exactos de consola ni la ubicación legacy de artefactos internos.

### Invariants relevantes
- La shell base de Devbox y el entorno base del repo son núcleo contractual.
- La contextualización ampliada depende de TTY, estado local, herramientas y verificación.
- `03-spec-anchored.md` sigue siendo la realidad anclada gobernante sobre cómo ese contrato se mapea hoy al código.
- El legado `.devtools` puede existir como compatibilidad, pero no debe redefinir silenciosamente el contrato aprobado.

### Failure modes relevantes
- Si faltan `devbox` o `git`, el flujo no satisface sus preconditions.
- Si faltan herramientas, credenciales o verificación SSH/GitHub, la sesión puede no quedar lista/contextualizada.
- Si no hay TTY, el flujo puede degradarse a `--verify-only`.
- Si falla la verificación requerida, el flujo puede conservar shell base sin afirmar readiness completa.

### Candidatos de aceptación heredados relevantes
- `devbox shell` entra por el repo y usa `devbox.json` como base del entorno.
- El entorno base del repo queda disponible en la shell o en la salida equivalente.
- El flujo distingue entre una ruta limitada de verificación y una ruta más completa de contextualización/bootstrap.
- La condición de "sesión lista/contextualizada" depende de verificación y contexto; no es resultado universal.
- Una corrida como `--print-env` no prueba por sí sola la experiencia interactiva completa.

## Partes del código que ya cumplen
- `devbox.json` ya sostiene el entrypoint repo-específico del flujo mediante `shell.init_hook`.
- El bloque `env` de `devbox.json` ya expone el entorno base del repo, incluido `DEVBOX_ENV_NAME=IHH`.
- El hook ya separa shell base y contextualización adicional mediante `DEVBOX_SESSION_READY`.
- `bin/setup-wizard.sh` ya distingue la ruta `--verify-only` de la ruta full y valida preconditions operativas.
- Los side effects persistentes del bootstrap full ya están concentrados en el wizard y sus steps, no en el contrato visible.
- La shell base repo-local y la degradación legítima por no TTY ya están sostenidas por la realidad anclada y no deben tocarse por esta fase.

## Gaps a cerrar

### Gaps claros
- El flujo no sostiene todavía una única autoridad operativa coherente entre contrato resuelto, marker de readiness y persistencia del perfil.
- El hook sigue gatillando ramas críticas con `.devtools/.setup_completed`, mientras el contrato resuelto por el wizard apunta a `config.profile_file: .git-acprc`.
- La persistencia observada del perfil sigue en `.devtools/.git-acprc`, lo que deja abierta una divergencia visible con el contrato repo.

### Gaps parciales
- La señal que habilita afirmar "sesión lista/contextualizada" está repartida entre hook, marker legacy y verificación del wizard.
- La modalidad `--print-env` prueba entorno base, pero no delimita por sí sola el alcance de la contextualización efímera.

### Gaps dependientes de decisión abierta
- Definir cómo se preserva compatibilidad legacy sin permitir que `.devtools` siga gobernando implícitamente readiness y persistencia.

## Cambios necesarios derivados del spec
- Alinear la fuente operativa de readiness con la autoridad aprobada del flujo, evitando que el marker legacy siga gobernando por inercia la ruta lista/contextualizada.
- Alinear la persistencia efectiva del perfil con la resolución contractual del repo o, si debe mantenerse compatibilidad legacy, dejarla explícitamente subordinada al contrato y no al revés.
- Mantener intacto el núcleo contractual: shell base repo-local, entorno base del repo y contextualización condicionada.
- Asegurar que la rama estricta de verificación solo afirme readiness cuando la verificación requerida realmente pasa.
- Mantener separadas la ruta limitada de verificación y la ruta full de bootstrap persistente, sin colapsarlas en una sola noción vaga de "funciona".

## Cambios opcionales
- Confirmar con una sesión PTY los textos exactos del menú de rol, prompt y mensajes finales.
- Simplificar la búsqueda múltiple de scripts auxiliares si eso no cambia el comportamiento requerido por el spec.
- Revisar el aviso remoto de versión o la cantidad exacta de aliases efímeros, siempre como trabajo no requerido para cumplimiento v1.

## Cambios explícitamente fuera de alcance
- Refactor amplio del wizard o de toda la topología `.devtools`.
- Rediseño de UX, branding, prompt, selector de rol o textos de consola.
- Limpieza general de scripts `git-*` o de rutas candidatas no directamente implicadas en el gap central.
- Cambios en `devbox-app/`, `Taskfile.yaml`, apps de producto o flujos vecinos.
- Trabajo de implementation, evaluation, review o tests finales como salida principal de esta fase.

## Superficies principales de intervención

### Superficies principales
- `devbox.json`: entrypoint real, gating por marker/TTY, activación de wizard y decisión de readiness.
- `bin/setup-wizard.sh`: resolución contractual del repo, parseo central del wizard y bifurcación `verify-only/full`.

### Superficies secundarias
- `lib/core/contract.sh`: resolución de `vendor_dir` y `profile_file`.
- `lib/wizard/step-04-profile.sh`: persistencia efectiva de perfil y marker.

### Zonas de alto riesgo
- El punto donde el hook sigue leyendo `.devtools/.setup_completed` mientras la resolución contractual del perfil ya puede salir de `devtools.repo.yaml`.
- La coexistencia entre `.git-acprc` contractual y `.devtools/.git-acprc` observado.
- Cualquier cambio que rebaje el contrato a "abre shell base" sin gobernar la condición real de readiness.

## Seams, compatibilidades y zonas de riesgo
- La búsqueda de scripts en múltiples candidatos es un seam activo de compatibilidad y no debe promoverse a contrato.
- La rama de `git submodule sync/update` es compatibilidad tolerada, no núcleo contractual del flujo.
- `.devtools/.setup_completed` y `.devtools/.git-acprc` son artefactos legacy visibles; pueden requerir compatibilidad, pero no deben seguir gobernando silenciosamente el flujo.
- El selector de rol, `gum`, `starship` y el aviso remoto de versión son capas de experiencia secundaria; su presencia no equivale a cumplimiento contractual.
- La dispersión entre hook, contrato y step final del wizard concentra el principal riesgo técnico y metodológico.

## Validación obligatoria

### Comportamientos observables a validar
- `devbox shell` sigue produciendo shell o salida repo-local válida asociada al `devbox.json` del repo.
- El entorno base del repo sigue estando disponible en la shell o en la salida equivalente.
- La ruta limitada de verificación sigue diferenciándose de la ruta full de bootstrap.
- La ruta "sesión lista/contextualizada" solo se afirma cuando la verificación requerida pasa bajo la autoridad operativa alineada.

### Divergencias que deben quedar cerradas
- La divergencia entre contrato resuelto para `profile_file` y persistencia efectiva observada.
- La divergencia entre gating de readiness en el hook y la fuente contractual efectiva del estado listo.

### Evidencias mínimas de cumplimiento
- Evidencia de que la shell base y el entorno base permanecen intactos.
- Evidencia de que la verificación requerida gobierna readiness y no solo la presencia de artefactos legacy.
- Evidencia de que una corrida limitada como `--print-env` no se usa como prueba suficiente de contextualización completa.

### Riesgos de validación insuficiente
- Dar por cumplido el flujo porque abre la shell base.
- Dar por cumplido el flujo porque `DEVBOX_ENV_NAME` aparece en `--print-env`.
- Dar por cerrada la divergencia solo porque los archivos legacy siguen existiendo.
- Aceptar textos visibles, prompt o aliases como sustituto de la verificación requerida.

## Candidatos de aceptación listos para ejecución
- El flujo debe conservar shell Devbox repo-local y entorno base del repo después del trabajo posterior.
- El flujo debe conservar la degradación legítima a verificación limitada cuando no hay TTY o cuando la modalidad lo requiere.
- La afirmación de readiness debe depender de verificación real y de una fuente operativa coherente con el contrato aprobado.
- La compatibilidad legacy puede existir, pero no puede seguir siendo la fuente normativa de readiness ni de persistencia.
- `--print-env` puede seguir siendo modalidad válida de inspección parcial, pero no debe declararse evidencia suficiente de contextualización completa.

## Criterio de cumplimiento

### Cumplimiento mínimo
- `devbox shell` sigue abriendo shell base repo-local con entorno base del repo.
- El flujo sigue intentando contextualización local de devtools sin prometerla universalmente.
- La condición de "sesión lista/contextualizada" queda gobernada por verificación requerida y por una autoridad operativa coherente con el contrato.
- La divergencia central entre contrato, readiness y persistencia deja de depender implícitamente del legado `.devtools`.

### Cumplimiento deseable
- La compatibilidad legacy, si persiste, queda explícitamente encapsulada y no ambigua.
- La diferencia entre shell base, verificación limitada y ruta full queda más fácil de leer desde el código y desde la validación.

### Falsa apariencia de cumplimiento
- La shell abre, pero readiness sigue dependiendo de un marker legacy no alineado con el contrato.
- `--print-env` muestra variables base y se usa indebidamente como prueba de contextualización completa.
- Existen aliases o prompt contextualizado, pero la divergencia contractual de readiness/persistencia sigue abierta.
- Los artefactos legacy siguen presentes y eso se interpreta erróneamente como alineación contractual.

## Criterio de terminado
- El alcance queda recortado al gap central entre contrato, readiness y persistencia, sin arrastrar limpiezas vecinas.
- Queda explícito qué ya cumple y no debe tocarse.
- Quedan explícitos los gaps que sí deben cerrarse y las superficies reales donde vive ese trabajo.
- La validación obligatoria ya deriva del spec aprobado y de la realidad anclada, no de conveniencia técnica.
- El criterio de cumplimiento ya distingue cumplimiento mínimo, deseable y falsa apariencia.
- Los unknowns quedan clasificados y ninguno bloquea por sí solo el paso a trabajo posterior.

## Unknowns

### No bloquean
- Confirmación PTY exacta del menú de rol, prompt y textos finales.
- Detalle exhaustivo de exit codes y del aviso remoto de versión.

### Condicionan
- Alcance exacto del `init_hook` bajo `devbox shell --print-env`.
- Decisión concreta de compatibilidad si se mantiene coexistencia temporal con artefactos legacy.

### Bloquean
- Ninguno identificado con base suficiente en esta fase.

## Evidencia
- Spec-first: `specs/flows/devbox-shell/02-spec-first.md`
- Spec-anchored: `specs/flows/devbox-shell/03-spec-anchored.md`
- Discovery: `specs/flows/devbox-shell/01-discovery.md`
- Repo / archivos / módulos: `devbox.json`, `bin/setup-wizard.sh`, `lib/core/contract.sh`, `lib/wizard/step-04-profile.sh`, `devtools.repo.yaml`
- Divergencias / seams / riesgos: `.devtools/.setup_completed`, `.devtools/.git-acprc`, búsqueda de scripts por múltiples candidatos, rama tolerada de submodule update
- Otras referencias relevantes: observaciones controladas previas con `devbox shell --help` y `devbox shell --print-env`

## Criterio de salida para ejecutar o delegar implementación

### Trabajo autorizado
- Trabajo focalizado en alinear la autoridad operativa de readiness y persistencia con el contrato funcional aprobado y la realidad anclada.
- Trabajo focalizado en preservar shell base, entorno base y contextualización condicionada.
- Trabajo focalizado en cerrar la divergencia central sin convertir compatibilidad legacy en contrato.

### Trabajo prohibido o fuera de alcance
- Refactor amplio, limpieza general, rediseño UX o endurecimiento colateral.
- Trabajo sobre flujos vecinos, apps de producto o artefactos fuera del flujo `devbox shell`.
- Validation final, evaluation o review como sustituto de implementation posterior.

### Validaciones obligatorias antes de declarar cumplimiento
- Validar shell base repo-local y entorno base del repo.
- Validar la separación entre ruta limitada y ruta full.
- Validar que readiness depende de verificación real y no solo de archivos legacy.
- Validar que la divergencia contractual de perfil/marker queda efectivamente cerrada.

### Riesgos a vigilar durante trabajo posterior
- Rebajar el contrato a "abre la shell" y omitir el gap de readiness.
- Ampliar el trabajo a una limpieza general del wizard o del legado `.devtools`.
- Declarar cumplimiento con evidencia parcial o cómoda.

### Unknowns que no bloquean avanzar
- PTY exacta de menú, prompt y branding.
- Detalle exhaustivo de mensajes y exit codes secundarios.

### Unknowns que sí bloquean avanzar
- Ninguno identificado.

### Aclaración mínima pendiente, si aplica
- Si se decide preservar compatibilidad temporal con rutas legacy, esa compatibilidad debe quedar explícitamente subordinada al contrato y a la validación obligatoria, no tratada como fuente normativa.

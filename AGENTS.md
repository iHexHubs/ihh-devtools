# Repo Agent Guidance

- This repo is a shell-heavy devtools workspace. Treat `devbox.json`, `bin/`, `lib/`, `Taskfile.yaml`, and generated `.devbox/` artifacts as the primary evidence surfaces for flow reconstruction.
- Keep project memory inside the repo under `specs/flows/<flow-id>/`, `specs/contracts/<flow-id>/`, `tests/contracts/<flow-id>/`, and `.ci/`.
- During methodological runs, do not mix SDD stages. Close `01` -> `02` -> `03` -> `04` before activating `Contract-Driven`.
- Prefer static inspection for discovery. Commands like `devbox shell --print-env`, `bin/setup-wizard.sh`, and git/ssh/gh validation paths are side-effectful and must be treated as execution surfaces, not harmless reads.
- When the active flow is shell or CLI oriented, preserve the real boundary. Do not force HTTP-style contracts or present partial tooling coverage as full contractual coverage.
- Keep contract checks focused on boundary behavior. Do not mix general product tests into `tests/contracts/<flow-id>/`.


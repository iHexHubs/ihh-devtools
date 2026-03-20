# IHH Devtools Repo Guidance

- Keep flow memory inside `specs/flows/<flow-id>/`.
- Keep stages separate: `01-discovery.md`, `02-spec-first.md`, `03-spec-anchored.md`, `04-spec-as-source.md`.
- For `devbox shell`, start evidence gathering from `devbox.json`, then expand only to the files the traced path actually reaches in `bin/`, `lib/`, `scripts/`, `Taskfile.yaml`, `README.md`, `.devbox/`, or repo config.
- Treat `devbox-app/` as out of scope for the `devbox shell` flow unless the traced execution path clearly enters it.
- During discovery, spec-first, spec-anchored, and spec-as-source do not edit product code, do not refactor, and do not add product tests.
- Prefer read-only inspection. If runtime confirmation is needed, keep it non-destructive and scoped to commands such as `devbox shell --help` or `devbox shell --print-env`.
- Keep seams, compatibilities, legacy paths, risks, and unknowns explicit. Do not promote current implementation quirks to contract by inertia.

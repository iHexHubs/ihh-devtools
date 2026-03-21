# devbox-shell contract checks

- Primary validation tool: `Bats`
- Canonical contract manifest: `specs/contracts/devbox-shell/interface-contract.yaml`
- Contract map: `specs/contracts/devbox-shell/contract-map.yaml`

Checks mapped in this directory:
- `devbox-shell-contract.bats`
  - `help exposes the supported shell flags` -> `examples/help-flags.yaml`
  - `print-env exposes the base repo environment` -> `examples/print-env-base.yaml`
  - `contract resolver keeps vendor_dir and profile_file aligned with the repo contract` -> `assertions/profile-resolution.yaml`
  - `setup wizard wiring keeps the contract-resolved profile file` -> `assertions/profile-resolution.yaml`
  - `init_hook keeps readiness gated by verification` -> `assertions/readiness-gate.yaml`
- `run-contract-checks.sh`
  - imports the repo environment with `devbox shell --print-env`
  - runs the Bats contract suite for this flow

Coverage notes:
- Complete for the contract checks materialized above.
- Partial for the interactive role/prompt branch and the full internal Devbox runtime.
- `Specmatic` does not apply to this main boundary.


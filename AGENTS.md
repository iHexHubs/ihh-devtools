# AGENTS.md

## Mission

Understand real Bash flows before changing code.
Specs are living documents.
Do not invent behavior that has not been observed in code, commands, or tests.

## Current active adoption

Only one flow is being actively promoted right now:

- `bootstrap.devbox-shell`

Its maturity path is:

1. `discovery`
2. `spec-first`
3. `spec-anchored`
4. `spec-as-source`

Do not start promoting `devtools.apps-sync`, `git-promote.to-local`, or `git-acp.post-push`
unless explicitly requested.

## Global operating rules

1. Work one flow at a time.
2. Do not implement code unless explicitly asked.
3. Every important claim must be backed by evidence:
   - file path
   - function name
   - command
   - observed behavior
4. Separate:
   - core path
   - support path
   - noise
   - suspected legacy
5. Keep `README.md` short.
   Detailed flow knowledge belongs in `specs/flows/*.md`.
6. Use `specs/templates/*.md` and `specs/flows/_template.md` as the documentation baseline.
7. When a flow becomes stable enough, create or update Bats tests in `tests/`.
8. Legacy is a hypothesis until there is evidence.
9. Do not mark a flow as `spec-as-source` unless:
   - the contract is explicit
   - current code is mapped to the contract
   - drift is identified
   - validation with Bats exists or is explicitly queued

## Required output when analyzing a flow

Every flow analysis should produce, at minimum:

- entry point
- dispatcher chain
- happy path
- important branches
- side effects
- inputs
- outputs
- preconditions
- invariants
- error modes
- files/functions involved
- assumptions
- unknowns
- suspected legacy
- next promotion step

## Promotion gates

### discovery -> spec-first
Required:
- observed entry point and path
- identified inputs/outputs
- identified side effects
- main unknowns listed
- evidence linked to code or commands

### spec-first -> spec-anchored
Required:
- intended contract written clearly
- examples of expected behavior
- invariants and failure modes
- mapping from spec to current code

### spec-anchored -> spec-as-source
Required:
- authoritative contract
- explicit drift notes
- acceptance criteria
- Bats validation present or required by policy

## Editing policy for specs

- Prefer updating the relevant flow file under `specs/flows/`
- Update `specs/constitution.md` only when a repo-wide rule changes
- Do not overload `README.md` with operational detail

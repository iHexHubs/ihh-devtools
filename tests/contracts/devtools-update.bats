#!/usr/bin/env bats
# Migrado desde erd-ecosystem/.devtools/tests/devtools-update.bats
# Iteración: T-AMBOS-5 (2026-04-28)

# tests/devtools-update.bats
#
# Objetivo: asegurar el "contrato" del CLI de bin/git-devtools-update.sh:
# - soporta TAG=..., list, --yes, --repo
# - no depende de red (usamos repo local)
#
# Nota: estos tests NO intentan tocar /webapps/erd-ecosystem; hacen un sandbox git aislado.

setup() {
  set -euo pipefail

  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/bin/git-devtools-update.sh"
  WRAPPER="$REPO_ROOT/bin/git-devtools-update"

  TMP="$(mktemp -d)"
  export TMP

  # repo "upstream" local con tags
  UPSTREAM="$TMP/upstream"
  git init -q "$UPSTREAM"
  git -C "$UPSTREAM" config user.name "Test Bot"
  git -C "$UPSTREAM" config user.email "test@example.com"
  git -C "$UPSTREAM" config commit.gpgsign false
  git -C "$UPSTREAM" config tag.gpgsign false
  git -C "$UPSTREAM" remote add origin "git@github.com:acme/erd-devtools.git"
  printf "hello\n" > "$UPSTREAM/README.md"
  mkdir -p "$UPSTREAM/.devtools/bin"
  printf "#!/usr/bin/env bash\necho devtools\n" > "$UPSTREAM/.devtools/bin/example.sh"
  chmod +x "$UPSTREAM/.devtools/bin/example.sh"
  git -C "$UPSTREAM" add README.md
  git -C "$UPSTREAM" add .devtools/bin/example.sh
  git -C "$UPSTREAM" commit -q -m "init"
  git -C "$UPSTREAM" tag -a -m "tag v0.0.1" v0.0.1
  printf "v0.0.2\n" >> "$UPSTREAM/README.md"
  git -C "$UPSTREAM" add README.md
  git -C "$UPSTREAM" commit -q -m "update for v0.0.2"
  git -C "$UPSTREAM" tag -a -m "tag v0.0.2" v0.0.2

  # repo "consumer" con .devtools (submódulo simulado o vendorizado simulado)
  CONSUMER="$TMP/consumer"
  git init -q "$CONSUMER"
  git -C "$CONSUMER" config user.name "Test Bot"
  git -C "$CONSUMER" config user.email "test@example.com"
  git -C "$CONSUMER" config commit.gpgsign false
  git -C "$CONSUMER" config tag.gpgsign false
  printf "consumer\n" > "$CONSUMER/README.md"
  git -C "$CONSUMER" add README.md
  git -C "$CONSUMER" commit -q -m "init"

  mkdir -p "$CONSUMER/.devtools"

  # Adaptación T-AMBOS-5: el canónico bin/git-devtools-update.sh exige
  # devtools.repo.yaml con paths.vendor_dir cuando se ejecuta desde un
  # consumer (no desde el repo upstream). El legado no tenía este check;
  # añadir el contrato al fixture es adaptación válida (no debilita asserts).
  cat > "$CONSUMER/devtools.repo.yaml" <<'YAML'
schema_version: 1
paths:
  vendor_dir: .devtools
YAML
}

teardown() {
  rm -rf "${TMP:-}" || true
}

@test "devtools-update script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
  [ -f "$WRAPPER" ]
  [ -x "$WRAPPER" ]
}

@test "devtools-update wrapper delegates to .sh entrypoint" {
  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$WRAPPER' --help
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
  [[ "$output" == *"git devtools-update"* ]]
}

@test "devtools-update: list resolves source from --repo and consults remote tags" {
  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v0.0.1"
  echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/v0.0.2"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    PATH='$TMP/fakebin':\"\$PATH\" '$SCRIPT' list --repo '$UPSTREAM'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/erd-devtools.git"* ]]
  [[ "$output" == *"v0.0.1"* ]]
  [[ "$output" == *"v0.0.2"* ]]
}

@test "devtools-update: list accepts --repo subdirectory and still queries remote source" {
  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v0.0.1"
  echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/v0.0.2"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    PATH='$TMP/fakebin':\"\$PATH\" '$SCRIPT' list --repo '$UPSTREAM/.devtools'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/erd-devtools.git"* ]]
  [[ "$output" == *"v0.0.1"* ]]
  [[ "$output" == *"v0.0.2"* ]]
}

@test "devtools-update: legacy lock DEVTOOLS_REPO/DEVTOOLS_TAG works in vendored mode (not submodule)" {
  mkdir -p "$CONSUMER/.devtools"
  printf "legacy lock\n" > "$CONSUMER/.devtools/OLD.txt"
  # .gitmodules presente pero sin gitlink real: debe seguir en modo vendorizado.
  cat > "$CONSUMER/.gitmodules" <<'GITMODULES'
; test fixture
GITMODULES
  cat > "$CONSUMER/.devtools.lock" <<LOCK
# lock legacy
DEVTOOLS_TAG="v0.0.1"
DEVTOOLS_SHA="$(git -C "$UPSTREAM" rev-parse v0.0.1^{commit})"
DEVTOOLS_REPO="$UPSTREAM"
LOCK

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' TAG=v0.0.2 --yes
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODE DETECTED: vendor"* ]]
  [ -f "$CONSUMER/.devtools/bin/example.sh" ]
  run bash -lc "grep -n 'DEVTOOLS_VERSION=\"v0.0.2\"' '$CONSUMER/.devtools.lock'"
  [ "$status" -eq 0 ]
  run bash -lc "grep -n 'DEVTOOLS_TAG=\"v0.0.2\"' '$CONSUMER/.devtools.lock'"
  [ "$status" -eq 0 ]
  run bash -lc "grep -n 'DEVTOOLS_REPO=\"$UPSTREAM\"' '$CONSUMER/.devtools.lock'"
  [ "$status" -eq 0 ]
}

@test "devtools-update: list in vendored repo uses DEVTOOLS_SOURCE from lock via ls-remote" {
  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v0.9.0"
  echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/v0.9.1"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  mkdir -p "$CONSUMER/.devtools"
  printf "v0.0.1\n" > "$CONSUMER/.devtools/VENDORED_TAG"
  cat > "$CONSUMER/.devtools.lock" <<'LOCK'
DEVTOOLS_SOURCE="acme/erd-devtools"
DEVTOOLS_VERSION="v0.0.1"
DEVTOOLS_SUBDIR=".devtools"
LOCK

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    PATH='$TMP/fakebin':\"\$PATH\" '$SCRIPT' list
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/erd-devtools.git"* ]]
  [[ "$output" == *"v0.9.0"* ]]
  [[ "$output" == *"v0.9.1"* ]]
}

@test "devtools-update: ignores invalid DEVTOOLS_REPO in lock and falls back to remote source" {
  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v1.2.3"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  mkdir -p "$CONSUMER/.devtools"
  printf "v0.0.1\n" > "$CONSUMER/.devtools/VENDORED_TAG"
  cat > "$CONSUMER/.devtools.lock" <<'LOCK'
DEVTOOLS_SOURCE="acme/erd-devtools"
DEVTOOLS_VERSION="v0.0.1"
DEVTOOLS_SUBDIR=".devtools"
DEVTOOLS_REPO="/path/that/does/not/exist"
LOCK

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    PATH='$TMP/fakebin':\"\$PATH\" '$SCRIPT' list
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/erd-devtools.git"* ]]
  [[ "$output" == *"v1.2.3"* ]]
}

@test "devtools-update: list in vendored repo fails when source is unknown" {
  mkdir -p "$CONSUMER/.devtools"
  printf "v0.0.1\n" > "$CONSUMER/.devtools/VENDORED_TAG"
  cat > "$CONSUMER/.devtools.lock" <<'LOCK'
DEVTOOLS_SOURCE="local/erd-devtools"
DEVTOOLS_VERSION="v0.0.1"
DEVTOOLS_SUBDIR=".devtools"
LOCK

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' list
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Origen remoto desconocido."* ]]
  [[ "$output" == *"--source <owner>/<repo>"* ]]
}

@test "devtools-update: in upstream repo mode, list still consults remote source" {
  toolrepo="$TMP/toolrepo"
  mkdir -p "$toolrepo/bin" "$toolrepo/lib/core" "$toolrepo/.devtools"
  cp "$SCRIPT" "$toolrepo/bin/git-devtools-update.sh"
  cp "$REPO_ROOT/lib/core/utils.sh" "$toolrepo/lib/core/utils.sh"
  cp "$REPO_ROOT/lib/core/git-ops.sh" "$toolrepo/lib/core/git-ops.sh"
  chmod +x "$toolrepo/bin/git-devtools-update.sh"
  printf "vX\n" > "$toolrepo/.devtools/VENDORED_TAG"

  git init -q "$toolrepo"
  git -C "$toolrepo" config user.name "Test Bot"
  git -C "$toolrepo" config user.email "test@example.com"
  git -C "$toolrepo" config commit.gpgsign false
  git -C "$toolrepo" config tag.gpgsign false
  git -C "$toolrepo" remote add origin "git@github.com:acme/toolrepo.git"
  printf "toolrepo\n" > "$toolrepo/README.md"
  git -C "$toolrepo" add .
  git -C "$toolrepo" commit -q -m "init toolrepo"
  git -C "$toolrepo" tag -a -m "tag v0.2.0" v0.2.0
  printf "next\n" >> "$toolrepo/README.md"
  git -C "$toolrepo" add README.md
  git -C "$toolrepo" commit -q -m "next tag"
  git -C "$toolrepo" tag -a -m "tag v0.2.1" v0.2.1

  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v0.2.0"
  echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/v0.2.1"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  run bash -lc "
    set -euo pipefail
    cd '$toolrepo'
    PATH='$TMP/fakebin':\"\$PATH\" ./bin/git-devtools-update.sh list
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/toolrepo.git"* ]]
  [[ "$output" == *"v0.2.0"* ]]
  [[ "$output" == *"v0.2.1"* ]]
}

@test "devtools-update: list resolves source from ROOT repo when script lives outside" {
  toolrepo="$TMP/toolrepo2"
  mkdir -p "$toolrepo/bin" "$toolrepo/lib/core" "$toolrepo/.devtools"
  cp "$SCRIPT" "$toolrepo/bin/git-devtools-update.sh"
  cp "$REPO_ROOT/lib/core/utils.sh" "$toolrepo/lib/core/utils.sh"
  cp "$REPO_ROOT/lib/core/git-ops.sh" "$toolrepo/lib/core/git-ops.sh"
  chmod +x "$toolrepo/bin/git-devtools-update.sh"
  printf "vX\n" > "$toolrepo/.devtools/VENDORED_TAG"

  git init -q "$toolrepo"
  git -C "$toolrepo" config user.name "Test Bot"
  git -C "$toolrepo" config user.email "test@example.com"
  git -C "$toolrepo" config commit.gpgsign false
  git -C "$toolrepo" config tag.gpgsign false
  git -C "$toolrepo" remote add origin "git@github.com:acme/toolrepo2.git"
  printf "toolrepo2\n" > "$toolrepo/README.md"
  git -C "$toolrepo" add .
  git -C "$toolrepo" commit -q -m "init toolrepo2"
  git -C "$toolrepo" tag -a -m "tag v0.3.0" v0.3.0

  foreign_bin="$TMP/foreign/bin"
  foreign_lib="$TMP/foreign/lib/core"
  mkdir -p "$foreign_bin" "$foreign_lib"
  cp "$toolrepo/bin/git-devtools-update.sh" "$foreign_bin/git-devtools-update.sh"
  cp "$toolrepo/lib/core/utils.sh" "$foreign_lib/utils.sh"
  cp "$toolrepo/lib/core/git-ops.sh" "$foreign_lib/git-ops.sh"
  chmod +x "$foreign_bin/git-devtools-update.sh"

  real_git="$(command -v git)"
  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" && "\${2:-}" == "--tags" && "\${3:-}" == "--refs" ]]; then
  echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/v0.3.0"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$TMP/fakebin/git"

  run bash -lc "
    set -euo pipefail
    cd '$toolrepo'
    PATH='$TMP/fakebin':\"\$PATH\" '$foreign_bin/git-devtools-update.sh' list
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Consultando upstream oficial: https://github.com/acme/toolrepo2.git"* ]]
  [[ "$output" == *"v0.3.0"* ]]
}

@test "devtools-update: TAG without --repo in vendored mode downloads tarball from lock source" {
  mkdir -p "$CONSUMER/.devtools"
  printf "legacy\n" > "$CONSUMER/.devtools/OLD.txt"
  printf "v0.0.1\n" > "$CONSUMER/.devtools/VENDORED_TAG"
  cat > "$CONSUMER/.devtools.lock" <<'LOCK'
DEVTOOLS_SOURCE="acme/erd-devtools"
DEVTOOLS_VERSION="v0.0.1"
DEVTOOLS_SUBDIR=".devtools"
LOCK

  fixture_root="$TMP/fixture/erd-devtools-v0.0.2/.devtools/bin"
  mkdir -p "$fixture_root"
  printf "#!/usr/bin/env bash\necho remote-update\n" > "$fixture_root/from-remote.sh"
  chmod +x "$fixture_root/from-remote.sh"
  tar -czf "$TMP/devtools-v0.0.2.tar.gz" -C "$TMP/fixture" "erd-devtools-v0.0.2"

  mkdir -p "$TMP/fakebin"
  cat > "$TMP/fakebin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o)
      out="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
cp "$DEVTOOLS_TEST_TARBALL" "$out"
EOF
  chmod +x "$TMP/fakebin/curl"

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    DEVTOOLS_TEST_TARBALL='$TMP/devtools-v0.0.2.tar.gz' \
      PATH='$TMP/fakebin':\"\$PATH\" \
      '$SCRIPT' TAG=v0.0.2 --yes
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Descargando: https://github.com/acme/erd-devtools/archive/refs/tags/v0.0.2.tar.gz"* ]]
  [ -x "$CONSUMER/.devtools/bin/from-remote.sh" ]
  run bash -lc "grep -n 'DEVTOOLS_VERSION=\"v0.0.2\"' '$CONSUMER/.devtools.lock'"
  [ "$status" -eq 0 ]
}

@test "devtools-update: TAG without --repo fails when source is unknown" {
  mkdir -p "$CONSUMER/.devtools"
  printf "v0.0.1\n" > "$CONSUMER/.devtools/VENDORED_TAG"
  cat > "$CONSUMER/.devtools.lock" <<'LOCK'
DEVTOOLS_SOURCE="local/erd-devtools"
DEVTOOLS_VERSION="v0.0.1"
DEVTOOLS_SUBDIR=".devtools"
LOCK

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' TAG=v0.0.2 --yes
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Origen remoto desconocido."* ]]
  [[ "$output" == *"--source owner/repo"* ]]
}

@test "devtools-update: TAG=... works in submodule-like mode using local --repo (no prompts via --yes)" {
  # Simulamos submódulo real apuntando al upstream local.
  rm -rf "$CONSUMER/.devtools"
  git -C "$CONSUMER" -c protocol.file.allow=always submodule add -q "$UPSTREAM" .devtools
  git -C "$CONSUMER" add .gitmodules .devtools
  git -C "$CONSUMER" commit -q -m "add devtools submodule"

  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' TAG=v0.0.2 --repo '$UPSTREAM' --yes
  "
  [ "$status" -eq 0 ]

  # Verifica que dentro de .devtools quedó en detached/tag (o al menos que conoce el tag)
  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER/.devtools'
    git describe --tags --exact-match 2>/dev/null || git describe --tags
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.0.2"* ]]
}

@test "devtools-update: fails with helpful error when TAG is missing value" {
  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' TAG= --repo '$UPSTREAM' --yes
  "
  [ "$status" -ne 0 ]
  # Ajusta el texto exacto si tu script usa otro mensaje
  [[ "$output" == *"TAG"* ]]
}

@test "devtools-update: rejects unknown option (guardrail)" {
  run bash -lc "
    set -euo pipefail
    cd '$CONSUMER'
    '$SCRIPT' --definitely-not-a-flag
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Opción"* || "$output" == *"unknown"* || "$output" == *"desconoc"* || "$output" == *"Argumento inesperado"* ]]
}

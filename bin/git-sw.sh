#!/usr/bin/env bash
# Alias de limpieza hacia git-sweep.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/git-sweep.sh" "$@"

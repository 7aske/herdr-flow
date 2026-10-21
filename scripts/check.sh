#!/usr/bin/env bash
# Run CONSTRAINTS.md fast checks (shellcheck + bats).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shopt -s nullglob
scripts=(bin/herdr-flow lib/*.sh)
shellcheck -x "${scripts[@]}"
bats tests/

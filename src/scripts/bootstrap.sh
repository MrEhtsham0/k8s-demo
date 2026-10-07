#!/usr/bin/env bash
# One-time (or anytime) setup for a fresh clone: deps + Git hooks.
# Usage: ./src/scripts/bootstrap.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> uv sync"
if command -v uv >/dev/null 2>&1; then
  uv sync
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command '& uv sync'
else
  echo "uv not found. Install it from https://docs.astral.sh/uv/" >&2
  exit 1
fi

echo "==> Git hooks"
bash "$ROOT/.githooks/install"

echo "OK: bootstrap complete"

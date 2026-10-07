#!/usr/bin/env bash
# Shared helpers for client-side Git hooks.
# Enable: run ./.githooks/install (or ./src/scripts/bootstrap.sh)

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if command -v uv >/dev/null 2>&1; then
  HAS_UV=1
elif command -v powershell.exe >/dev/null 2>&1; then
  HAS_UV=0
else
  echo "uv not found. Install it from https://docs.astral.sh/uv/" >&2
  exit 1
fi

run_uv() {
  # Usage: run_uv <args after "uv run --frozen">
  if [[ "$HAS_UV" -eq 1 ]]; then
    uv run --frozen "$@"
  else
    local joined=""
    local a
    for a in "$@"; do
      joined+=" $a"
    done
    powershell.exe -NoProfile -Command "& uv run --frozen${joined}"
  fi
}

run_uv_sync() {
  if [[ "$HAS_UV" -eq 1 ]]; then
    uv sync --frozen
  else
    powershell.exe -NoProfile -Command '& uv sync --frozen'
  fi
}

run_helm_lint() {
  if command -v helm >/dev/null 2>&1; then
    echo "==> Helm lint (charts/k8s-python)"
    helm lint charts/k8s-python
  else
    echo "==> Helm lint skipped (helm not on PATH)"
  fi
}

run_python_quality() {
  echo "==> Python lint (ruff check)"
  run_uv ruff check .
  echo "==> Python format (ruff format --check)"
  run_uv ruff format . --check
}

deps_may_have_changed() {
  local base="${1:-HEAD@{1}}"
  local head="${2:-HEAD}"
  git diff --name-only "$base" "$head" -- uv.lock pyproject.toml 2>/dev/null | grep -q .
}

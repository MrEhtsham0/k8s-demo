#!/usr/bin/env bash
# Step-by-step Helm deploy for this project.
# Usage: ./src/scripts/deploy-helm.sh
#
# Prerequisites:
#   1. helm installed (https://helm.sh/docs/intro/install/)
#   2. kind cluster running + image loaded:
#        ./src/scripts/rebuild-docker.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CHART="./charts/k8s-python"
RELEASE="k8s-python"
SECRET_VALUES="$CHART/values-secret.yaml"

echo "==> Working directory: $ROOT"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found. Install Helm first, then re-run."
  exit 1
fi

echo "==> Step 1: lint chart"
helm lint "$CHART"

echo "==> Step 2: render templates (dry view — does not apply)"
helm template "$RELEASE" "$CHART" | head -n 40
echo "... (truncated)"

HELM_ARGS=(upgrade --install "$RELEASE" "$CHART")
if [[ -f "$SECRET_VALUES" ]]; then
  echo "==> Using secret values: $SECRET_VALUES"
  HELM_ARGS+=(-f "$SECRET_VALUES")
else
  echo "==> No values-secret.yaml — using defaults from values.yaml"
  echo "    Optional: cp $CHART/values-secret.yaml.example $SECRET_VALUES"
fi

echo "==> Step 3: install/upgrade release"
helm "${HELM_ARGS[@]}"

echo "==> Step 4: wait for workloads"
if kubectl get deployment postgres >/dev/null 2>&1; then
  kubectl rollout status deployment/postgres
fi
kubectl rollout status deployment/k8s-python

echo "==> Step 5: status"
helm status "$RELEASE"
kubectl get pods
kubectl get hpa
kubectl get cronjobs

echo "==> Done."
echo "Port-forward:"
echo "  kubectl port-forward service/k8s-python 8000:80"
echo "Change APP_ENV without rebuilding image:"
echo "  helm upgrade $RELEASE $CHART --set config.APP_ENV=staging"
echo "  kubectl rollout restart deployment/k8s-python"

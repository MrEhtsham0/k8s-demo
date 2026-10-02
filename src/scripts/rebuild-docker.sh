#!/usr/bin/env bash
# Rebuild the Docker image and load it into the kind cluster.
# Usage: ./src/scripts/rebuild-docker.sh

set -euo pipefail

# Project root = two levels up from src/scripts/
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

IMAGE="k8s-python:latest"
CLUSTER="learning"

echo "==> Working directory: $ROOT"
echo "==> Building image: $IMAGE"
docker build -t "$IMAGE" .

echo "==> Loading image into kind cluster: $CLUSTER"
kind load docker-image "$IMAGE" --name "$CLUSTER"

echo "==> Done. Run ./src/scripts/redeploy-k8s.sh to restart the app."

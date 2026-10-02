#!/usr/bin/env bash
# Apply Kubernetes manifests and restart the app pods.
# Usage: ./src/scripts/redeploy-k8s.sh

set -euo pipefail

# Project root = two levels up from src/scripts/
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> Working directory: $ROOT"

if [[ ! -f k8s/k8s-secret.yml ]]; then
  echo "Missing k8s/k8s-secret.yml (gitignored on purpose)."
  echo "  cp k8s/k8s-secret.yml.example k8s/k8s-secret.yml"
  echo "Then edit passwords/DATABASE_URL and re-run this script."
  exit 1
fi

echo "==> Applying manifests (Secret first, then Postgres, app, HPA, CronJob)"
kubectl apply -f k8s/k8s-secret.yml
kubectl apply -f k8s/k8s-postgres.yml
kubectl apply -f k8s/k8s-configmap.yml
kubectl apply -f k8s/k8s-deployment.yml
kubectl apply -f k8s/k8s-service.yml
kubectl apply -f k8s/k8s-ingress.yml
kubectl apply -f k8s/k8s-hpa.yml
kubectl apply -f k8s/k8s-cronjob.yml

echo "==> Waiting for Postgres"
kubectl rollout status deployment/postgres

echo "==> Restarting app"
kubectl rollout restart deployment/k8s-python
kubectl rollout status deployment/k8s-python

echo "==> Pods / HPA / CronJobs"
kubectl get pods
kubectl get hpa
kubectl get cronjobs

echo "==> Done."
echo "Run this in another terminal (it stays open on purpose):"
echo "  kubectl port-forward service/k8s-python 8000:80"
echo "Then check:"
echo "  curl http://localhost:8000/health"
echo "  curl http://localhost:8000/users"
echo ""
echo "CronJob count-to-100 runs every 5 minutes. Check logs with:"
echo "  kubectl get jobs -l app=count-to-100"
echo "  kubectl logs -l app=count-to-100 --tail=120"
echo "Run once immediately (don't wait 5 min):"
echo "  kubectl create job --from=cronjob/count-to-100 count-to-100-manual"
echo "  kubectl logs job/count-to-100-manual"
echo ""
echo "Tip: change APP_ENV in k8s/k8s-configmap.yml, apply, restart — no image rebuild needed."
echo "HPA needs metrics-server. If TARGETS shows <unknown>, install it for kind:"
echo "  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo "  kubectl -n kube-system patch deployment metrics-server --type=json -p='[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--kubelet-insecure-tls\"}]'"

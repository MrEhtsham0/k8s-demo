# Ingress on kind — learning guide

What you practiced today: install an Ingress **controller**, wire your app Ingress to it, resolve `k8s-python.local`, and test without `kubectl port-forward` (when port 80 is mapped).

## Concepts (short)

| Piece | Role |
|--------|------|
| **Service** | Stable in-cluster name → pods |
| **Ingress** | HTTP rules (host/path → Service) |
| **Ingress controller** (nginx) | Program that enforces those rules |
| **hosts file** | Maps `k8s-python.local` → `127.0.0.1` on your PC |

Local Ingress is **not** public. Only your machine (or a tunnel/cloud later).

---

## 1. Kind cluster with ports 80/443 (needed for `http://k8s-python.local`)

If `curl http://k8s-python.local/health` fails with “connection refused” on port 80, recreate kind with this config (repo root: `kind-config.yaml`):

```powershell
kind delete cluster --name learning
kind create cluster --name learning --config kind-config.yaml
```

Then reload the app image and redeploy (see project scripts).

---

## 2. Install ingress-nginx (cluster addon — not part of the app Helm chart)

```powershell
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
```

Wait / check:

```powershell
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=90s

kubectl get pods -n ingress-nginx
kubectl get ingressclass
```

Expected:

- Controller pod `1/1 Running`
- Admission Jobs may show `Completed` (normal)
- IngressClass name: `nginx`

You do **not** reinstall this on every app deploy. In production it is usually installed once by the platform/Terraform/Helm.

---

## 3. Deploy / upgrade the app (Helm)

```powershell
# from project root
.\src\scripts\rebuild-docker.sh
.\src\scripts\deploy-helm.sh
```

Or:

```powershell
helm upgrade --install k8s-python ./charts/k8s-python
```

The chart sets `ingress.className: nginx` and host `k8s-python.local` (see `charts/k8s-python/values.yaml`).

Check:

```powershell
kubectl get ingress
helm status k8s-python
```

You want `CLASS` = `nginx`, host = `k8s-python.local`.

### One-time manual patch (if an old Ingress has CLASS `<none>`)

PowerShell:

```powershell
kubectl patch ingress k8s-python --type=merge -p "{`"spec`":{`"ingressClassName`":`"nginx`"}}"
```

Prefer fixing via Helm values instead of patching every time.

---

## 4. Windows hosts file (Admin)

File: `C:\Windows\System32\drivers\etc\hosts`

Add (do **not** comment out Docker Desktop lines):

```text
127.0.0.1 k8s-python.local
```

Save as Administrator, then:

```powershell
ipconfig /flushdns
ping k8s-python.local
```

`ping` should resolve to `127.0.0.1`.

---

## 5. Test

### Ideal (port 80 mapped + hosts OK)

```powershell
curl.exe http://k8s-python.local/health
curl.exe http://k8s-python.local/users
```

### Bypass DNS (Ingress only)

```powershell
curl.exe -H "Host: k8s-python.local" http://127.0.0.1/health
```

### Workaround if host port 80 is not mapped

```powershell
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

```powershell
curl.exe -H "Host: k8s-python.local" http://127.0.0.1:8080/health
curl.exe http://k8s-python.local:8080/health
```

---

## Troubleshooting

| Symptom | Meaning / fix |
|---------|----------------|
| `Could not resolve host` | hosts not saved / not Admin / flush DNS |
| `Failed to connect … :80` | kind missing `extraPortMappings` → recreate with `kind-config.yaml` |
| Ingress `CLASS: <none>` | set `ingress.className=nginx` in Helm and upgrade |
| 404 from nginx | wrong `Host` header or Ingress host mismatch |
| Works with port-forward to Service `:8000` but not Ingress | controller / class / port 80 issue |

---

## Helm vs manual commands

| Action | In Helm chart? |
|--------|----------------|
| Install ingress-nginx | **No** (cluster) |
| hosts file | **No** |
| kind port mappings | **No** (`kind-config.yaml`) |
| App Ingress host + `ingressClassName` | **Yes** (`values.yaml` + template) |

---

## Related loose ends (same learning week)

- **HPA target:** use `70` in production-like demos (`autoscaling.targetCPUUtilizationPercentage`). `5` was only for easy scale testing.
- **metrics-server** (for HPA on kind):

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json -p="[{`"op`":`"add`",`"path`":`"/spec/template/spec/containers/0/args/-`",`"value`":`"--kubelet-insecure-tls`"}]"
kubectl top pods
kubectl get hpa
```

- **NetworkPolicy** (only app → Postgres): see `charts/k8s-python/templates/networkpolicy.yaml` (needs a CNI that enforces policies).

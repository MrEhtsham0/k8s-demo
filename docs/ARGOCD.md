# Argo CD + GitOps — learning & implementation guide

This guide is for **this project** (`charts/k8s-python` on kind).  
Goal: stop deploying only with `helm upgrade` by hand; let **Git** drive the cluster.

Related: Helm chart under `charts/k8s-python/`, Ingress notes in `docs/INGRESS.md`.

---

## Concepts (short)

| Idea | Meaning |
|------|---------|
| **GitOps** | Desired state lives in Git. The cluster should match Git. |
| **Argo CD** | A controller that watches Git and syncs Kubernetes (and Helm charts). |
| **Application** | An Argo CD object: “this Git path → this cluster/namespace”. |
| **Synced** | Live cluster matches Git. |
| **OutOfSync** | Someone changed the cluster (or Git) and they differ. |
| **Self-heal** | If you `kubectl` something away, Argo puts it back from Git. |
| **Prune** | If you remove a resource from the chart, Argo deletes it from the cluster. |

### Mental model

```text
You edit charts/values → git push
        ↓
   Argo CD sees Git change
        ↓
   helm template + apply (sync)
        ↓
   kind cluster updated
```

Argo does **not** replace Kubernetes or Helm. It **runs Helm/kubectl for you** from Git.

---

## What you already have (reuse it)

| Piece | Path / status |
|--------|----------------|
| Helm chart | `charts/k8s-python/` |
| Values | `charts/k8s-python/values.yaml` |
| kind cluster | `learning` (+ optional `kind-config.yaml`) |
| Manual Helm deploy | `src/scripts/deploy-helm.sh` |

Argo will point at **`charts/k8s-python`**, not the raw `k8s/` folder.

---

## Prerequisites

1. kind cluster running (`kind get clusters`)
2. Docker image loaded for local kind (`./src/scripts/rebuild-docker.sh`)
3. Project pushed to GitHub (Argo must clone the repo)
4. `kubectl` context pointing at kind
5. (Recommended) ingress-nginx already installed if you use Ingress — see `docs/INGRESS.md`

**Important:** pick **one** deploy driver for the app:

- either Argo CD, **or**
- `deploy-helm.sh`

Don’t keep both fighting over the same release.

---

## Step 1 — Install Argo CD on kind

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait until pods are ready:

```powershell
kubectl get pods -n argocd -w
```

When most pods are `Running` / `Completed`, continue.

---

## Step 2 — Open the Argo CD UI

Port-forward the API server:

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Browser: [https://localhost:8080](https://localhost:8080)  
(Accept the self-signed cert warning.)

**Initial admin password** (username is `admin`):

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

On Git Bash / WSL:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

Optional CLI (`argocd` binary): install from [Argo CD CLI docs](https://argo-cd.readthedocs.io/en/stable/cli_installation/) if you want terminal login later.

---

## Step 3 — Make sure Git has your chart

Argo reads **remote Git**, not only your laptop folder.

```powershell
git status
git add charts/k8s-python docs
git commit -m "Add Helm chart for GitOps"
git push origin main
```

Confirm the chart exists on GitHub under `charts/k8s-python/`.

If the repo is **private**, you must add a repo credential in Argo CD (Settings → Repositories). Public repos work without that.

---

## Step 4 — Create an Argo CD Application

### Option A — YAML (recommended to learn GitOps fully)

Create a file (example) and apply it, **or** commit it under something like `argocd/application.yaml` later:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-python
  namespace: argocd
spec:
  project: default

  source:
    # Change to YOUR GitHub URL
    repoURL: https://github.com/MrEhtsham0/k8s-demo.git
    targetRevision: main
    path: charts/k8s-python
    # Helm uses Chart.yaml + values.yaml in that path by default
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    # Start with MANUAL sync for learning; then enable automated
    syncOptions:
      - CreateNamespace=true
    # Uncomment when you trust the flow:
    # automated:
    #   prune: true
    #   selfHeal: true
```

Apply:

```powershell
kubectl apply -f argocd/application.yaml
```

(Adjust path if you store the file elsewhere.)

### Option B — UI

1. **New App**
2. Application Name: `k8s-python`
3. Project: `default`
4. Repository URL: your GitHub repo
5. Revision: `main`
6. Path: `charts/k8s-python`
7. Cluster: `in-cluster`
8. Namespace: `default`
9. Create → **Sync**

---

## Step 5 — First sync (manual)

In UI: open app → **Sync** → Synchronize.

Or CLI (if installed):

```powershell
argocd app sync k8s-python
argocd app get k8s-python
```

With kubectl only:

```powershell
kubectl get application -n argocd
kubectl get pods
```

Expect: Deployment, Service, Ingress, Postgres, HPA, CronJob, etc. (same as Helm).

Test the app (Ingress or port-forward — see `docs/INGRESS.md`):

```powershell
curl.exe http://k8s-python.local/health
# or
kubectl port-forward service/k8s-python 8000:80
curl.exe http://localhost:8000/health
```

---

## Step 6 — Prove GitOps (change → push → sync)

1. Edit `charts/k8s-python/values.yaml`, e.g.:

   ```yaml
   config:
     APP_ENV: staging
   ```

2. Commit and push:

   ```powershell
   git add charts/k8s-python/values.yaml
   git commit -m "Set APP_ENV to staging via GitOps"
   git push origin main
   ```

3. In Argo UI: app becomes **OutOfSync** → **Sync** (or wait if auto-sync is on).

4. Restart is sometimes needed for ConfigMap env pickup:

   ```powershell
   kubectl rollout restart deployment/k8s-python
   ```

5. Check `/health` shows `"environment":"staging"`.

**That loop is GitOps.**

---

## Step 7 — Turn on auto-sync + self-heal

Update the Application `syncPolicy`:

```yaml
syncPolicy:
  automated:
    prune: true      # remove resources deleted from Git
    selfHeal: true    # undo manual kubectl drift
  syncOptions:
    - CreateNamespace=true
```

Apply / sync the Application itself.

**Demo self-heal:**

```powershell
kubectl delete configmap k8s-python-config
```

Watch Argo recreate it from Git.

**Demo prune:** remove CronJob from the chart (or set `cronjob.enabled: false`), push, sync → CronJob disappears.

---

## Step 8 — Day-2 workflow (what you stop doing)

| Old habit | New habit |
|-----------|-----------|
| `./src/scripts/deploy-helm.sh` for every change | `git push` → Argo sync |
| `kubectl edit` in the cluster | edit chart/values in Git |
| Hope staging matches laptop | Git commit = environment truth |

Keep `deploy-helm.sh` only for emergencies or clusters without Argo.

---

## Kind + local images (important)

Your chart uses:

```yaml
image:
  repository: k8s-python
  tag: latest
  pullPolicy: IfNotPresent
```

On kind you still must **build and load** the image yourself:

```powershell
./src/scripts/rebuild-docker.sh
```

Argo syncs **manifests**, not Docker builds.

### Why `latest` is awkward with GitOps

If only the image bytes change but Git `tag: latest` stays the same, Argo may **not** roll pods.

Better later:

1. Tag images `v0.1.0` or git SHA  
2. Commit the new tag into `values.yaml`  
3. Push → Argo syncs → new pods  

Optional next topics: GitHub Actions build/push + commit tag; Argo CD Image Updater.

---

## Secrets with GitOps

Do **not** commit real passwords.

| Approach | Notes |
|----------|--------|
| Learning defaults in `values.yaml` | OK for local kind only |
| `values-secret.yaml` gitignored | Fine locally; Argo on the cluster **cannot** read your laptop file |
| Sealed Secrets / External Secrets / AWS SM | Production pattern |
| Argo CD repo credentials | For private Git |

For kind learning, chart defaults (`app`/`app`) are enough. For real GitOps + secrets, add External Secrets later.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| App stuck **Unknown** / can’t clone | Wrong `repoURL`, private repo without credentials, bad branch |
| **OutOfSync** forever | Sync manually; check sync errors in UI |
| Sync OK but app CrashLoop | Image missing on kind → `rebuild-docker.sh` |
| ConfigMap changed but `/health` old | `kubectl rollout restart deployment/k8s-python` |
| Fight with Helm CLI | Uninstall manual release or let Argo own resources; don’t dual-manage |
| UI password secret missing | Already logged in / secret rotated; reset per Argo docs |

Useful commands:

```powershell
kubectl get applications -n argocd
kubectl describe application k8s-python -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

---

## What to learn next (after this works)

1. **App of Apps** — one root Application that syncs many apps  
2. **Environments** — `values-dev.yaml` / `values-prod.yaml` or separate branches/dirs  
3. **CI + GitOps** — CI builds image; GitOps deploys manifests  
4. **RBAC / SSO** on Argo CD  
5. **Multi-cluster** (dev kind vs EKS)  

---

## Checklist (copy/paste)

- [ ] Argo CD installed in `argocd` namespace  
- [ ] UI login works (`port-forward` + admin password)  
- [ ] Chart is on GitHub under `charts/k8s-python`  
- [ ] Application created (UI or YAML)  
- [ ] First **Sync** succeeded; pods Running  
- [ ] Change `values.yaml` → push → sync → see change  
- [ ] Enable `automated.prune` + `selfHeal`  
- [ ] Stop using `deploy-helm.sh` for normal updates  

---

## One-line summary

**Install Argo CD → create an Application pointing at `charts/k8s-python` in Git → sync → make all future changes via git push (GitOps).**

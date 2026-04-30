# ArgoCD — GitOps for `devops-python-app` (Lab 13)

> Source of truth: **Git**. ArgoCD continuously reconciles the
> cluster against the manifests in this repository. Any manual
> change on the cluster (`kubectl scale`, `kubectl edit`, …) is
> considered drift and, for environments with `selfHeal: true`,
> reverted automatically.

All manifests live in [`k8s/argocd/`](argocd/).

| File | Purpose |
|---|---|
| [`argocd/application.yaml`](argocd/application.yaml) | Single-env app (`default` ns), **manual sync** |
| [`argocd/application-dev.yaml`](argocd/application-dev.yaml) | `dev` ns, **auto-sync + self-heal + prune** |
| [`argocd/application-prod.yaml`](argocd/application-prod.yaml) | `prod` ns, **manual sync** |
| [`argocd/applicationset.yaml`](argocd/applicationset.yaml) | Bonus: generates both via List generator |
| [`argocd/install.sh`](argocd/install.sh) | One-shot bootstrap (install + apply) |

---

## 1. ArgoCD Setup

### 1.1 Install via Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.extraArgs='{--insecure}' \
  --wait --timeout 10m

kubectl wait --for=condition=available deploy/argocd-server \
  -n argocd --timeout=5m
```

Or just run:

```bash
./k8s/argocd/install.sh
```

### 1.2 Access the UI

```bash
# UI → https://localhost:8080  (username: admin)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### 1.3 CLI login

```bash
# macOS
brew install argocd

argocd login localhost:8080 --insecure --username admin
argocd version
argocd app list
```

### 1.4 Verification

```text
$ kubectl get pods -n argocd
NAME                                          READY   STATUS    RESTARTS   AGE
argocd-application-controller-0               1/1     Running   0          3m
argocd-applicationset-controller-...          1/1     Running   0          3m
argocd-dex-server-...                         1/1     Running   0          3m
argocd-notifications-controller-...           1/1     Running   0          3m
argocd-redis-...                              1/1     Running   0          3m
argocd-repo-server-...                        1/1     Running   0          3m
argocd-server-...                             1/1     Running   0          3m
```

---

## 2. Application Configuration

The application manifests all point at the Helm chart that lives
in this repo at [`k8s/devops-python-app`](devops-python-app/).

### 2.1 Anatomy of [`application.yaml`](argocd/application.yaml:1)

```yaml
source:
  repoURL: https://github.com/aalikorn/DevOps-Core-Course.git
  targetRevision: lab13
  path: k8s/devops-python-app
  helm:
    valueFiles:
      - values.yaml
destination:
  server: https://kubernetes.default.svc
  namespace: default
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

Key points:

- **`repoURL` / `targetRevision` / `path`** tell ArgoCD *where* to
  find the desired state (Git is the source of truth).
- **`helm.valueFiles`** selects which values override to apply for
  this Application (different per environment).
- **`destination`** is *where* on the cluster the state gets
  reconciled (cluster + namespace).
- **`syncPolicy.syncOptions: CreateNamespace=true`** allows
  ArgoCD to create the target namespace on first sync.
- Absent `syncPolicy.automated` ⇒ **manual sync**.

### 2.2 Apply and sync

```bash
kubectl apply -f k8s/argocd/application.yaml
argocd app sync python-app
argocd app get python-app
```

### 2.3 GitOps workflow test

1. Edit [`k8s/devops-python-app/values.yaml`](devops-python-app/values.yaml) —
   e.g. change `replicaCount: 2` → `3`.
2. `git commit -am "chore: scale to 3 replicas" && git push`.
3. In the UI the Application turns **OutOfSync** (yellow arrow);
   the diff view shows `replicas: 2 → 3`.
4. Click **Sync** (or `argocd app sync python-app`).
5. Rollout completes; state goes back to **Synced / Healthy**.

---

## 3. Multi-Environment Deployment

### 3.1 Namespaces

```bash
kubectl create namespace dev
kubectl create namespace prod
```

### 3.2 Configuration differences

| Aspect | `dev` ([`application-dev.yaml`](argocd/application-dev.yaml)) | `prod` ([`application-prod.yaml`](argocd/application-prod.yaml)) |
|---|---|---|
| Namespace | `dev` | `prod` |
| Values files | `values.yaml` + `values-dev.yaml` | `values.yaml` + `values-prod.yaml` |
| Replicas | 1 | 3 |
| Image tag / pullPolicy | `latest` / `Always` | pinned / `IfNotPresent` |
| Resources | 50m / 64Mi | larger limits |
| Sync | **auto + prune + selfHeal** | **manual only** |
| Failure budget | `maxUnavailable: 1` (downtime ok) | `maxUnavailable: 0` (no downtime) |

### 3.3 Sync-policy rationale

**Dev — auto-sync everything:**

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

- Fast feedback loop: merge to Git ⇒ live on dev in minutes.
- Drift is irrelevant, developers will re-deploy constantly.
- `prune` keeps the namespace clean as files are removed from Git.
- `selfHeal` keeps dev honest — no “works because someone kubectl-ed
  something manually last week” situations.

**Prod — manual sync only:**

- Changes in Git are visible as **OutOfSync** and wait for a human.
- Operator can inspect the diff and pick the deployment window.
- Easier compliance / change-management trail.
- Rollback is explicit — a `git revert` + manual sync.
- The cluster-side safety net (`selfHeal`) is deliberately OFF so
  that emergency manual hotfixes are not undone mid-incident.

### 3.4 Apply and verify

```bash
kubectl apply -f k8s/argocd/application-dev.yaml
kubectl apply -f k8s/argocd/application-prod.yaml

# Prod needs a manual sync the first time:
argocd app sync python-app-prod

argocd app list
kubectl get pods -n dev
kubectl get pods -n prod
```

Expected:

```text
$ argocd app list
NAME              PROJECT  STATUS  HEALTH   SYNCPOLICY  REPO
python-app        default  Synced  Healthy  Manual      .../DevOps-Core-Course.git
python-app-dev    default  Synced  Healthy  Auto-Prune  .../DevOps-Core-Course.git
python-app-prod   default  Synced  Healthy  Manual      .../DevOps-Core-Course.git
```

---

## 4. Self-Healing & Sync Policies

Reconciliation interval: **~3 min** (controller default, polled
from Git). Immediate sync is achievable via a GitHub webhook.

### 4.1 Manual scale test (dev, `selfHeal: true`)

```bash
# BEFORE — Git says replicaCount: 1
kubectl get deploy -n dev
# NAME             READY   UP-TO-DATE   AVAILABLE
# python-app-dev   1/1     1            1

# Introduce drift
kubectl scale deployment python-app-dev -n dev --replicas=5

# Right after drift
kubectl get deploy -n dev
# NAME             READY   UP-TO-DATE   AVAILABLE
# python-app-dev   5/5     5            5

# Within ~3 minutes ArgoCD reverts:
kubectl get deploy -n dev -w
# python-app-dev   1/1     1            1
```

In the UI the Application briefly flips to **OutOfSync** and the
history tab records an automatic **Sync (self-heal)** operation.

### 4.2 Pod deletion test — *Kubernetes*, not ArgoCD

```bash
kubectl delete pod -n dev -l app.kubernetes.io/name=devops-python-app
# pod "python-app-dev-6f..." deleted

kubectl get pods -n dev -w
# python-app-dev-6f...   0/1   ContainerCreating   0s
# python-app-dev-6f...   1/1   Running             3s
```

The pod comes back immediately because the Deployment's
ReplicaSet controller re-creates it — this is **Kubernetes
self-healing** (desired pod count), *not* ArgoCD. ArgoCD was
never notified because the desired state in Git (a Deployment
with `replicas: 1`) was never violated.

### 4.3 Configuration-drift test

```bash
# Add an unmanaged label
kubectl label deploy python-app-dev -n dev drift=manual --overwrite

# Diff view
argocd app diff python-app-dev
# metadata.labels.drift: "manual"   (cluster has it, Git does not)
```

With `selfHeal: true` ArgoCD removes the label at the next
reconcile. In prod (no self-heal) the drift would stay visible
as **OutOfSync** until a human intervened.

### 4.4 Kubernetes self-healing vs. ArgoCD self-healing

| | **Kubernetes self-healing** | **ArgoCD self-healing** |
|---|---|---|
| Scope | Pod-level (via ReplicaSet, StatefulSet, DaemonSet) | Whole-object level (Deployment, ConfigMap, Service, …) |
| Source of truth | API-server objects | **Git repository** |
| Trigger | Pod failure, node failure, liveness probe | Diff between Git and cluster |
| Speed | Seconds | Default ≤ 3 min (or webhook) |
| Needs ArgoCD? | No | Yes, plus `automated.selfHeal: true` |

### 4.5 What triggers an ArgoCD sync?

1. Periodic polling of the Git repo (default `3m`,
   `timeout.reconciliation`).
2. Git webhook (instant).
3. Manual: UI, `argocd app sync`, or `kubectl patch` with
   `syncOperation`.
4. Automatic, if `syncPolicy.automated` is set and either:
   - Git has moved forward, or
   - the cluster state has drifted (`selfHeal: true`).

---

## 5. Bonus — ApplicationSet

Instead of maintaining `application-dev.yaml` **and**
`application-prod.yaml` side by side, a single
[`applicationset.yaml`](argocd/applicationset.yaml) generates
both from one template using the **List** generator.

### 5.1 How it works

```yaml
generators:
  - list:
      elements:
        - env: dev
          namespace: dev
          valuesFile: values-dev.yaml
          autoSync: "true"
        - env: prod
          namespace: prod
          valuesFile: values-prod.yaml
          autoSync: "false"
template:
  metadata:
    name: 'python-app-{{ .env }}'
  spec:
    source:
      helm:
        valueFiles: ['values.yaml', '{{ .valuesFile }}']
    destination:
      namespace: '{{ .namespace }}'
    syncPolicy:
      {{- if eq .autoSync "true" }}
      automated: { prune: true, selfHeal: true }
      {{- end }}
```

`goTemplate: true` enables the conditional `{{ if }}` so that
**prod does not inherit `automated`** — exactly matching the
rationale from §3.3.

### 5.2 Apply and observe

```bash
# Remove the individual Applications first to avoid dupes
kubectl delete -n argocd application python-app-dev python-app-prod --ignore-not-found

kubectl apply -f k8s/argocd/applicationset.yaml

# The controller materialises two Applications:
kubectl get applications -n argocd
# python-app-dev    Synced  Healthy
# python-app-prod   OutOfSync Healthy   (manual — waiting for sync)

kubectl get applicationsets -n argocd
# NAME            AGE
# python-app-set  30s
```

### 5.3 Available generators (when to reach for them)

| Generator | Use case |
|---|---|
| **List** | Small, hand-maintained matrix of envs (what we use). |
| **Cluster** | Deploy the same app across *many clusters* registered in ArgoCD. |
| **Git (files)** | Auto-discover apps from config files under a repo path. |
| **Git (directories)** | Monorepo with one folder per app. |
| **Matrix / Merge** | Combine the above (e.g. cluster × env). |
| **SCM / PR** | Per-branch preview environments. |

### 5.4 Individual Applications vs. ApplicationSet

| Criterion | N × Applications | ApplicationSet |
|---|---|---|
| Adding an env | Copy-paste a whole file | Add one list element |
| DRY-ness | Low (duplication) | High (single template) |
| Conditional per-env settings | Native | Requires Go templating |
| Visibility in UI | One card per app | One card per app (identical) |
| Blast radius of a typo | 1 app | All generated apps |
| Best for | 1–2 envs, ad-hoc | 3+ envs, multi-cluster, per-PR previews |

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| App stuck **Unknown** | Repo URL / credentials wrong → `argocd repo list`. |
| **OutOfSync** that won't clear in dev | `selfHeal: true` fighting a controller that keeps re-adding the field — exclude it in `ignoreDifferences`. |
| UI login fails with self-signed TLS | Re-run with `--set server.extraArgs='{--insecure}'` or use `kubectl port-forward` on `80` of `argocd-server`. |
| Helm values not picked up | Check `source.helm.valueFiles` order — later files override earlier ones. |
| `CreateNamespace=true` ignored | Option must sit under `syncPolicy.syncOptions`, not inside `automated`. |

---

## References

- ArgoCD docs: https://argo-cd.readthedocs.io/
- Application CRD: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
- Auto-sync & self-heal: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- ApplicationSet: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
- OpenGitOps principles: https://opengitops.dev/

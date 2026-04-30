# `k8s/argocd/` — ArgoCD manifests (Lab 13)

| File | Purpose |
|---|---|
| [`application.yaml`](application.yaml) | Single-env Application (`default` ns, manual sync) |
| [`application-dev.yaml`](application-dev.yaml) | `dev` Application (auto-sync + self-heal + prune) |
| [`application-prod.yaml`](application-prod.yaml) | `prod` Application (manual sync only) |
| [`applicationset.yaml`](applicationset.yaml) | Bonus: List-generator ApplicationSet producing dev + prod |
| [`install.sh`](install.sh) | One-shot bootstrap: install ArgoCD and apply the Applications |

Full walk-through & rationale: [`../ARGOCD.md`](../ARGOCD.md).

## Quick start

```bash
./install.sh                                # install ArgoCD + apply apps
kubectl port-forward svc/argocd-server -n argocd 8080:443   # open https://localhost:8080
```

## Apply manually

```bash
kubectl apply -f application.yaml
kubectl apply -f application-dev.yaml
kubectl apply -f application-prod.yaml

# or the bonus ApplicationSet (replaces the two env-specific apps):
kubectl apply -f applicationset.yaml
```

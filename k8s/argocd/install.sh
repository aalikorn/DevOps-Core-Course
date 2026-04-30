#!/usr/bin/env bash
# ---------------------------------------------------------------
# install.sh — one-shot bootstrap for ArgoCD (Lab 13)
#
# Installs ArgoCD via Helm, sets up port-forwarding, prints the
# initial admin password, and applies the Application manifests
# from this directory.
#
# Prereqs: kubectl, helm, a working Kubernetes context.
# ---------------------------------------------------------------
set -euo pipefail

ARGOCD_NS="${ARGOCD_NS:-argocd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Adding argo Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "==> Creating namespace '${ARGOCD_NS}' (if missing)"
kubectl get ns "${ARGOCD_NS}" >/dev/null 2>&1 || kubectl create namespace "${ARGOCD_NS}"

echo "==> Installing / upgrading ArgoCD"
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NS}" \
  --set server.extraArgs='{--insecure}' \
  --wait --timeout 10m

echo "==> Waiting for argocd-server to become ready"
kubectl wait --for=condition=available deploy/argocd-server \
  -n "${ARGOCD_NS}" --timeout=5m

echo "==> Creating dev/prod namespaces"
for ns in dev prod; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
done

echo "==> Applying Application manifests"
kubectl apply -f "${SCRIPT_DIR}/application.yaml"
kubectl apply -f "${SCRIPT_DIR}/application-dev.yaml"
kubectl apply -f "${SCRIPT_DIR}/application-prod.yaml"

echo ""
echo "==> Initial admin password:"
kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo ""

cat <<EOF

==> Next steps:

  # Forward the UI to https://localhost:8080  (user: admin)
  kubectl port-forward svc/argocd-server -n ${ARGOCD_NS} 8080:443

  # Or log in via CLI
  argocd login localhost:8080 --insecure --username admin

  # Trigger first sync for the manual apps
  argocd app sync python-app
  argocd app sync python-app-prod

  # List all apps
  argocd app list
EOF

# Secrets Management Quick Start - Lab 11

## Quick Start Guide

This guide helps you complete all tasks for Lab 11.

---

## Prerequisites

- Kubernetes cluster running (kind/minikube)
- Helm installed
- kubectl configured
- Helm chart from Lab 10

---

## Task 1: Kubernetes Secrets Fundamentals (2 pts)

### Create Secret

```bash
# Create secret using kubectl
kubectl create secret generic app-credentials \
  --from-literal=username=admin \
  --from-literal=password=supersecret123

# Verify
kubectl get secrets
```

### View and Decode

```bash
# View secret in YAML
kubectl get secret app-credentials -o yaml

# Decode username
kubectl get secret app-credentials -o jsonpath='{.data.username}' | base64 -d
echo

# Decode password
kubectl get secret app-credentials -o jsonpath='{.data.password}' | base64 -d
echo
```

### Save for Documentation

```bash
kubectl get secret app-credentials -o yaml > task1-secret.yaml
echo "username: $(kubectl get secret app-credentials -o jsonpath='{.data.username}' | base64 -d)" > task1-decoded.txt
echo "password: $(kubectl get secret app-credentials -o jsonpath='{.data.password}' | base64 -d)" >> task1-decoded.txt
```

---

## Task 2: Helm-Managed Secrets (3 pts)

### Files Already Created

✅ `templates/secrets.yaml` - Secret template  
✅ `templates/serviceaccount.yaml` - Service account  
✅ `values.yaml` - Updated with secrets configuration  
✅ `templates/deployment.yaml` - Updated with secret injection

### Deploy with Secrets

```bash
cd k8s

# Install with custom secret values
helm install myapp devops-python-app \
  --set secrets.data.DB_USERNAME=testuser \
  --set secrets.data.DB_PASSWORD=testpass123 \
  --set secrets.data.API_KEY=sk-test-key-12345
```

### Verify Secret Injection

```bash
# Check secret created
kubectl get secrets
kubectl describe secret myapp-devops-python-app-secret

# Get pod name
POD=$(kubectl get pod -l app.kubernetes.io/name=devops-python-app -o jsonpath='{.items[0].metadata.name}')

# Check environment variables
kubectl exec $POD -- env | grep -E "DB_|API_"

# Verify secrets not visible in describe
kubectl describe pod $POD | grep -A 10 "Environment"
```

### Save for Documentation

```bash
kubectl get secret myapp-devops-python-app-secret -o yaml > task2-helm-secret.yaml
kubectl exec $POD -- env | grep -E "DB_|API_" > task2-env-vars.txt
kubectl describe pod $POD > task2-pod-describe.txt
```

---

## Task 3: HashiCorp Vault Integration (3 pts)

### Install Vault

```bash
cd k8s/vault

# Run installation script
./install-vault.sh

# Or manually:
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"
```

### Configure Vault

```bash
# Run configuration script
./vault-config.sh

# This will:
# - Enable KV secrets engine
# - Create sample secrets
# - Enable Kubernetes auth
# - Create policy and role
```

### Manual Configuration (Alternative)

```bash
# Exec into Vault
kubectl exec -it vault-0 -- /bin/sh

# Enable KV v2
vault secrets enable -path=secret kv-v2

# Create secrets
vault kv put secret/devops-python-app/config \
    username="admin" \
    password="supersecret123" \
    api_key="sk-1234567890abcdef"

# Enable K8s auth
vault auth enable kubernetes

# Configure K8s auth
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Create policy
vault policy write devops-python-app - <<EOF
path "secret/data/devops-python-app/*" {
  capabilities = ["read"]
}
EOF

# Create role
vault write auth/kubernetes/role/devops-python-app \
    bound_service_account_names=devops-python-app \
    bound_service_account_namespaces=default \
    policies=devops-python-app \
    ttl=24h

# Exit
exit
```

### Deploy with Vault

```bash
cd k8s

# Upgrade to use Vault
helm upgrade myapp devops-python-app \
  --set vault.enabled=true \
  --set secrets.enabled=false
```

### Verify Vault Injection

```bash
# Get new pod name (after upgrade)
POD=$(kubectl get pod -l app.kubernetes.io/name=devops-python-app -o jsonpath='{.items[0].metadata.name}')

# Check pod has vault-agent sidecar
kubectl get pod $POD -o jsonpath='{.spec.containers[*].name}'
echo

# Check secrets file
kubectl exec $POD -c devops-python-app -- cat /vault/secrets/config

# Check Vault agent logs
kubectl logs $POD -c vault-agent | head -20
```

### Save for Documentation

```bash
kubectl get pods -l app.kubernetes.io/name=vault > task3-vault-pods.txt
kubectl exec vault-0 -- vault read auth/kubernetes/role/devops-python-app > task3-vault-role.txt
kubectl exec $POD -c devops-python-app -- cat /vault/secrets/config > task3-injected-secrets.txt
kubectl logs $POD -c vault-agent > task3-vault-agent-logs.txt
```

---

## Task 4: Documentation (2 pts)

### Documentation Already Created

✅ `SECRETS.md` - Complete documentation with all sections:
- Kubernetes Secrets fundamentals
- Helm secret integration
- Resource management
- Vault integration
- Security analysis
- Troubleshooting

### Add Your Evidence

Edit `SECRETS.md` and add your screenshots/outputs in the appropriate sections.

---

## Bonus: Vault Agent Templates (2.5 pts)

### Already Implemented

The Helm chart already includes Vault template annotation in `values.yaml`:

```yaml
vault:
  template: |
    {{- with secret "secret/data/devops-python-app/config" -}}
    export DB_USERNAME="{{ .Data.data.username }}"
    export DB_PASSWORD="{{ .Data.data.password }}"
    export API_KEY="{{ .Data.data.api_key }}"
    {{- end -}}
```

### Verify Template Rendering

```bash
# Check the rendered secret file
kubectl exec $POD -c devops-python-app -- cat /vault/secrets/config

# Should show:
# export DB_USERNAME="admin"
# export DB_PASSWORD="supersecret123"
# export API_KEY="sk-1234567890abcdef"
```

### Named Templates in _helpers.tpl

Add to `templates/_helpers.tpl`:

```yaml
{{/*
Common environment variables
*/}}
{{- define "devops-python-app.envVars" -}}
- name: APP_ENV
  value: {{ .Values.environment | default "production" | quote }}
- name: LOG_LEVEL
  value: {{ .Values.logLevel | default "info" | quote }}
{{- end }}
```

Use in deployment:

```yaml
env:
  {{- include "devops-python-app.envVars" . | nindent 10 }}
```

---

## Checklist

### Task 1 - Kubernetes Secrets (2 pts)
- [ ] Secret created via kubectl
- [ ] Secret viewed in YAML format
- [ ] Values decoded from base64
- [ ] Security implications documented
- [ ] Screenshots saved

### Task 2 - Helm Secrets (3 pts)
- [x] `templates/secrets.yaml` created
- [x] Secrets in `values.yaml`
- [x] Deployment updated for injection
- [ ] Deployed and verified
- [ ] Environment variables checked
- [ ] Resource limits configured
- [ ] Screenshots saved

### Task 3 - Vault Integration (3 pts)
- [ ] Vault installed
- [ ] KV engine enabled
- [ ] Secrets created in Vault
- [ ] Kubernetes auth configured
- [ ] Policy created
- [ ] Role created
- [ ] Application deployed with Vault
- [ ] Secrets verified in pod
- [ ] Screenshots saved

### Task 4 - Documentation (2 pts)
- [x] SECRETS.md created
- [ ] All sections filled with evidence
- [ ] Screenshots added
- [ ] Security analysis included

### Bonus - Templates (2.5 pts)
- [x] Template annotation implemented
- [x] Custom format rendering
- [ ] Named templates added
- [ ] Documentation complete

---

## Common Commands

### Secrets

```bash
# Create secret
kubectl create secret generic <name> --from-literal=key=value

# View secret
kubectl get secret <name> -o yaml

# Decode
echo "<base64>" | base64 -d

# Delete secret
kubectl delete secret <name>
```

### Helm

```bash
# Install with secrets
helm install myapp devops-python-app \
  --set secrets.data.KEY=value

# Upgrade to Vault
helm upgrade myapp devops-python-app \
  --set vault.enabled=true \
  --set secrets.enabled=false

# Check values
helm get values myapp
```

### Vault

```bash
# Exec into Vault
kubectl exec -it vault-0 -- /bin/sh

# Create secret
vault kv put secret/path key=value

# Read secret
vault kv get secret/path

# List secrets
vault kv list secret/

# Check role
vault read auth/kubernetes/role/<role-name>
```

### Debugging

```bash
# Check pod
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Check Vault agent
kubectl logs <pod-name> -c vault-agent
kubectl logs <pod-name> -c vault-agent-init

# Check secrets file
kubectl exec <pod-name> -c <container> -- cat /vault/secrets/config

# Check environment
kubectl exec <pod-name> -- env
```

---

## Troubleshooting

### Secret not created

```bash
# Check Helm release
helm list
helm get manifest myapp | grep Secret

# Check if secrets.enabled=true
helm get values myapp
```

### Vault agent not injecting

```bash
# Check annotations
kubectl get pod <pod-name> -o yaml | grep vault

# Check service account
kubectl get sa devops-python-app

# Check Vault role
kubectl exec vault-0 -- vault read auth/kubernetes/role/devops-python-app

# Check Vault agent logs
kubectl logs <pod-name> -c vault-agent-init
```

### Secrets file not found

```bash
# Check mount path
kubectl exec <pod-name> -c devops-python-app -- ls -la /vault/secrets/

# Check Vault agent status
kubectl logs <pod-name> -c vault-agent | grep -i error
```

---

## Quick Test Script

```bash
#!/bin/bash
# Test all components

echo "=== Task 1: K8s Secrets ==="
kubectl get secret app-credentials && echo "✓ Secret exists" || echo "✗ Secret missing"

echo -e "\n=== Task 2: Helm Secrets ==="
kubectl get secret myapp-devops-python-app-secret && echo "✓ Helm secret exists" || echo "✗ Helm secret missing"

echo -e "\n=== Task 3: Vault ==="
kubectl get pod vault-0 && echo "✓ Vault running" || echo "✗ Vault not running"

POD=$(kubectl get pod -l app.kubernetes.io/name=devops-python-app -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD" ]; then
    echo "✓ App pod: $POD"
    kubectl get pod $POD -o jsonpath='{.spec.containers[*].name}' | grep -q vault-agent && echo "✓ Vault agent injected" || echo "✗ No Vault agent"
else
    echo "✗ App pod not found"
fi
```

---

## Next Steps

After completing Lab 11:
- **Lab 12:** ConfigMaps and persistent storage
- **Lab 13:** ArgoCD for GitOps
- **Lab 14:** Progressive delivery with Argo Rollouts

---

**Good luck!** 🔐

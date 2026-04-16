# Lab 11 - Secrets Management - Project Files

## Overview

Lab 11 extends the Helm chart from Lab 10 with comprehensive secret management using both Kubernetes native Secrets and HashiCorp Vault.

---

## File Structure

```
k8s/
├── devops-python-app/              # Helm chart (updated)
│   ├── templates/
│   │   ├── secrets.yaml            # NEW: Secret template
│   │   ├── serviceaccount.yaml     # NEW: Service account
│   │   ├── deployment.yaml         # UPDATED: Secret injection
│   │   └── ...
│   └── values.yaml                 # UPDATED: Secrets config
│
├── vault/                          # NEW: Vault configuration
│   ├── install-vault.sh            # Vault installation script
│   ├── vault-config.sh             # Vault configuration script
│   ├── policy.hcl                  # Vault policy definition
│   └── README.md                   # Vault documentation
│
├── SECRETS.md                      # NEW: Complete documentation
├── SECRETS-QUICKSTART.md           # NEW: Quick start guide
└── SECRETS-INDEX.md                # This file
```

---

## New Files for Lab 11

### Helm Chart Updates

#### 1. [`devops-python-app/templates/secrets.yaml`](devops-python-app/templates/secrets.yaml)
**Kubernetes Secret template**

Features:
- Conditional creation (`if .Values.secrets.enabled`)
- Dynamic key-value pairs from values
- Automatic base64 encoding with `stringData`
- Proper labels and naming

Usage:
```bash
helm install myapp devops-python-app \
  --set secrets.data.DB_PASSWORD=mypass
```

---

#### 2. [`devops-python-app/templates/serviceaccount.yaml`](devops-python-app/templates/serviceaccount.yaml)
**Service Account for Vault authentication**

Features:
- Conditional creation
- Supports annotations for Vault
- Used by Vault Kubernetes auth

---

#### 3. [`devops-python-app/values.yaml`](devops-python-app/values.yaml) (Updated)
**Added sections:**

```yaml
# Secrets configuration
secrets:
  enabled: true
  data:
    DB_USERNAME: "placeholder_user"
    DB_PASSWORD: "placeholder_pass"
    API_KEY: "placeholder_key"

# Service account (now enabled by default)
serviceAccount:
  create: true

# Vault integration
vault:
  enabled: false
  role: "devops-python-app"
  secretPath: "secret/data/devops-python-app/config"
  annotations: {...}
  template: |
    {{- with secret "..." -}}
    export DB_USERNAME="{{ .Data.data.username }}"
    ...
    {{- end -}}
```

---

#### 4. [`devops-python-app/templates/deployment.yaml`](devops-python-app/templates/deployment.yaml) (Updated)
**Changes:**

1. **Vault annotations** (conditional):
   ```yaml
   annotations:
     vault.hashicorp.com/agent-inject: "true"
     vault.hashicorp.com/role: "..."
   ```

2. **Secret injection**:
   ```yaml
   envFrom:
   - secretRef:
       name: {{ include "..." . }}-secret
   ```

---

### Vault Configuration

#### 5. [`vault/install-vault.sh`](vault/install-vault.sh)
**Vault installation script**

What it does:
- Adds HashiCorp Helm repository
- Installs Vault in dev mode
- Enables Vault Agent Injector
- Waits for Vault to be ready

Usage:
```bash
cd k8s/vault
./install-vault.sh
```

---

#### 6. [`vault/vault-config.sh`](vault/vault-config.sh)
**Vault configuration script**

What it does:
- Enables KV secrets engine (v2)
- Creates sample secrets
- Enables Kubernetes authentication
- Configures Kubernetes auth
- Creates policy
- Creates role

Usage:
```bash
cd k8s/vault
./vault-config.sh
```

---

#### 7. [`vault/policy.hcl`](vault/policy.hcl)
**Vault policy definition**

Grants read access to application secrets:
```hcl
path "secret/data/devops-python-app/*" {
  capabilities = ["read", "list"]
}
```

---

#### 8. [`vault/README.md`](vault/README.md)
**Vault setup documentation**

Sections:
- Quick start
- Manual configuration
- Vault annotations
- Troubleshooting
- Security notes

---

### Documentation

#### 9. [`SECRETS.md`](SECRETS.md)
**Complete Lab 11 documentation (20KB+)**

Sections:
1. Task 1: Kubernetes Secrets Fundamentals
2. Task 2: Helm-Managed Secrets
3. Resource Management
4. Task 3: HashiCorp Vault Integration
5. Security Analysis
6. Troubleshooting
7. Best Practices

---

#### 10. [`SECRETS-QUICKSTART.md`](SECRETS-QUICKSTART.md)
**Quick start guide**

Contents:
- Step-by-step instructions for all tasks
- Commands for each task
- Verification steps
- Checklist
- Common commands
- Troubleshooting

---

## Task Mapping

| Task | Files | Status |
|------|-------|--------|
| **Task 1** - K8s Secrets (2 pts) | SECRETS.md, SECRETS-QUICKSTART.md | ✅ Instructions |
| **Task 2** - Helm Secrets (3 pts) | templates/secrets.yaml, values.yaml, deployment.yaml | ✅ Implemented |
| **Task 3** - Vault Integration (3 pts) | vault/*, values.yaml (vault section) | ✅ Implemented |
| **Task 4** - Documentation (2 pts) | SECRETS.md | ✅ Complete |
| **Bonus** - Templates (2.5 pts) | values.yaml (vault.template) | ✅ Implemented |

**Total: 10 pts + 2.5 bonus = 12.5 pts**

---

## Quick Start

### Option 1: Kubernetes Secrets Only

```bash
cd k8s

# Install with K8s secrets
helm install myapp devops-python-app \
  --set secrets.data.DB_USERNAME=user \
  --set secrets.data.DB_PASSWORD=pass

# Verify
kubectl get secrets
kubectl exec <pod> -- env | grep DB_
```

### Option 2: With Vault

```bash
cd k8s/vault

# Install Vault
./install-vault.sh

# Configure Vault
./vault-config.sh

# Deploy app with Vault
cd ..
helm upgrade myapp devops-python-app \
  --set vault.enabled=true \
  --set secrets.enabled=false

# Verify
kubectl exec <pod> -c devops-python-app -- cat /vault/secrets/config
```

---

## Key Features

### 1. Dual Secret Management

**Kubernetes Secrets:**
- Simple, built-in
- Good for development
- Base64 encoded (not encrypted)

**HashiCorp Vault:**
- Enterprise-grade
- Encrypted at rest
- Automatic rotation
- Audit logging

### 2. Flexible Configuration

Switch between modes easily:

```bash
# Use K8s Secrets
helm install myapp devops-python-app \
  --set secrets.enabled=true \
  --set vault.enabled=false

# Use Vault
helm install myapp devops-python-app \
  --set secrets.enabled=false \
  --set vault.enabled=true
```

### 3. Sidecar Injection Pattern

Vault Agent automatically:
- Authenticates with Vault
- Fetches secrets
- Renders templates
- Keeps secrets updated

No code changes required!

### 4. Template Rendering

Custom secret format:

```yaml
vault:
  template: |
    {{- with secret "..." -}}
    export DB_USERNAME="{{ .Data.data.username }}"
    export DB_PASSWORD="{{ .Data.data.password }}"
    {{- end -}}
```

Renders to:
```bash
export DB_USERNAME="admin"
export DB_PASSWORD="supersecret123"
```

---

## Security Highlights

### Kubernetes Secrets

✅ Built-in, no extra components  
✅ RBAC integration  
⚠️ Base64 encoded (not encrypted)  
⚠️ Visible to anyone with API access  

**Recommendation:** Use for non-sensitive config or with etcd encryption

### HashiCorp Vault

✅ Encrypted at rest  
✅ Fine-grained access control  
✅ Audit logging  
✅ Secret rotation  
✅ Dynamic secrets  
⚠️ Additional complexity  
⚠️ Requires management  

**Recommendation:** Use for production and sensitive data

---

## Common Operations

### Create Secret

```bash
# Imperative
kubectl create secret generic app-creds \
  --from-literal=user=admin \
  --from-literal=pass=secret

# Via Helm
helm install myapp devops-python-app \
  --set secrets.data.USER=admin
```

### View Secret

```bash
# Get secret
kubectl get secret <name> -o yaml

# Decode
kubectl get secret <name> -o jsonpath='{.data.user}' | base64 -d
```

### Vault Operations

```bash
# Create secret
kubectl exec vault-0 -- vault kv put secret/app/config key=value

# Read secret
kubectl exec vault-0 -- vault kv get secret/app/config

# List secrets
kubectl exec vault-0 -- vault kv list secret/
```

---

## Troubleshooting

### Secrets not injected

1. Check secret exists: `kubectl get secrets`
2. Check deployment: `kubectl describe pod <pod>`
3. Check env vars: `kubectl exec <pod> -- env`

### Vault agent not working

1. Check annotations: `kubectl get pod <pod> -o yaml | grep vault`
2. Check service account: `kubectl get sa`
3. Check Vault logs: `kubectl logs <pod> -c vault-agent`
4. Check Vault role: `kubectl exec vault-0 -- vault read auth/kubernetes/role/<role>`

---

## Best Practices

1. ✅ Never commit secrets to Git
2. ✅ Use placeholder values in values.yaml
3. ✅ Override at deployment time
4. ✅ Use Vault for production
5. ✅ Enable etcd encryption
6. ✅ Rotate secrets regularly
7. ✅ Use least privilege access
8. ✅ Monitor secret access

---

## Next Steps

After Lab 11:
- **Lab 12:** ConfigMaps for non-sensitive configuration
- **Lab 13:** ArgoCD for GitOps deployments
- **Lab 14:** Progressive delivery with Argo Rollouts

---

**Lab 11 Complete!** 🔐

All files created, scripts ready, documentation complete.

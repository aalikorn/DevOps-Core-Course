# Secrets Management - Lab 11

## Overview

This document covers secret management implementation for the DevOps Python application using both Kubernetes native Secrets and HashiCorp Vault.

---

## Task 1: Kubernetes Secrets Fundamentals

### Creating Secrets

**Imperative approach (kubectl):**

```bash
# Create secret from literals
kubectl create secret generic app-credentials \
  --from-literal=username=admin \
  --from-literal=password=supersecret123

# Verify creation
kubectl get secrets
```

**Expected output:**
```
NAME               TYPE     DATA   AGE
app-credentials    Opaque   2      5s
```

### Viewing Secrets

```bash
# View secret in YAML format
kubectl get secret app-credentials -o yaml
```

**Output:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: default
type: Opaque
data:
  username: YWRtaW4=
  password: c3VwZXJzZWNyZXQxMjM=
```

### Decoding Secrets

```bash
# Decode username
echo "YWRtaW4=" | base64 -d
# Output: admin

# Decode password
echo "c3VwZXJzZWNyZXQxMjM=" | base64 -d
# Output: supersecret123
```

### Security Implications

**Base64 Encoding vs Encryption:**

- **Encoding:** Transforms data into different format (reversible)
- **Encryption:** Secures data with cryptographic keys (requires key to decrypt)

**Kubernetes Secrets are BASE64-ENCODED, NOT ENCRYPTED by default!**

**Security concerns:**
1. Anyone with API access can decode secrets
2. Secrets are stored in etcd (unencrypted by default)
3. Secrets appear in pod specs and can be logged

**Production recommendations:**
1. Enable etcd encryption at rest
2. Use RBAC to limit secret access
3. Use external secret managers (Vault, AWS Secrets Manager)
4. Never commit secrets to Git
5. Rotate secrets regularly

**Resources:**
- [Kubernetes Secrets Security](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- [Encrypting Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

---

## Task 2: Helm-Managed Secrets

### Chart Structure

The Helm chart now includes secret management:

```
devops-python-app/
├── templates/
│   ├── secrets.yaml          # Secret template (NEW)
│   ├── serviceaccount.yaml   # Service account (NEW)
│   ├── deployment.yaml        # Updated with secret injection
│   └── ...
└── values.yaml                # Updated with secret values
```

### Secret Template

**File:** `templates/secrets.yaml`

```yaml
{{- if .Values.secrets.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "devops-python-app.fullname" . }}-secret
  labels:
    {{- include "devops-python-app.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- range $key, $value := .Values.secrets.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
```

**Key features:**
- Conditional creation (`if .Values.secrets.enabled`)
- Templated name using helper function
- Standard labels for organization
- `stringData` for automatic base64 encoding
- Dynamic key-value pairs from values

### Values Configuration

**File:** `values.yaml`

```yaml
secrets:
  enabled: true
  data:
    # Placeholder values - override during deployment
    DB_USERNAME: "placeholder_user"
    DB_PASSWORD: "placeholder_pass"
    API_KEY: "placeholder_key"
```

**⚠️ Important:** These are placeholders! Override with real values:

```bash
# Using --set
helm install myapp devops-python-app \
  --set secrets.data.DB_USERNAME=realuser \
  --set secrets.data.DB_PASSWORD=realpass

# Using values file
helm install myapp devops-python-app -f secrets-values.yaml
```

### Secret Injection in Deployment

**Updated deployment template:**

```yaml
spec:
  containers:
  - name: devops-python-app
    env:
      # Regular environment variables
      {{- if .Values.env }}
      {{- toYaml .Values.env | nindent 10 }}
      {{- end }}
    {{- if and .Values.secrets.enabled (not .Values.vault.enabled) }}
    envFrom:
    - secretRef:
        name: {{ include "devops-python-app.fullname" . }}-secret
    {{- end }}
```

**How it works:**
- `envFrom` loads all keys from secret as environment variables
- Only used when secrets enabled and Vault disabled
- Automatic injection - no need to specify each key

### Verification

**Deploy with secrets:**

```bash
helm install myapp devops-python-app \
  --set secrets.data.DB_USERNAME=testuser \
  --set secrets.data.DB_PASSWORD=testpass123
```

**Verify secret created:**

```bash
kubectl get secrets
kubectl describe secret myapp-devops-python-app-secret
```

**Check environment variables in pod:**

```bash
# Get pod name
POD=$(kubectl get pod -l app.kubernetes.io/name=devops-python-app -o jsonpath='{.items[0].metadata.name}')

# Exec into pod
kubectl exec -it $POD -- env | grep DB_
```

**Expected output:**
```
DB_USERNAME=testuser
DB_PASSWORD=testpass123
```

**Security check - secrets not visible in describe:**

```bash
kubectl describe pod $POD | grep -A 10 "Environment"
```

**Output shows reference, not values:**
```
Environment Variables from:
  myapp-devops-python-app-secret  Secret  Optional: false
```

---

## Resource Management

### Configuration

**In values.yaml:**

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Requests vs Limits

**Requests:**
- Guaranteed resources
- Used for scheduling decisions
- Pod won't be scheduled if node can't provide requests

**Limits:**
- Maximum resources allowed
- Pod throttled (CPU) or killed (memory) if exceeded
- Prevents resource hogging

### Choosing Values

**Guidelines:**

1. **Start with monitoring:**
   - Deploy without limits
   - Monitor actual usage
   - Set requests = average usage
   - Set limits = peak usage + buffer

2. **CPU:**
   - 100m = 0.1 CPU core
   - 1000m = 1 CPU core
   - CPU is compressible (throttled, not killed)

3. **Memory:**
   - Mi = Mebibyte (1024-based)
   - Gi = Gibibyte
   - Memory is incompressible (OOM kill if exceeded)

**Example for Python FastAPI app:**

```yaml
resources:
  requests:
    cpu: "100m"      # Baseline for API
    memory: "128Mi"  # Python runtime + app
  limits:
    cpu: "200m"      # Allow burst for traffic spikes
    memory: "256Mi"  # Prevent memory leaks
```

### Verification

```bash
# Check resource allocation
kubectl describe pod $POD | grep -A 10 "Limits"

# Monitor actual usage (requires metrics-server)
kubectl top pod $POD
```

---

## Task 3: HashiCorp Vault Integration

### Installation

**Install Vault via Helm:**

```bash
# Add repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install in dev mode
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"
```

**Or use the provided script:**

```bash
cd vault
./install-vault.sh
```

**Verify installation:**

```bash
kubectl get pods -l app.kubernetes.io/name=vault
```

**Expected output:**
```
NAME                                   READY   STATUS    RESTARTS   AGE
vault-0                                1/1     Running   0          2m
vault-agent-injector-xxxxx-xxxxx       1/1     Running   0          2m
```

### Configuration

**Configure Vault using the script:**

```bash
cd vault
./vault-config.sh
```

**Or manually:**

```bash
# Exec into Vault pod
kubectl exec -it vault-0 -- /bin/sh

# Enable KV v2 engine
vault secrets enable -path=secret kv-v2

# Create secrets
vault kv put secret/devops-python-app/config \
    username="admin" \
    password="supersecret123" \
    api_key="sk-1234567890abcdef"

# Verify
vault kv get secret/devops-python-app/config
```

### Kubernetes Authentication

**Enable and configure:**

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure (run inside Vault pod)
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

### Policy and Role

**Create policy:**

```bash
vault policy write devops-python-app - <<EOF
path "secret/data/devops-python-app/*" {
  capabilities = ["read"]
}
EOF
```

**Create role:**

```bash
vault write auth/kubernetes/role/devops-python-app \
    bound_service_account_names=devops-python-app \
    bound_service_account_namespaces=default \
    policies=devops-python-app \
    ttl=24h
```

### Vault Agent Injection

**Deploy with Vault enabled:**

```bash
helm upgrade --install myapp devops-python-app \
  --set vault.enabled=true \
  --set secrets.enabled=false
```

**Vault annotations (automatically added by Helm):**

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "devops-python-app"
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/devops-python-app/config"
  vault.hashicorp.com/agent-inject-template-config: |
    {{- with secret "secret/data/devops-python-app/config" -}}
    export DB_USERNAME="{{ .Data.data.username }}"
    export DB_PASSWORD="{{ .Data.data.password }}"
    export API_KEY="{{ .Data.data.api_key }}"
    {{- end -}}
```

### Verification

**Check pod has Vault sidecar:**

```bash
kubectl get pod $POD -o jsonpath='{.spec.containers[*].name}'
```

**Expected output:**
```
vault-agent devops-python-app
```

**Check secrets file:**

```bash
kubectl exec $POD -c devops-python-app -- cat /vault/secrets/config
```

**Expected output:**
```
export DB_USERNAME="admin"
export DB_PASSWORD="supersecret123"
export API_KEY="sk-1234567890abcdef"
```

**Check Vault agent logs:**

```bash
kubectl logs $POD -c vault-agent
```

### Sidecar Injection Pattern

**How it works:**

1. **Mutating Webhook:** Vault Agent Injector intercepts pod creation
2. **Init Container:** `vault-agent-init` runs first, authenticates with Vault
3. **Sidecar Container:** `vault-agent` runs alongside app, keeps secrets updated
4. **Shared Volume:** Secrets written to `/vault/secrets/` (emptyDir volume)
5. **Application:** Reads secrets from files

**Benefits:**
- No code changes required
- Secrets never in environment variables
- Automatic secret rotation
- Centralized secret management

**Architecture:**

```
┌─────────────────────────────────────────┐
│              Pod                        │
│                                         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │ vault-agent  │    │     app      │  │
│  │  (sidecar)   │    │  container   │  │
│  └──────┬───────┘    └──────┬───────┘  │
│         │                   │          │
│         └────┬──────────────┘          │
│              │                         │
│         /vault/secrets/                │
│         (shared volume)                │
└─────────────────────────────────────────┘
         │
         ▼
    ┌─────────┐
    │  Vault  │
    │ Server  │
    └─────────┘
```

---

## Security Analysis

### Kubernetes Secrets vs Vault

| Feature | K8s Secrets | Vault |
|---------|-------------|-------|
| **Encryption** | Base64 (encoding only) | Encrypted at rest |
| **Access Control** | RBAC | Fine-grained policies |
| **Audit Logging** | Limited | Comprehensive |
| **Secret Rotation** | Manual | Automatic |
| **Dynamic Secrets** | No | Yes |
| **Centralized** | Per cluster | Cross-cluster |
| **Complexity** | Low | Medium-High |
| **Cost** | Free | Free (OSS) / Paid (Enterprise) |

### When to Use Each

**Use Kubernetes Secrets when:**
- Simple applications
- Secrets rarely change
- Single cluster
- Low security requirements
- Quick prototyping

**Use Vault when:**
- Production environments
- Compliance requirements (SOC2, PCI-DSS)
- Multiple clusters/environments
- Dynamic secrets needed
- Secret rotation required
- Audit trail important

### Production Recommendations

**For Kubernetes Secrets:**
1. Enable etcd encryption at rest
2. Use RBAC to limit access
3. Use sealed-secrets or external-secrets operator
4. Never commit to Git
5. Rotate regularly

**For Vault:**
1. Use HA mode with proper storage backend
2. Enable audit logging
3. Implement secret rotation policies
4. Use namespaces for multi-tenancy
5. Monitor Vault health
6. Backup Vault data
7. Use auto-unseal in production

**Hybrid Approach:**
- Use Vault for sensitive secrets (passwords, API keys)
- Use K8s Secrets for non-sensitive config
- Use ConfigMaps for public configuration

---

## Troubleshooting

### Secrets Not Injected

**Check secret exists:**
```bash
kubectl get secret myapp-devops-python-app-secret
kubectl describe secret myapp-devops-python-app-secret
```

**Check pod events:**
```bash
kubectl describe pod $POD
```

**Check environment variables:**
```bash
kubectl exec $POD -- env
```

### Vault Agent Issues

**Check annotations:**
```bash
kubectl get pod $POD -o yaml | grep vault.hashicorp.com
```

**Check Vault agent logs:**
```bash
kubectl logs $POD -c vault-agent
kubectl logs $POD -c vault-agent-init
```

**Common issues:**
- Service account doesn't exist
- Role not configured correctly
- Policy doesn't grant access
- Secret path incorrect

**Verify Vault configuration:**
```bash
kubectl exec vault-0 -- vault read auth/kubernetes/role/devops-python-app
kubectl exec vault-0 -- vault policy read devops-python-app
```

### Resource Limit Issues

**Pod OOMKilled:**
```bash
kubectl describe pod $POD | grep -A 5 "Last State"
```

**Solution:** Increase memory limits

**Pod CPU throttled:**
```bash
kubectl top pod $POD
```

**Solution:** Increase CPU limits or optimize application

---

## Best Practices

1. **Never commit secrets to Git**
   - Use `.gitignore` for secret files
   - Use placeholder values in values.yaml
   - Override at deployment time

2. **Use least privilege**
   - Grant minimum required permissions
   - Use separate service accounts per app
   - Limit secret access with RBAC

3. **Rotate secrets regularly**
   - Automate rotation where possible
   - Use short TTLs for dynamic secrets
   - Monitor for leaked secrets

4. **Audit secret access**
   - Enable audit logging
   - Monitor who accesses secrets
   - Alert on suspicious activity

5. **Encrypt in transit and at rest**
   - Use TLS for all communication
   - Enable etcd encryption
   - Use Vault for sensitive data

6. **Test secret injection**
   - Verify in non-prod first
   - Check application can read secrets
   - Test secret rotation

---

## Summary

This lab covered:

1. **Kubernetes Secrets:** Base64 encoding, security implications
2. **Helm Integration:** Template-based secret management
3. **Resource Management:** Requests and limits configuration
4. **Vault Integration:** Enterprise-grade secret management
5. **Sidecar Pattern:** Automatic secret injection
6. **Security Analysis:** When to use each approach

**Key takeaways:**
- K8s Secrets are encoded, not encrypted
- Vault provides enterprise-grade security
- Sidecar injection requires no code changes
- Resource limits prevent resource exhaustion
- Always use external secret managers in production

---

**Lab 11 Complete!** 🔐

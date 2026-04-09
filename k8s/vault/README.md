# Vault Configuration for Lab 11

This directory contains scripts and configuration files for HashiCorp Vault integration with Kubernetes.

## Files

- **`install-vault.sh`** - Installs Vault via Helm in dev mode
- **`vault-config.sh`** - Configures Vault for Kubernetes authentication
- **`policy.hcl`** - Vault policy definition
- **`README.md`** - This file

## Quick Start

### 1. Install Vault

```bash
./install-vault.sh
```

This will:
- Add HashiCorp Helm repository
- Install Vault in dev mode
- Enable Vault Agent Injector
- Wait for Vault to be ready

### 2. Configure Vault

```bash
./vault-config.sh
```

This will:
- Enable KV secrets engine (v2)
- Create sample secrets
- Enable Kubernetes authentication
- Create policy and role

### 3. Deploy Application with Vault

```bash
cd ..
helm upgrade --install myapp devops-python-app --set vault.enabled=true
```

### 4. Verify Secret Injection

```bash
# Get pod name
POD=$(kubectl get pod -l app.kubernetes.io/name=devops-python-app -o jsonpath='{.items[0].metadata.name}')

# Check secrets file
kubectl exec $POD -c devops-python-app -- cat /vault/secrets/config

# Check Vault agent logs
kubectl logs $POD -c vault-agent
```

## Manual Configuration

If you prefer to configure Vault manually:

### Access Vault Pod

```bash
kubectl exec -it vault-0 -- /bin/sh
```

### Enable KV Engine

```bash
vault secrets enable -path=secret kv-v2
```

### Create Secrets

```bash
vault kv put secret/devops-python-app/config \
    username="admin" \
    password="supersecret123" \
    api_key="sk-1234567890abcdef"
```

### Enable Kubernetes Auth

```bash
vault auth enable kubernetes

vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

### Create Policy

```bash
vault policy write devops-python-app - <<EOF
path "secret/data/devops-python-app/*" {
  capabilities = ["read"]
}
EOF
```

### Create Role

```bash
vault write auth/kubernetes/role/devops-python-app \
    bound_service_account_names=devops-python-app \
    bound_service_account_namespaces=default \
    policies=devops-python-app \
    ttl=24h
```

## Vault Annotations

The Helm chart uses these annotations for Vault injection:

```yaml
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

## Troubleshooting

### Vault pod not starting

```bash
kubectl describe pod vault-0
kubectl logs vault-0
```

### Secrets not injected

```bash
# Check pod annotations
kubectl describe pod <pod-name> | grep vault

# Check Vault agent logs
kubectl logs <pod-name> -c vault-agent

# Check Vault agent init logs
kubectl logs <pod-name> -c vault-agent-init
```

### Authentication issues

```bash
# Verify service account exists
kubectl get sa devops-python-app

# Verify role binding
kubectl exec vault-0 -- vault read auth/kubernetes/role/devops-python-app

# Test authentication
kubectl exec vault-0 -- vault write auth/kubernetes/login \
    role=devops-python-app \
    jwt=<service-account-token>
```

## Security Notes

**⚠️ Important:**
- Dev mode is for learning only
- Dev mode stores data in memory (not persistent)
- Dev mode uses a static root token
- For production, use Vault in HA mode with proper storage backend

## Resources

- [Vault Helm Chart](https://developer.hashicorp.com/vault/docs/platform/k8s/helm)
- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)

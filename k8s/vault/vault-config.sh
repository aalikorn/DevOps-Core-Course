#!/bin/bash
# Vault Configuration Script for Lab 11
# This script configures Vault for Kubernetes integration

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Vault Configuration for Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if Vault pod is running
echo -e "${YELLOW}Checking Vault pod status...${NC}"
if ! kubectl get pod vault-0 &> /dev/null; then
    echo -e "${RED}Error: Vault pod 'vault-0' not found${NC}"
    echo "Please install Vault first:"
    echo "  helm install vault hashicorp/vault --set 'server.dev.enabled=true'"
    exit 1
fi

echo -e "${GREEN}✓ Vault pod found${NC}\n"

# Wait for Vault to be ready
echo -e "${YELLOW}Waiting for Vault to be ready...${NC}"
kubectl wait --for=condition=ready pod/vault-0 --timeout=60s
echo -e "${GREEN}✓ Vault is ready${NC}\n"

# Enable KV secrets engine
echo -e "${YELLOW}Enabling KV secrets engine...${NC}"
kubectl exec vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"
echo -e "${GREEN}✓ KV secrets engine enabled${NC}\n"

# Create sample secrets
echo -e "${YELLOW}Creating sample secrets...${NC}"
kubectl exec vault-0 -- vault kv put secret/devops-python-app/config \
    username="admin" \
    password="supersecret123" \
    api_key="sk-1234567890abcdef"
echo -e "${GREEN}✓ Secrets created${NC}\n"

# Verify secrets
echo -e "${YELLOW}Verifying secrets...${NC}"
kubectl exec vault-0 -- vault kv get secret/devops-python-app/config
echo -e "${GREEN}✓ Secrets verified${NC}\n"

# Enable Kubernetes auth
echo -e "${YELLOW}Enabling Kubernetes authentication...${NC}"
kubectl exec vault-0 -- vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"
echo -e "${GREEN}✓ Kubernetes auth enabled${NC}\n"

# Configure Kubernetes auth
echo -e "${YELLOW}Configuring Kubernetes authentication...${NC}"
kubectl exec vault-0 -- sh -c '
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
'
echo -e "${GREEN}✓ Kubernetes auth configured${NC}\n"

# Create policy
echo -e "${YELLOW}Creating Vault policy...${NC}"
kubectl exec vault-0 -- sh -c 'cat <<EOF | vault policy write devops-python-app -
path "secret/data/devops-python-app/*" {
  capabilities = ["read"]
}
EOF'
echo -e "${GREEN}✓ Policy created${NC}\n"

# Create role
echo -e "${YELLOW}Creating Vault role...${NC}"
kubectl exec vault-0 -- vault write auth/kubernetes/role/devops-python-app \
    bound_service_account_names=devops-python-app \
    bound_service_account_namespaces=default \
    policies=devops-python-app \
    ttl=24h
echo -e "${GREEN}✓ Role created${NC}\n"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Vault configuration complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo "Next steps:"
echo "1. Deploy your application with Vault annotations:"
echo "   helm upgrade myapp devops-python-app --set vault.enabled=true"
echo ""
echo "2. Verify secret injection:"
echo "   kubectl exec -it <pod-name> -c devops-python-app -- cat /vault/secrets/config"
echo ""
echo "3. Check Vault agent sidecar:"
echo "   kubectl logs <pod-name> -c vault-agent"

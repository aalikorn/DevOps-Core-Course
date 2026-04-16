#!/bin/bash
# Vault Installation Script for Lab 11

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Installing HashiCorp Vault${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm not found. Please install Helm first.${NC}"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}kubectl not configured. Please configure kubectl first.${NC}"
    exit 1
fi

# Add HashiCorp Helm repository
echo -e "${YELLOW}Adding HashiCorp Helm repository...${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
echo -e "${GREEN}✓ Repository added${NC}\n"

# Install Vault in dev mode
echo -e "${YELLOW}Installing Vault in dev mode...${NC}"
echo -e "${YELLOW}Note: Dev mode is for learning only, NOT for production!${NC}\n"

helm install vault hashicorp/vault \
    --set "server.dev.enabled=true" \
    --set "injector.enabled=true" \
    --set "ui.enabled=true"

echo -e "${GREEN}✓ Vault installed${NC}\n"

# Wait for Vault to be ready
echo -e "${YELLOW}Waiting for Vault pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/vault-0 --timeout=120s

echo -e "${GREEN}✓ Vault is ready${NC}\n"

# Display status
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Vault installation complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo "Vault pods:"
kubectl get pods -l app.kubernetes.io/name=vault

echo -e "\nVault services:"
kubectl get svc -l app.kubernetes.io/name=vault

echo -e "\nNext steps:"
echo "1. Configure Vault:"
echo "   ./vault-config.sh"
echo ""
echo "2. Access Vault UI (if needed):"
echo "   kubectl port-forward vault-0 8200:8200"
echo "   Open http://localhost:8200"
echo ""
echo "3. Root token (dev mode only):"
echo "   kubectl exec vault-0 -- printenv VAULT_DEV_ROOT_TOKEN_ID"

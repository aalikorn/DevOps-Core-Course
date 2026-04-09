#!/bin/bash
# Kubernetes Lab 9 - Quick Setup Script
# This script helps you quickly set up and verify your Kubernetes deployment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if kubectl is installed
check_kubectl() {
    print_header "Checking Prerequisites"
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    print_success "kubectl is installed"
    kubectl version --client --short 2>/dev/null || kubectl version --client
}

# Check cluster connectivity
check_cluster() {
    print_header "Checking Kubernetes Cluster"
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        echo ""
        echo "Please start your cluster:"
        echo "  - minikube: minikube start"
        echo "  - kind: kind create cluster"
        echo "  - Docker Desktop: Enable Kubernetes in settings"
        exit 1
    fi
    
    print_success "Connected to Kubernetes cluster"
    kubectl cluster-info
    
    echo ""
    print_info "Cluster nodes:"
    kubectl get nodes
}

# Deploy application
deploy_app() {
    print_header "Deploying Application"
    
    print_info "Applying Kubernetes manifests..."
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    
    print_success "Manifests applied"
    
    echo ""
    print_info "Waiting for deployment to be ready..."
    kubectl rollout status deployment/devops-python-app --timeout=120s
    
    print_success "Deployment is ready!"
}

# Show deployment status
show_status() {
    print_header "Deployment Status"
    
    echo -e "${BLUE}Deployments:${NC}"
    kubectl get deployments
    
    echo ""
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -o wide
    
    echo ""
    echo -e "${BLUE}Services:${NC}"
    kubectl get services
    
    echo ""
    echo -e "${BLUE}All Resources:${NC}"
    kubectl get all
}

# Test application
test_app() {
    print_header "Testing Application"
    
    # Detect cluster type and provide appropriate access method
    if kubectl config current-context | grep -q "kind"; then
        print_info "Detected kind cluster"
        print_warning "kind requires port-forwarding for access"
        echo ""
        echo "Run this command in another terminal:"
        echo "  kubectl port-forward service/devops-python-service 8080:80"
        echo ""
        echo "Then access the app at:"
        echo "  http://localhost:8080/"
        echo "  http://localhost:8080/health"
        
    elif kubectl config current-context | grep -q "minikube"; then
        print_info "Detected minikube cluster"
        echo ""
        echo "Get service URL:"
        echo "  minikube service devops-python-service --url"
        echo ""
        echo "Or open in browser:"
        echo "  minikube service devops-python-service"
        
    else
        print_info "Detected Docker Desktop or other cluster"
        echo ""
        echo "Access the app via NodePort:"
        echo "  http://localhost:30080/"
        echo "  http://localhost:30080/health"
        echo ""
        print_info "Testing connection..."
        if command -v curl &> /dev/null; then
            sleep 2
            if curl -s http://localhost:30080/health > /dev/null; then
                print_success "Application is accessible!"
                echo ""
                echo "Response from /health:"
                curl -s http://localhost:30080/health | jq . 2>/dev/null || curl -s http://localhost:30080/health
            else
                print_warning "Cannot reach application yet. It may still be starting."
            fi
        fi
    fi
}

# Show useful commands
show_commands() {
    print_header "Useful Commands"
    
    cat << 'EOF'
# View logs from all pods
kubectl logs -l app=devops-python-app -f

# Scale to 5 replicas
kubectl scale deployment/devops-python-app --replicas=5

# Update to new image version
kubectl set image deployment/devops-python-app \
  devops-python-app=dashnik/devops-info-service:v2.0.0

# Check rollout status
kubectl rollout status deployment/devops-python-app

# Rollback to previous version
kubectl rollout undo deployment/devops-python-app

# Port forward (for kind/minikube)
kubectl port-forward service/devops-python-service 8080:80

# Delete all resources
kubectl delete -f .

# Watch pods
kubectl get pods -w

# Describe deployment
kubectl describe deployment devops-python-app

# Get pod details
kubectl describe pod <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/sh
EOF
}

# Main execution
main() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     Kubernetes Lab 9 - Quick Setup Script             ║
║     DevOps Info Service Deployment                   ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_kubectl
    check_cluster
    deploy_app
    show_status
    test_app
    show_commands
    
    print_header "Setup Complete! 🎉"
    print_success "Your application is deployed and running!"
    echo ""
    print_info "Check the README.md for detailed documentation"
}

# Run main function
main

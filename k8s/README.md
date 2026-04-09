# Kubernetes Deployment - Lab 9

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         Service: devops-python-service         │    │
│  │         Type: NodePort (30080)                 │    │
│  └──────────────┬─────────────────────────────────┘    │
│                 │                                        │
│                 │ Load Balances to:                     │
│                 │                                        │
│  ┌──────────────┼─────────────────────────────────┐    │
│  │              │  Deployment: devops-python-app  │    │
│  │              │  Replicas: 3                     │    │
│  │              │                                  │    │
│  │  ┌───────────▼──────┐  ┌──────────┐  ┌──────────┐  │
│  │  │   Pod 1          │  │  Pod 2   │  │  Pod 3   │  │
│  │  │ Container:       │  │Container:│  │Container:│  │
│  │  │ devops-python    │  │devops-   │  │devops-   │  │
│  │  │ Port: 5001       │  │python    │  │python    │  │
│  │  │ Resources:       │  │Port: 5001│  │Port: 5001│  │
│  │  │  CPU: 100m-200m  │  │          │  │          │  │
│  │  │  Mem: 128Mi-256Mi│  │          │  │          │  │
│  │  └──────────────────┘  └──────────┘  └──────────┘  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Manifest Files

### 1. deployment.yaml

**Purpose:** Defines the application deployment with 3 replicas, health checks, and resource limits.

**Key Configuration Choices:**

- **Replicas: 3** - Ensures high availability and load distribution
- **Rolling Update Strategy:**
  - `maxSurge: 1` - Allows one extra pod during updates
  - `maxUnavailable: 0` - Guarantees zero downtime during updates
- **Resource Requests:**
  - CPU: 100m (0.1 core) - Guaranteed CPU allocation
  - Memory: 128Mi - Guaranteed memory allocation
- **Resource Limits:**
  - CPU: 200m (0.2 core) - Maximum CPU usage
  - Memory: 256Mi - Maximum memory (prevents OOM issues)
- **Liveness Probe:**
  - Checks `/health` endpoint every 5 seconds
  - Restarts container if 3 consecutive failures
  - Initial delay: 10 seconds (allows app startup)
- **Readiness Probe:**
  - Checks `/health` endpoint every 3 seconds
  - Removes pod from service if not ready
  - Initial delay: 5 seconds
- **Security Context:**
  - Runs as non-root user (UID 1000)
  - No privilege escalation
  - Drops all capabilities

### 2. service.yaml

**Purpose:** Exposes the deployment via a stable network endpoint.

**Key Configuration:**

- **Type: NodePort** - Allows external access on port 30080
- **Selector:** `app: devops-python-app` - Targets all pods with this label
- **Port Mapping:**
  - Service port: 80 (internal cluster communication)
  - Target port: 5001 (container port)
  - Node port: 30080 (external access)

## Prerequisites

1. **Local Kubernetes cluster** (choose one):
   - minikube
   - kind
   - Docker Desktop with Kubernetes

2. **kubectl** installed and configured

3. **Docker image** available:
   - Built from Lab 2: `dashnik/devops-info-service:latest`
   - Or use your own image (update `deployment.yaml`)

## Deployment Instructions

### Step 1: Verify Cluster

```bash
# Check cluster is running
kubectl cluster-info

# Check nodes
kubectl get nodes

# Expected output: At least 1 node in Ready state
```

### Step 2: Deploy Application

```bash
# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Apply service
kubectl apply -f k8s/service.yaml

# Or apply all at once
kubectl apply -f k8s/
```

### Step 3: Verify Deployment

```bash
# Check deployment status
kubectl get deployments

# Check pods
kubectl get pods

# Check service
kubectl get services

# Get all resources
kubectl get all

# Expected output:
# - Deployment: 3/3 ready replicas
# - 3 pods in Running state
# - Service with NodePort 30080
```

### Step 4: Access Application

**For kind:**
```bash
# Port forward to access locally
kubectl port-forward service/devops-python-service 8080:80

# Access in browser or curl
curl http://localhost:8080/
curl http://localhost:8080/health
```

**For minikube:**
```bash
# Get service URL
minikube service devops-python-service --url

# Or open in browser
minikube service devops-python-service
```

**For Docker Desktop:**
```bash
# Access directly via NodePort
curl http://localhost:30080/
curl http://localhost:30080/health
```

## Scaling Operations

### Scale Up to 5 Replicas

```bash
# Method 1: Declarative (recommended)
# Edit deployment.yaml, change replicas: 5
kubectl apply -f k8s/deployment.yaml

# Method 2: Imperative (quick testing)
kubectl scale deployment/devops-python-app --replicas=5

# Watch scaling
kubectl get pods -w

# Verify
kubectl get deployment devops-python-app
```

### Scale Down to 2 Replicas

```bash
kubectl scale deployment/devops-python-app --replicas=2

# Verify
kubectl get pods
```

## Rolling Updates

### Update to New Version

```bash
# Method 1: Update image in deployment.yaml
# Change image tag: dashnik/devops-info-service:v2.0.0
kubectl apply -f k8s/deployment.yaml

# Method 2: Imperative update
kubectl set image deployment/devops-python-app \
  devops-python-app=dashnik/devops-info-service:v2.0.0

# Watch rollout
kubectl rollout status deployment/devops-python-app

# Check rollout history
kubectl rollout history deployment/devops-python-app
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/devops-python-app

# Rollback to specific revision
kubectl rollout undo deployment/devops-python-app --to-revision=1

# Check rollout status
kubectl rollout status deployment/devops-python-app
```

## Monitoring & Debugging

### Check Pod Logs

```bash
# Logs from specific pod
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# Logs from all pods with label
kubectl logs -l app=devops-python-app

# Previous container logs (if crashed)
kubectl logs <pod-name> --previous
```

### Describe Resources

```bash
# Detailed deployment info
kubectl describe deployment devops-python-app

# Detailed pod info
kubectl describe pod <pod-name>

# Service details
kubectl describe service devops-python-service

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Execute Commands in Pod

```bash
# Get shell in pod
kubectl exec -it <pod-name> -- /bin/sh

# Run single command
kubectl exec <pod-name> -- env
kubectl exec <pod-name> -- ps aux
```

### Check Resource Usage

```bash
# Pod resource usage (requires metrics-server)
kubectl top pods

# Node resource usage
kubectl top nodes
```

## Production Considerations

### 1. Health Checks Implementation

**Liveness Probe:**
- **Purpose:** Detects if container is alive
- **Action on failure:** Restarts container
- **Configuration:** HTTP GET to `/health` every 5 seconds
- **Why:** Automatically recovers from deadlocks or hung processes

**Readiness Probe:**
- **Purpose:** Detects if container is ready to serve traffic
- **Action on failure:** Removes from service endpoints
- **Configuration:** HTTP GET to `/health` every 3 seconds
- **Why:** Prevents routing traffic to pods that aren't ready

### 2. Resource Limits Rationale

**Requests (Guaranteed):**
- CPU: 100m - Sufficient for Python FastAPI app under normal load
- Memory: 128Mi - Baseline memory for application runtime

**Limits (Maximum):**
- CPU: 200m - Allows burst capacity for traffic spikes
- Memory: 256Mi - Prevents memory leaks from affecting cluster

**Why these values:**
- Based on Python FastAPI typical resource consumption
- Allows 3 pods to run comfortably on single-node cluster
- Provides headroom for traffic spikes
- Prevents resource starvation

### 3. Production Improvements

**For production deployment, consider:**

1. **Horizontal Pod Autoscaler (HPA):**
   ```bash
   kubectl autoscale deployment devops-python-app \
     --cpu-percent=70 --min=3 --max=10
   ```

2. **Pod Disruption Budget:**
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: devops-python-pdb
   spec:
     minAvailable: 2
     selector:
       matchLabels:
         app: devops-python-app
   ```

3. **Resource Quotas per Namespace:**
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: compute-quota
   spec:
     hard:
       requests.cpu: "4"
       requests.memory: 8Gi
       limits.cpu: "8"
       limits.memory: 16Gi
   ```

4. **Network Policies:**
   - Restrict pod-to-pod communication
   - Allow only necessary ingress/egress

5. **Secrets Management:**
   - Use Kubernetes Secrets for sensitive data
   - Consider external secret managers (Vault, AWS Secrets Manager)

6. **Monitoring:**
   - Prometheus for metrics collection
   - Grafana for visualization
   - Alert rules for critical conditions

7. **Logging:**
   - Centralized logging with Loki/ELK
   - Structured JSON logs
   - Log retention policies

8. **Service Mesh (Advanced):**
   - Istio or Linkerd for advanced traffic management
   - mTLS between services
   - Circuit breaking and retries

### 4. Monitoring & Observability Strategy

**Metrics to Monitor:**
- Pod restart count (should be 0)
- CPU/Memory usage vs limits
- Request latency (p50, p95, p99)
- Error rate
- Pod readiness/liveness probe success rate

**Alerting Rules:**
- Pod restart > 3 in 5 minutes
- CPU usage > 80% for 5 minutes
- Memory usage > 90%
- Error rate > 5%
- All pods down

**Logging Strategy:**
- Application logs to stdout/stderr
- Collected by cluster logging solution
- Structured JSON format
- Include request ID, user context
- Retention: 30 days

## Challenges & Solutions

### Challenge 1: Image Pull Errors

**Problem:** `ImagePullBackOff` or `ErrImagePull`

**Solutions:**
```bash
# Check pod events
kubectl describe pod <pod-name>

# Verify image exists
docker pull dashnik/devops-info-service:latest

# If using private registry, create secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>

# Add to deployment.yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

### Challenge 2: Pods Not Ready

**Problem:** Pods stuck in `ContainerCreating` or `CrashLoopBackOff`

**Solutions:**
```bash
# Check pod status
kubectl get pods

# Check events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common causes:
# - Health check failing (check /health endpoint)
# - Resource limits too low
# - Application crash on startup
# - Missing environment variables
```

### Challenge 3: Service Not Accessible

**Problem:** Cannot access application via service

**Solutions:**
```bash
# Verify service endpoints
kubectl get endpoints devops-python-service

# Should show 3 pod IPs (one per replica)
# If empty, check pod labels match service selector

# Test from within cluster
kubectl run test-pod --rm -it --image=busybox -- sh
wget -O- http://devops-python-service

# For NodePort, verify port is accessible
# kind: May need port mapping in cluster config
# minikube: Use `minikube service` command
```

### Challenge 4: Rolling Update Issues

**Problem:** Update causes downtime or fails

**Solutions:**
```bash
# Check rollout status
kubectl rollout status deployment/devops-python-app

# Pause rollout if issues
kubectl rollout pause deployment/devops-python-app

# Fix issues, then resume
kubectl rollout resume deployment/devops-python-app

# Rollback if needed
kubectl rollout undo deployment/devops-python-app

# Ensure readiness probes are configured
# Ensure maxUnavailable: 0 for zero downtime
```

## What I Learned About Kubernetes

1. **Declarative Configuration:**
   - Define desired state in YAML
   - Kubernetes reconciles actual state to match
   - Much better than imperative commands

2. **Self-Healing:**
   - Pods automatically restart on failure
   - Failed nodes trigger pod rescheduling
   - Health checks enable automatic recovery

3. **Scaling:**
   - Horizontal scaling is trivial (change replica count)
   - Load balancing is automatic via Service
   - Can scale to thousands of pods

4. **Zero-Downtime Updates:**
   - Rolling updates gradually replace pods
   - Readiness probes prevent traffic to unready pods
   - Rollback is instant if issues occur

5. **Resource Management:**
   - Requests ensure guaranteed resources
   - Limits prevent resource hogging
   - Scheduler places pods based on available resources

6. **Labels & Selectors:**
   - Powerful mechanism for grouping resources
   - Services find pods via label selectors
   - Enables flexible organization

## Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/

# Or delete individually
kubectl delete deployment devops-python-app
kubectl delete service devops-python-service

# Verify deletion
kubectl get all
```

## Quick Reference

```bash
# Apply manifests
kubectl apply -f k8s/

# Get all resources
kubectl get all

# Scale deployment
kubectl scale deployment/devops-python-app --replicas=5

# Update image
kubectl set image deployment/devops-python-app \
  devops-python-app=dashnik/devops-info-service:v2.0.0

# Rollback
kubectl rollout undo deployment/devops-python-app

# Port forward
kubectl port-forward service/devops-python-service 8080:80

# Logs
kubectl logs -l app=devops-python-app -f

# Delete all
kubectl delete -f k8s/
```

## Next Steps

- **Lab 10:** Package this deployment as a Helm chart
- **Lab 11:** Add secrets management with Vault
- **Lab 12:** Use ConfigMaps for configuration
- **Lab 13:** Deploy via ArgoCD (GitOps)
- **Lab 14:** Implement progressive delivery with Argo Rollouts

---

**Created for Lab 9 - Kubernetes Fundamentals**

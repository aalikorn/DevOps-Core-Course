# Lab 10 - Helm Package Manager

## Overview

This Helm chart packages the DevOps Python Info Service for deployment across multiple environments with configurable values.

**Chart Name:** devops-python-app  
**Chart Version:** 0.1.0  
**App Version:** 1.0.0

## Chart Structure

```
devops-python-app/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values-dev.yaml         # Development environment
├── values-prod.yaml        # Production environment
├── .helmignore            # Files to exclude
└── templates/
    ├── _helpers.tpl       # Template helpers
    ├── deployment.yaml    # Deployment template
    ├── service.yaml       # Service template
    ├── hpa.yaml          # HorizontalPodAutoscaler
    └── hooks/
        ├── pre-install-job.yaml   # Pre-install hook
        └── post-install-job.yaml  # Post-install hook
```

## Installation

### Prerequisites

- Kubernetes cluster running
- Helm 4.x installed
- kubectl configured

### Install Chart

```bash
# Install with default values
helm install devops-app k8s/devops-python-app

# Install with custom values
helm install devops-app k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml

# Install with inline overrides
helm install devops-app k8s/devops-python-app \
  --set replicaCount=5 \
  --set image.tag=v2.0.0
```

### Verify Installation

```bash
# List releases
helm list

# Get release status
helm status devops-app

# Get deployed manifests
helm get manifest devops-app

# Get values
helm get values devops-app
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of pod replicas | `3` |
| `image.repository` | Container image repository | `dashnik/devops-info-service` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `NodePort` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `5001` |
| `service.nodePort` | NodePort for external access | `30080` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas for HPA | `3` |
| `autoscaling.maxReplicas` | Maximum replicas for HPA | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU for scaling | `70` |

### Environment-Specific Values

**Development (values-dev.yaml):**
- 2 replicas
- Lower resource limits
- Debug mode enabled
- NodePort service

**Production (values-prod.yaml):**
- 5 replicas
- Higher resource limits
- Debug mode disabled
- LoadBalancer service (if available)
- HPA enabled

## Template Features

### 1. Helpers (_helpers.tpl)

Reusable template functions:

```yaml
{{- define "devops-python-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "devops-python-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "devops-python-app.labels" -}}
helm.sh/chart: {{ include "devops-python-app.chart" . }}
{{ include "devops-python-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

### 2. Deployment Template

Key features:
- Configurable replicas via values
- Rolling update strategy
- Resource requests and limits
- Health probes (liveness and readiness)
- Security context
- Environment variables

### 3. Service Template

Features:
- Configurable service type (NodePort, LoadBalancer, ClusterIP)
- Port mapping from values
- Label selectors

### 4. HorizontalPodAutoscaler

Conditional rendering based on `autoscaling.enabled`:
- CPU-based scaling
- Memory-based scaling
- Configurable min/max replicas

### 5. Helm Hooks

**Pre-install Hook:**
- Runs before chart installation
- Validates prerequisites
- Can check cluster resources

**Post-install Hook:**
- Runs after successful installation
- Can perform health checks
- Can send notifications

## Usage Examples

### Deploy to Development

```bash
helm install devops-dev k8s/devops-python-app \
  --values k8s/devops-python-app/values-dev.yaml \
  --namespace dev \
  --create-namespace
```

### Deploy to Production

```bash
helm install devops-prod k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml \
  --namespace prod \
  --create-namespace
```

### Upgrade Release

```bash
# Upgrade with new values
helm upgrade devops-app k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml

# Upgrade with new image tag
helm upgrade devops-app k8s/devops-python-app \
  --set image.tag=v2.0.0 \
  --reuse-values
```

### Rollback Release

```bash
# Rollback to previous version
helm rollback devops-app

# Rollback to specific revision
helm rollback devops-app 2

# Check rollback status
helm status devops-app
```

### Uninstall Release

```bash
# Uninstall release
helm uninstall devops-app

# Uninstall and keep history
helm uninstall devops-app --keep-history
```

## Testing

### Dry Run

```bash
# Test template rendering without installing
helm install devops-app k8s/devops-python-app \
  --dry-run --debug

# Test with specific values
helm install devops-app k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml \
  --dry-run --debug
```

### Template Validation

```bash
# Render templates locally
helm template devops-app k8s/devops-python-app

# Render with values
helm template devops-app k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml

# Validate against Kubernetes API
helm template devops-app k8s/devops-python-app | kubectl apply --dry-run=client -f -
```

### Lint Chart

```bash
# Lint chart for issues
helm lint k8s/devops-python-app

# Lint with values
helm lint k8s/devops-python-app \
  --values k8s/devops-python-app/values-prod.yaml
```

## Advanced Features

### 1. Multiple Environments

Deploy same chart to different environments:

```bash
# Development
helm install devops-dev k8s/devops-python-app \
  -f k8s/devops-python-app/values-dev.yaml \
  -n dev --create-namespace

# Staging
helm install devops-staging k8s/devops-python-app \
  -f k8s/devops-python-app/values-staging.yaml \
  -n staging --create-namespace

# Production
helm install devops-prod k8s/devops-python-app \
  -f k8s/devops-python-app/values-prod.yaml \
  -n prod --create-namespace
```

### 2. Value Overrides

Multiple ways to override values:

```bash
# Via file
helm install devops-app k8s/devops-python-app -f custom-values.yaml

# Via command line
helm install devops-app k8s/devops-python-app \
  --set replicaCount=5 \
  --set image.tag=v2.0.0

# Multiple files (later files override earlier)
helm install devops-app k8s/devops-python-app \
  -f values.yaml \
  -f values-prod.yaml \
  -f values-override.yaml
```

### 3. Conditional Resources

Enable/disable resources via values:

```yaml
# Enable HPA
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

# Enable Ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
```

### 4. Hooks for Lifecycle Management

Hooks execute at specific points:

- `pre-install`: Before resources are installed
- `post-install`: After all resources are installed
- `pre-upgrade`: Before upgrade
- `post-upgrade`: After upgrade
- `pre-delete`: Before deletion
- `post-delete`: After deletion
- `pre-rollback`: Before rollback
- `post-rollback`: After rollback

## Best Practices

### 1. Values Organization

- Use `values.yaml` for defaults
- Create environment-specific files (`values-dev.yaml`, `values-prod.yaml`)
- Document all values with comments
- Use meaningful defaults

### 2. Template Design

- Use helpers for repeated logic
- Keep templates DRY (Don't Repeat Yourself)
- Use `if/else` for conditional resources
- Validate required values with `required` function

### 3. Version Management

- Increment chart version on changes
- Use semantic versioning
- Tag releases in git
- Document changes in Chart.yaml annotations

### 4. Security

- Don't store secrets in values files
- Use Kubernetes Secrets or external secret managers
- Set appropriate security contexts
- Use least privilege principles

### 5. Resource Management

- Always set resource requests and limits
- Use HPA for production workloads
- Set appropriate probe timeouts
- Use PodDisruptionBudgets for critical apps

## Troubleshooting

### Issue: Helm Install Fails

```bash
# Check chart syntax
helm lint k8s/devops-python-app

# Dry run to see what would be created
helm install devops-app k8s/devops-python-app --dry-run --debug

# Check rendered templates
helm template devops-app k8s/devops-python-app
```

### Issue: Values Not Applied

```bash
# Verify values are correct
helm get values devops-app

# Check what was actually deployed
helm get manifest devops-app

# Upgrade with correct values
helm upgrade devops-app k8s/devops-python-app -f correct-values.yaml
```

### Issue: Upgrade Fails

```bash
# Check upgrade status
helm status devops-app

# View history
helm history devops-app

# Rollback if needed
helm rollback devops-app

# Force upgrade (use with caution)
helm upgrade devops-app k8s/devops-python-app --force
```

## Comparison: Raw Manifests vs Helm

| Aspect | Raw Manifests (Lab 9) | Helm Chart (Lab 10) |
|--------|----------------------|---------------------|
| **Reusability** | Copy/paste and edit | Single chart, multiple deployments |
| **Configuration** | Hardcoded values | Parameterized via values |
| **Environments** | Separate manifest files | Same chart, different values files |
| **Versioning** | Manual git tags | Built-in chart versioning |
| **Rollback** | Manual kubectl apply | `helm rollback` command |
| **Dependencies** | Manual management | Automatic via Chart.yaml |
| **Lifecycle** | No hooks | Pre/post install/upgrade hooks |
| **Templating** | None | Go templates with helpers |
| **Package** | Directory of YAML | Packaged .tgz file |
| **Distribution** | Git repository | Helm repository or OCI registry |

## Key Learnings

1. **Templating Power:** Helm templates allow single chart to deploy across environments
2. **Values Hierarchy:** Multiple value files can be layered for flexibility
3. **Lifecycle Hooks:** Execute actions at specific deployment stages
4. **Version Control:** Built-in versioning and rollback capabilities
5. **Standardization:** Industry-standard packaging for Kubernetes apps
6. **Reusability:** Charts can be shared and reused across projects
7. **Complexity Trade-off:** More powerful but adds learning curve

## Next Steps

- **Lab 11:** Add ConfigMaps and Secrets management
- **Lab 12:** Implement StatefulSets for stateful workloads
- **Lab 13:** Deploy via ArgoCD (GitOps)
- **Lab 14:** Progressive delivery with Argo Rollouts

---

**Created for Lab 10 - Helm Package Manager**

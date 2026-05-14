# Argo Rollouts — Progressive Delivery

> **Lab 14** | Progressive delivery with canary and blue-green strategies using Argo Rollouts 1.7+.

---

## Table of Contents

1. [Argo Rollouts Setup](#1-argo-rollouts-setup)
2. [Rollout vs Deployment](#2-rollout-vs-deployment)
3. [Canary Deployment](#3-canary-deployment)
4. [Blue-Green Deployment](#4-blue-green-deployment)
5. [Bonus: Automated Analysis](#5-bonus-automated-analysis)
6. [Strategy Comparison](#6-strategy-comparison)
7. [CLI Commands Reference](#7-cli-commands-reference)

---

## 1. Argo Rollouts Setup

### 1.1 Install the Controller

```bash
# Create namespace
kubectl create namespace argo-rollouts

# Install controller (latest stable)
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Verify controller pod is running
kubectl get pods -n argo-rollouts
# NAME                             READY   STATUS    RESTARTS   AGE
# argo-rollouts-7f8b9c6b9f-xxxxx   1/1     Running   0          30s
```

### 1.2 Install kubectl Plugin

```bash
# macOS (Homebrew)
brew install argoproj/tap/kubectl-argo-rollouts

# Linux
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
# kubectl-argo-rollouts: v1.7.x
```

### 1.3 Install and Access the Dashboard

```bash
# Install dashboard
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml

# Verify dashboard pod
kubectl get pods -n argo-rollouts
# NAME                                        READY   STATUS    RESTARTS   AGE
# argo-rollouts-dashboard-xxxxxxxxx-xxxxx     1/1     Running   0          15s

# Access dashboard via port-forward
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
# Open: http://localhost:3100
```

The dashboard provides a visual overview of all Rollout resources, showing current steps, weights, and health status in real-time.

---

## 2. Rollout vs Deployment

### Key Differences

| Feature | `kind: Deployment` | `kind: Rollout` |
|---|---|---|
| **API Version** | `apps/v1` | `argoproj.io/v1alpha1` |
| **Strategy** | `RollingUpdate` / `Recreate` | `canary` / `blueGreen` |
| **Traffic control** | ❌ Not supported | ✅ Percentage-based weights |
| **Manual promotion** | ❌ Not supported | ✅ `kubectl argo rollouts promote` |
| **Automated analysis** | ❌ Not supported | ✅ AnalysisTemplate integration |
| **Preview environment** | ❌ Not supported | ✅ Preview service (blue-green) |
| **Instant rollback** | ⚠️ Slow (rolling back gradually) | ✅ Instant traffic switch |
| **Dashboard UI** | ❌ No dedicated UI | ✅ Argo Rollouts dashboard |

### Pod Template

The `spec.template` section is **identical** to a Deployment — the same containers, volumes, probes, and security contexts. Only the `spec.strategy` section changes.

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
spec:
  strategy:
    type: RollingUpdate          # ← limited control

# Rollout
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:                      # ← full progressive delivery control
      steps: [...]
```

---

## 3. Canary Deployment

### 3.1 Strategy Configuration

The canary rollout in `templates/rollout.yaml` implements a 5-step progressive traffic shift. It is **activated** by setting `rollout.enabled: true` and `rollout.strategy: "canary"` in values, which simultaneously disables the plain Deployment.

```yaml
# templates/rollout.yaml (key section)
strategy:
  canary:
    steps:
      - setWeight: 20
      - pause: {}          # ← Manual promotion required (gate)
      - setWeight: 40
      - pause:
          duration: 30s    # ← Automatic after 30 seconds
      - setWeight: 60
      - pause:
          duration: 30s
      - setWeight: 80
      - pause:
          duration: 30s
      # Implicit 100% at the end
```

**Why this configuration:**
- The first `pause: {}` (no duration) is a **manual gate** — a human must verify 20% canary traffic is healthy before proceeding.
- Subsequent pauses are timed, allowing automated progression once the critical first gate is passed.

### 3.2 Deploy Canary Rollout

```bash
# Install/upgrade with canary values
helm upgrade --install devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --namespace default

# Confirm Rollout is created (not Deployment)
kubectl get rollouts
# NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE
# devops-python-app    3         3         3            3

# Watch live status
kubectl argo rollouts get rollout devops-python-app -w
```

### 3.3 Trigger a Rollout (Update)

```bash
# Update the image tag to trigger a new rollout
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --set image.tag=v2

# Or update an env variable to simulate a config change
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --set env[0].value="new-value"
```

Expected `kubectl argo rollouts get rollout devops-python-app -w` output after trigger:

```
Name:            devops-python-app
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/8
  SetWeight:     20
  ActualWeight:  20

Canary Pods:
NAME                                      READY   STATUS    RESTARTS
devops-python-app-xxxxxxxxx-canary-1      1/1     Running   0

Stable Pods:
NAME                                      READY   STATUS    RESTARTS
devops-python-app-yyyyyyyyy-stable-1      1/1     Running   0
devops-python-app-yyyyyyyyy-stable-2      1/1     Running   0
```

At this point **20% of traffic** goes to the new (canary) version, **80%** remains on stable.

### 3.4 Manual Promotion

After verifying the canary at 20% is healthy:

```bash
# Promote: move to next step (40%)
kubectl argo rollouts promote devops-python-app

# The rollout then automatically proceeds:
#  40% → waits 30s → 60% → waits 30s → 80% → waits 30s → 100%
```

### 3.5 Testing Rollback

```bash
# During rollout (e.g. at 40%), abort it
kubectl argo rollouts abort devops-python-app

# Traffic IMMEDIATELY returns 100% to the stable version.
# Status shows: Degraded / Aborted

# To retry the rollout with the same version:
kubectl argo rollouts retry rollout devops-python-app
```

**Result:** Rollback is near-instant because Argo Rollouts only adjusts traffic weights — existing stable pods are never terminated during an abort.

---

## 4. Blue-Green Deployment

### 4.1 Strategy Configuration

Blue-green uses **two services**: `active` (production) and `preview` (new version). During a rollout the new pods come up alongside the old ones; traffic only switches at promotion.

```yaml
# templates/rollout-bluegreen.yaml (key section)
strategy:
  blueGreen:
    activeService:  devops-python-app          # Production traffic (blue)
    previewService: devops-python-app-preview  # Test traffic (green)
    autoPromotionEnabled: false                # Manual promotion
    scaleDownDelaySeconds: 30                  # Keep old pods 30s after promotion
```

### 4.2 Deploy Blue-Green Rollout

```bash
# Switch to blue-green strategy
helm upgrade --install devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-bluegreen.yaml \
  --namespace default

# Verify both services exist
kubectl get svc
# NAME                          TYPE       CLUSTER-IP   PORT(S)
# devops-python-app             NodePort   10.x.x.x     80:30080/TCP   ← active (blue)
# devops-python-app-preview     NodePort   10.x.x.x     80:30081/TCP   ← preview (green)
```

### 4.3 Blue-Green Flow

**Step 1 — Initial (Blue) deployment:**

```bash
# Initial install runs with v1 image (blue)
# All traffic goes through active service → blue pods
kubectl argo rollouts get rollout devops-python-app
# Status: Healthy  |  Active: v1  |  Preview: -
```

**Step 2 — Trigger update (Green comes up):**

```bash
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-bluegreen.yaml \
  --set image.tag=v2

# Status: Paused  |  Active: v1 (blue)  |  Preview: v2 (green)
```

**Step 3 — Test the preview (green) version:**

```bash
# Access production (blue, unchanged)
kubectl port-forward svc/devops-python-app 8080:80
curl http://localhost:8080/        # → v1 response

# Access preview (green, new version)
kubectl port-forward svc/devops-python-app-preview 8081:80
curl http://localhost:8081/        # → v2 response
```

**Step 4 — Promote green → active:**

```bash
# After verifying preview is healthy, promote:
kubectl argo rollouts promote devops-python-app

# Traffic INSTANTLY switches: active now → v2 pods
# Old v1 pods kept alive for scaleDownDelaySeconds (30s), then removed
```

**Step 5 — Instant rollback:**

```bash
# If an issue is found after promotion:
kubectl argo rollouts undo devops-python-app

# Traffic INSTANTLY returns to v1 (kept in the old ReplicaSet).
# This is faster than canary rollback because:
#   - No gradual weight reduction needed
#   - Old ReplicaSet is still running (within scaleDownDelaySeconds)
```

**Speed comparison:**
- Blue-Green rollback: **< 1 second** (pointer swap on service selector)
- Canary rollback (`abort`): **1–5 seconds** (weight redistribution)

---

## 5. Bonus: Automated Analysis

### 5.1 AnalysisTemplate

The `templates/analysis-template.yaml` runs health checks against the app's `/health` endpoint during a canary rollout. If more than 1 check out of 3 fails, the rollout is **automatically aborted**.

```yaml
# templates/analysis-template.yaml (key section)
spec:
  metrics:
    - name: health-check
      interval: 10s      # Check every 10 seconds
      count: 3           # Run 3 times total
      failureLimit: 1    # Allow at most 1 failure before rollback
      provider:
        web:
          url: "http://devops-python-app.default.svc/health"
          jsonPath: "{$.status}"
      successCondition: result == "ok"
```

### 5.2 Enable Analysis

```bash
# Deploy canary with analysis enabled
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --set rollout.analysisEnabled=true \
  --set image.tag=v2

# The analysis starts at step 1 (after 20% weight is set)
# Watch the AnalysisRun
kubectl get analysisrun
kubectl describe analysisrun <name>
```

### 5.3 Testing Auto-Rollback

To simulate a failure (e.g. deploy a broken image that returns `status: "error"`):

```bash
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --set rollout.analysisEnabled=true \
  --set image.tag=broken-v3

# After 2 failed health checks, the AnalysisRun transitions to "Failed"
# Argo Rollouts automatically aborts → traffic returns 100% to stable
kubectl argo rollouts get rollout devops-python-app
# Status: Degraded | Message: RolloutAborted: metric "health-check" assessed Failed
```

### 5.4 Prometheus-based Analysis (Optional — requires Lab 16)

```yaml
# Enable in values.yaml under rollout.analysis.prometheus:
rollout:
  analysis:
    prometheus:
      enabled: true
      address: "http://prometheus.monitoring:9090"
```

This adds a second metric checking that the HTTP 5xx error rate stays below 5% during the canary phase.

---

## 6. Strategy Comparison

### When to Use Each Strategy

| Scenario | Canary | Blue-Green |
|---|:---:|:---:|
| Gradual user exposure (risk minimization) | ✅ Best | — |
| A/B testing with real traffic | ✅ | — |
| Need to test full new version before any live traffic | — | ✅ Best |
| Instant rollback requirement | ⚠️ Fast | ✅ Instant |
| Limited resources (can't double pods) | ✅ | ⚠️ Needs 2x |
| Database schema migrations (all-or-nothing) | ⚠️ Risky | ✅ Safer |
| Long-running request safety (drain gracefully) | ✅ | ⚠️ Harder |
| Simple microservice stateless update | ✅ | ✅ |

### Pros and Cons

#### Canary
| Pros | Cons |
|---|---|
| Real traffic validation at small scale | Mixed versions in production simultaneously |
| Gradual risk exposure | Harder to debug (split traffic) |
| Shared resource pool (no 2x overhead) | State/session issues if versions incompatible |
| Automated rollback via metrics | Slower full rollout |

#### Blue-Green
| Pros | Cons |
|---|---|
| Instant, clean traffic switch | Requires 2x pod resources during switch |
| Full preview environment for testing | No gradual rollout — all-or-nothing |
| Clean separation of versions | Higher infrastructure cost |
| Safest for DB migrations with compatibility layer | Old version scaled down after scaleDownDelay |

### Recommendation

- **Use Canary** for typical stateless service updates where gradual exposure and real-traffic validation are more important than clean version isolation.
- **Use Blue-Green** for critical infrastructure changes, major version upgrades, or any scenario requiring a full staging environment that mirrors production before switching.
- **Combine both with AnalysisTemplates** to make promotion/rollback fully automated and metrics-driven.

---

## 7. CLI Commands Reference

### Installation & Setup

```bash
# Install controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install dashboard
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml

# Access dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

# Verify plugin
kubectl argo rollouts version
```

### Monitoring Rollouts

```bash
# List all rollouts
kubectl get rollouts -A

# Watch a rollout live (streams updates)
kubectl argo rollouts get rollout devops-python-app -w

# Describe a rollout (full spec + events)
kubectl describe rollout devops-python-app

# View rollout history
kubectl argo rollouts history rollout devops-python-app
```

### Canary Controls

```bash
# Promote to next step manually
kubectl argo rollouts promote devops-python-app

# Promote directly to 100% (skip remaining steps)
kubectl argo rollouts promote devops-python-app --full

# Abort rollout → traffic returns to stable
kubectl argo rollouts abort devops-python-app

# Retry after abort
kubectl argo rollouts retry rollout devops-python-app

# Set weight manually (for debugging)
kubectl argo rollouts set image devops-python-app \
  devops-python-app=dashnik/devops-info-service:v2
```

### Blue-Green Controls

```bash
# Promote preview → active
kubectl argo rollouts promote devops-python-app

# Rollback to previous version
kubectl argo rollouts undo devops-python-app

# Access active (production)
kubectl port-forward svc/devops-python-app 8080:80

# Access preview (new version)
kubectl port-forward svc/devops-python-app-preview 8081:80
```

### Analysis

```bash
# List AnalysisTemplates
kubectl get analysistemplates

# List active AnalysisRuns
kubectl get analysisruns

# Describe an AnalysisRun (see metric results)
kubectl describe analysisrun <analysisrun-name>
```

### Helm Integration

```bash
# Deploy with canary strategy
helm upgrade --install devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml

# Deploy with blue-green strategy
helm upgrade --install devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-bluegreen.yaml

# Deploy with analysis enabled
helm upgrade --install devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  -f k8s/devops-python-app/values-canary.yaml \
  --set rollout.analysisEnabled=true

# Revert to plain Deployment (disable rollouts)
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values.yaml \
  --set rollout.enabled=false
```

---

## Resources

- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Canary Strategy](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Blue-Green Strategy](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [Analysis & Progressive Delivery](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [Rollout Specification](https://argoproj.github.io/argo-rollouts/features/specification/)

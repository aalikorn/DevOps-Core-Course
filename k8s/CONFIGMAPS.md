# ConfigMaps & Persistent Volumes

## Table of Contents

- [Application Changes](#application-changes)
- [ConfigMap Implementation](#configmap-implementation)
- [Persistent Volume](#persistent-volume)
- [ConfigMap vs Secret](#configmap-vs-secret)
- [Bonus: ConfigMap Hot Reload](#bonus-configmap-hot-reload)

---

## Application Changes

### Visits Counter Implementation

The application (`app_python/app.py`) was extended with a **file-based visits counter** that tracks how many times the root endpoint (`/`) has been accessed.

**Key changes:**

| Change | Description |
|--------|-------------|
| `_read_visits()` | Reads the current count from the persistent file (defaults to `0` if the file does not exist) |
| `_write_visits()` | Atomically writes the count using a temporary file + rename pattern |
| `_visits_lock` | A `threading.Lock` that serialises concurrent access to the counter file |
| `VISITS_FILE` env var | Configurable path to the counter file (default `/data/visits`) |

On every `GET /` request the counter is incremented and the new value is included in the JSON response under the `visits` key.

### New Endpoint — `/visits`

```
GET /visits
```

Returns the current visit count **without** incrementing it:

```json
{ "visits": 42 }
```

### Local Testing with Docker

A `docker-compose.yml` was added to `app_python/`:

```yaml
services:
  app_python:
    build: .
    ports:
      - "5001:5001"
    environment:
      - VISITS_FILE=/data/visits
    volumes:
      - ./data:/data
```

**Testing steps:**

```bash
cd app_python
docker compose up -d

# Hit root several times
curl http://localhost:5001/
curl http://localhost:5001/
curl http://localhost:5001/

# Check counter
curl http://localhost:5001/visits
# → {"visits": 3}

# Verify file on host
cat ./data/visits
# → 3

# Restart container
docker compose restart

# Counter survives restart
curl http://localhost:5001/visits
# → {"visits": 3}
```

---

## ConfigMap Implementation

Two ConfigMaps are created by the Helm chart.

### 1. File-based ConfigMap (`*-config`)

**Template:** `templates/configmap.yaml` (first document)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <release>-devops-python-app-config
data:
  config.json: |-
    {
      "app_name": "devops-info-service",
      "environment": "production",
      "version": "1.0.0",
      "features": {
        "visits_counter": true,
        "prometheus_metrics": true,
        "health_check": true
      },
      "logging": {
        "level": "INFO",
        "format": "json"
      }
    }
```

The content is loaded from `files/config.json` using Helm's `.Files.Get` function.

**Volume mount in the Deployment:**

```yaml
volumes:
  - name: config-volume
    configMap:
      name: <release>-devops-python-app-config
containers:
  - volumeMounts:
      - name: config-volume
        mountPath: /config
        readOnly: true
```

The file is accessible inside the pod at `/config/config.json`.

**Verification:**

```bash
kubectl exec <pod> -- cat /config/config.json
```

### 2. Environment-variable ConfigMap (`*-env`)

**Template:** `templates/configmap.yaml` (second document)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <release>-devops-python-app-env
data:
  APP_NAME: "devops-info-service"
  APP_ENV: "production"
  LOG_LEVEL: "INFO"
```

Values are sourced from `values.yaml` → `config.*` keys.

**Injection via `envFrom`:**

```yaml
envFrom:
  - configMapRef:
      name: <release>-devops-python-app-env
```

**Verification:**

```bash
kubectl exec <pod> -- printenv | grep -E 'APP_|LOG_'
# APP_NAME=devops-info-service
# APP_ENV=production
# LOG_LEVEL=INFO
```

### Listing ConfigMaps

```bash
kubectl get configmap,pvc
# NAME                                          DATA   AGE
# configmap/<release>-devops-python-app-config   1      5m
# configmap/<release>-devops-python-app-env      3      5m
#
# NAME                                                STATUS   VOLUME   CAPACITY   ACCESS MODES   AGE
# persistentvolumeclaim/<release>-devops-python-app-data   Bound    ...      100Mi      RWO            5m
```

---

## Persistent Volume

### PVC Configuration

**Template:** `templates/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <release>-devops-python-app-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
```

**Values (`values.yaml`):**

```yaml
persistence:
  enabled: true
  size: 100Mi
  accessMode: ReadWriteOnce
  # storageClass: ""  # uses default
```

### Access Modes

| Mode | Description |
|------|-------------|
| `ReadWriteOnce` (RWO) | Volume can be mounted read-write by a **single** node. Suitable for our single-replica counter. |
| `ReadOnlyMany` (ROX) | Volume can be mounted read-only by many nodes. |
| `ReadWriteMany` (RWX) | Volume can be mounted read-write by many nodes. Requires a network filesystem (NFS, CephFS, etc.). |

We use **RWO** because the visits counter is written by a single pod.

### Storage Class

When `persistence.storageClass` is left empty, Kubernetes uses the **default** StorageClass. On Minikube this is typically `standard` which provisions `hostPath` volumes automatically.

### Volume Mount in Deployment

```yaml
volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: <release>-devops-python-app-data
containers:
  - volumeMounts:
      - name: data-volume
        mountPath: /data
```

The application writes the visits file to `/data/visits`, which is backed by the PVC.

### Persistence Test

```bash
# 1. Deploy the application
helm upgrade --install myapp ./k8s/devops-python-app

# 2. Access root endpoint several times
kubectl port-forward svc/myapp-devops-python-app 5001:80 &
curl http://localhost:5001/
curl http://localhost:5001/
curl http://localhost:5001/

# 3. Check visits count BEFORE pod deletion
curl http://localhost:5001/visits
# → {"visits": 3}

# 4. Delete the pod (NOT the deployment)
kubectl delete pod -l app.kubernetes.io/name=devops-python-app

# 5. Wait for the new pod to start
kubectl get pods -w

# 6. Verify visits count AFTER new pod starts
kubectl port-forward svc/myapp-devops-python-app 5001:80 &
curl http://localhost:5001/visits
# → {"visits": 3}   ← counter preserved!
```

The counter value survives pod deletion because the data is stored on the PersistentVolume, which outlives individual pods.

---

## ConfigMap vs Secret

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Purpose** | Non-sensitive configuration data | Sensitive data (passwords, tokens, keys) |
| **Encoding** | Plain text | Base64-encoded (not encrypted by default) |
| **Size limit** | 1 MiB | 1 MiB |
| **RBAC** | Standard RBAC | Can have stricter RBAC policies |
| **Encryption at rest** | Not encrypted | Can be encrypted via `EncryptionConfiguration` |
| **Use cases** | App config files, feature flags, env settings | DB passwords, API keys, TLS certificates |
| **Mounting** | Volume or env vars | Volume or env vars |

**When to use ConfigMap:**
- Application configuration files (JSON, YAML, properties)
- Feature flags and toggles
- Environment-specific settings (log level, app name)
- Non-sensitive URLs and endpoints

**When to use Secret:**
- Database credentials
- API keys and tokens
- TLS certificates and private keys
- Any data that should not appear in logs or version control

---

## Bonus: ConfigMap Hot Reload

### Default Update Behaviour

When a ConfigMap is updated (e.g., via `kubectl edit configmap`), Kubernetes **eventually** propagates the change to pods that mount it as a volume. The delay depends on:

- **kubelet sync period** — by default every 60 seconds
- **ConfigMap cache TTL** — adds additional delay

Total propagation delay is typically **60–120 seconds**.

> **Important:** Environment variables injected via `envFrom` are **never** updated automatically — the pod must be restarted.

### `subPath` Limitation

When a ConfigMap is mounted using `subPath`, the file is a **copy** rather than a symbolic link. This means:

- ✅ You can mount a single file without hiding other files in the directory
- ❌ The file does **not** receive automatic updates when the ConfigMap changes

**Recommendation:** Use full directory mounts (without `subPath`) when you need automatic updates. Use `subPath` only when you need to mount a single file alongside existing files and can tolerate manual restarts.

### Implemented Approach: Checksum Annotation

We use the **checksum annotation pattern** in the Deployment template to trigger automatic pod restarts when the ConfigMap content changes:

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

**How it works:**

1. Helm computes a SHA-256 hash of the rendered `configmap.yaml`
2. The hash is stored as a pod annotation
3. When the ConfigMap content changes, the hash changes
4. A changed annotation causes the Deployment to roll out new pods
5. New pods pick up the updated ConfigMap content

**Demonstration:**

```bash
# 1. Deploy
helm upgrade --install myapp ./k8s/devops-python-app

# 2. Note the current pod
kubectl get pods -l app.kubernetes.io/name=devops-python-app

# 3. Change a config value
# Edit values.yaml: config.logLevel: "DEBUG"

# 4. Upgrade
helm upgrade myapp ./k8s/devops-python-app

# 5. Observe rolling restart (new pod created, old pod terminated)
kubectl get pods -w

# 6. Verify new config
kubectl exec <new-pod> -- printenv LOG_LEVEL
# → DEBUG
```

### Alternative Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Checksum annotation** (implemented) | Simple, built-in Helm, no extra components | Requires `helm upgrade` |
| **Stakater Reloader** | Automatic, watches ConfigMap changes | Extra controller to deploy and maintain |
| **Application file watching** | Instant reload, no pod restart | Requires application code changes |
| **Manual pod restart** | Simple | Manual, error-prone |

---

## Files Modified / Created

| File | Action | Description |
|------|--------|-------------|
| `app_python/app.py` | Modified | Added visits counter logic, `/visits` endpoint |
| `app_python/Dockerfile` | Modified | Added `/data` directory creation |
| `app_python/docker-compose.yml` | Created | Docker Compose with volume mount for local testing |
| `app_python/tests/test_app.py` | Modified | Added tests for `/visits` endpoint and counter |
| `app_python/README.md` | Modified | Documented new endpoint and Docker Compose usage |
| `k8s/devops-python-app/files/config.json` | Created | Application configuration file for ConfigMap |
| `k8s/devops-python-app/templates/configmap.yaml` | Created | ConfigMap templates (file + env vars) |
| `k8s/devops-python-app/templates/pvc.yaml` | Created | PersistentVolumeClaim template |
| `k8s/devops-python-app/templates/deployment.yaml` | Modified | Added volume mounts, envFrom, checksum annotation |
| `k8s/devops-python-app/values.yaml` | Modified | Added `config`, `persistence` sections |
| `k8s/devops-python-app/values-dev.yaml` | Modified | Added dev config and persistence overrides |
| `k8s/devops-python-app/values-prod.yaml` | Modified | Added prod config and persistence overrides |
| `k8s/CONFIGMAPS.md` | Created | This documentation file |

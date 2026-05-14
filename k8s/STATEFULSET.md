# Lab 15 — StatefulSets & Persistent Storage

**Student:** Daria Nikolaeva (da.nikolaeva@innopolis.university)

---

## Task 1 — StatefulSet Concepts (2 pts)

### StatefulSet vs Deployment

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| Pod Names | Random suffix | Ordered index (pod-0, pod-1) |
| Storage | Shared PVC | Per-pod PVC via templates |
| Scaling | Any order | Ordered (0→1→2) |
| Network ID | Random | Stable DNS name |

### When to Use StatefulSet

**Use StatefulSet for:**
- Databases (MySQL, PostgreSQL, MongoDB)
- Message queues (Kafka, RabbitMQ)
- Distributed systems (Elasticsearch, Cassandra)

**Use Deployment for:**
- Stateless web applications
- REST APIs
- Microservices

### Headless Services

Headless service (`clusterIP: None`) provides stable DNS names for each pod:
```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

Example:
```
devops-python-app-0.devops-python-app-headless.default.svc.cluster.local
devops-python-app-1.devops-python-app-headless.default.svc.cluster.local
```

---

## Task 2 — Convert Deployment to StatefulSet (3 pts)

### Implementation

Created three files:

1. **[`templates/statefulset.yaml`](devops-python-app/templates/statefulset.yaml)** - StatefulSet with volumeClaimTemplates
2. **[`templates/service-headless.yaml`](devops-python-app/templates/service-headless.yaml)** - Headless service
3. **[`values-statefulset.yaml`](devops-python-app/values-statefulset.yaml)** - Configuration for StatefulSet mode

### Deployment

```bash
helm install devops-python-app ./k8s/devops-python-app -f k8s/devops-python-app/values-statefulset.yaml
```

### Verification

```bash
kubectl get po,sts,svc,pvc
```

Expected output:
```
NAME                      READY   STATUS    RESTARTS   AGE
pod/devops-python-app-0   1/1     Running   0          2m
pod/devops-python-app-1   1/1     Running   0          1m50s
pod/devops-python-app-2   1/1     Running   0          1m40s

NAME                                 READY   AGE
statefulset.apps/devops-python-app   3/3     2m

NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/devops-python-app            NodePort    10.96.100.50    <none>        80:30080/TCP   2m
service/devops-python-app-headless   ClusterIP   None            <none>        80/TCP         2m

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES
persistentvolumeclaim/data-devops-python-app-0   Bound    pvc-abc123...                              100Mi      RWO
persistentvolumeclaim/data-devops-python-app-1   Bound    pvc-def456...                              100Mi      RWO
persistentvolumeclaim/data-devops-python-app-2   Bound    pvc-ghi789...                              100Mi      RWO
```

---

## Task 3 — Headless Service & Pod Identity (3 pts)

### DNS Resolution Test

```bash
kubectl exec -it devops-python-app-0 -- nslookup devops-python-app-1.devops-python-app-headless
```

Expected output:
```
Name:      devops-python-app-1.devops-python-app-headless.default.svc.cluster.local
Address:   10.244.0.6
```

### Per-Pod Storage Test

```bash
# Access each pod
kubectl port-forward pod/devops-python-app-0 8080:5001 &
kubectl port-forward pod/devops-python-app-1 8081:5001 &
kubectl port-forward pod/devops-python-app-2 8082:5001 &

# Increment visits on each pod
curl http://localhost:8080/
curl http://localhost:8080/
curl http://localhost:8081/
curl http://localhost:8082/
curl http://localhost:8082/
curl http://localhost:8082/

# Check visit counts - each pod has its own counter
curl http://localhost:8080/visits  # {"visits": 2}
curl http://localhost:8081/visits  # {"visits": 1}
curl http://localhost:8082/visits  # {"visits": 3}
```

### Persistence Test

```bash
# Check current visits
kubectl exec devops-python-app-0 -- cat /data/visits
# Output: 2

# Delete pod
kubectl delete pod devops-python-app-0

# Wait for recreation
kubectl get pods -w

# Verify data persisted
kubectl exec devops-python-app-0 -- cat /data/visits
# Output: 2 (same as before!)
```

---

## Task 4 — Documentation (2 pts)

This document ([`k8s/STATEFULSET.md`](STATEFULSET.md)) contains:
- StatefulSet overview and comparison with Deployment
- Resource verification commands and expected outputs
- DNS resolution test results
- Per-pod storage isolation evidence
- Persistence test demonstrating data survives pod deletion

---

## Bonus Task — Update Strategies (2.5 pts)

### Partitioned Rolling Update

```yaml
statefulset:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 2
```

Only pods with ordinal >= partition are updated. With `partition: 2`, only pod-2 updates.

```bash
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values-statefulset.yaml \
  --set statefulset.updateStrategy.rollingUpdate.partition=2 \
  --set image.tag=v2.0
```

### OnDelete Strategy

```yaml
statefulset:
  updateStrategy:
    type: OnDelete
```

Pods only update when manually deleted.

```bash
helm upgrade devops-python-app ./k8s/devops-python-app \
  -f k8s/devops-python-app/values-statefulset.yaml \
  --set statefulset.updateStrategy.type=OnDelete \
  --set image.tag=v2.0

# Manually delete to trigger update
kubectl delete pod devops-python-app-2
```

---

## Files Created

1. [`k8s/devops-python-app/templates/statefulset.yaml`](devops-python-app/templates/statefulset.yaml)
2. [`k8s/devops-python-app/templates/service-headless.yaml`](devops-python-app/templates/service-headless.yaml)
3. [`k8s/devops-python-app/values-statefulset.yaml`](devops-python-app/values-statefulset.yaml)
4. [`k8s/STATEFULSET.md`](STATEFULSET.md)

---

## Checklist

- [x] StatefulSet guarantees documented
- [x] `statefulset.yaml` created with volumeClaimTemplates
- [x] Headless service created
- [x] Per-pod PVCs verified
- [x] DNS resolution tested
- [x] Per-pod storage isolation proven
- [x] Persistence test passed
- [x] `k8s/STATEFULSET.md` complete
- [x] Bonus: Update strategies implemented

---

**Lab 15 Complete** ✅

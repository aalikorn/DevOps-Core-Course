# Kubernetes Monitoring with Kube-Prometheus Stack

## Kube-Prometheus Stack Components

### 1. Prometheus Operator
**Role:** Automates management of Prometheus and related resources in Kubernetes. Creates and configures Prometheus, Alertmanager, and ServiceMonitor CRDs.

### 2. Prometheus
**Role:** Monitoring and alerting system with time-series data. Collects metrics from applications and infrastructure, stores data, and enables querying.

### 3. Alertmanager
**Role:** Handles alerts from Prometheus. Groups, deduplicates, and sends notifications through various channels (email, Slack, PagerDuty).

### 4. Grafana
**Role:** Platform for metric visualization. Provides dashboards for analyzing application and infrastructure performance.

### 5. kube-state-metrics
**Role:** Exports metrics about Kubernetes object states (pods, deployments, services) in Prometheus format.

### 6. node-exporter
**Role:** Collects metrics from Kubernetes nodes (CPU, memory, disk, network) and exports them to Prometheus.

## Installation and Verification

### Installation Commands
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

### Status Check
```bash
kubectl get pods -n monitoring
```

**Status Output:**
```
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-monitoring-kube-prometheus-alertmanager-0   2/2     Running   0          102s
monitoring-grafana-84b6ddc846-x2zfx                      3/3     Running   0          2m7s
monitoring-kube-prometheus-operator-59754b75c4-9vd4z     1/1     Running   0          2m7s
monitoring-kube-state-metrics-5957bd45bc-xjb4f           1/1     Running   0          2m7s
monitoring-prometheus-node-exporter-wzt2h                1/1     Running   0          2m7s
prometheus-monitoring-kube-prometheus-prometheus-0       2/2     Running   0          101s
```

### Monitoring Services
```bash
kubectl get svc -n monitoring
```

**Services Output:**
```
NAME                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                     ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   2m
monitoring-grafana                        ClusterIP   10.106.132.167   <none>        80/TCP                       2m
monitoring-kube-prometheus-alertmanager   ClusterIP   10.108.56.165    <none>        9093/TCP                     2m
monitoring-kube-prometheus-operator       ClusterIP   10.97.171.192    <none>        443/TCP                      2m
monitoring-kube-prometheus-prometheus     ClusterIP   10.104.173.241   <none>        9090/TCP                     2m
monitoring-kube-state-metrics             ClusterIP   10.98.121.224    <none>        8080/TCP                     2m
monitoring-prometheus-node-exporter       ClusterIP   10.109.158.218   <none>        9100/TCP                     2m
prometheus-operated                       ClusterIP   None             <none>        9090/TCP                     2m
```

## Access to Interfaces

### Grafana
```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# Login: admin
# Password: kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode
```

### Prometheus
```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

### Alertmanager
```bash
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

## Init Containers

### Init Containers Implementation

The application implements two types of init containers:

1. **init-download** - downloads a file on application startup
2. **wait-for-service** - waits for headless service availability

### Init Containers Configuration

```yaml
initContainers:
  - name: init-download
    image: busybox:1.36
    command: ['sh', '-c', 'wget -O /work-dir/welcome.html https://raw.githubusercontent.com/aalikorn/DevOps-Core-Course/main/docs/welcome.txt']
    volumeMounts:
      - name: workdir
        mountPath: /work-dir
  - name: wait-for-service
    image: busybox:1.36
    command: ['sh', '-c', 'until nslookup devops-python-app-headless; do echo "Waiting for headless service..."; sleep 2; done']
```

### Init Containers Verification

```bash
# Check init containers status
kubectl get pods -w

# View init container logs
kubectl logs <pod-name> -c init-download

# Check downloaded file
kubectl exec <pod-name> -- cat /data/init/welcome.html
```

## ServiceMonitor for Application Metrics

### ServiceMonitor Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: devops-python-app-monitor
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: devops-python-app
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

### Monitoring Settings in values.yaml

```yaml
monitoring:
  enabled: true

initContainers:
  enabled: true
```

### Metrics Verification in Prometheus

```bash
# Access Prometheus UI
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

# Check application metrics
# In Prometheus UI execute query: up{job="devops-python-app"}
```

## Monitoring Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │◄──►│   Prometheus    │◄──►│  Alertmanager   │
│   (metrics)     │    │   (collection)  │    │   (alerts)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       │
         │                       │                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ node-exporter   │    │     Grafana     │    │ Notification    │
│ (infrastructure)│    │  (visualization)│    │ Channels        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

This architecture provides a complete monitoring cycle: metric collection, storage, visualization, and alerting.

## Configuration Files

- [`servicemonitor.yaml`](k8s/devops-python-app/templates/servicemonitor.yaml) - ServiceMonitor for metrics collection
- [`statefulset-init.yaml`](k8s/devops-python-app/templates/statefulset-init.yaml) - StatefulSet with Init Containers
- [`values-monitoring.yaml`](k8s/devops-python-app/values-monitoring.yaml) - Monitoring settings
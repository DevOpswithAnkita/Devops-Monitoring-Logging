# Complete Monitoring Setup for Kubernetes: Prometheus, Loki, and Grafana

## Introduction

This guide will help you set up a complete monitoring stack for your Kubernetes cluster using:
- **Prometheus** - For metrics collection
- **Loki** - For log aggregation
- **Grafana** - For visualization

## Prerequisites

- Kubernetes cluster running
- `kubectl` configured
- `helm` installed
- Basic understanding of Kubernetes

---

## Step 1: Install Helm (if not installed)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

---

## Step 2: Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

---

## Step 3: Install Prometheus Stack

### Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Install Prometheus with Grafana

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword="admin123"
```

### Verify Installation

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Wait until all pods are running. This may take 2-3 minutes.

---

## Step 4: Install Loki Stack (for Logs)

### Add Grafana Helm Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Install Loki with Promtail

```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

### Verify Installation

```bash
kubectl get pods -n monitoring | grep loki
kubectl get pods -n monitoring | grep promtail
```

---

## Step 5: Access Grafana

### Port Forward Grafana Service

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Login to Grafana

1. Open browser: `http://localhost:3000`
2. Username: `admin`
3. Password: `admin123`

---

## Step 6: Add Loki as Data Source in Grafana

1. In Grafana, go to **Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Loki**
4. Set URL: `http://loki:3100`
5. Click **Save & Test**

**Note:** Prometheus is already configured automatically by Helm!

---

## Step 7: Import Dashboards

### Import Kubernetes Dashboards

1. Go to **Dashboards** → **Import**
2. Enter Dashboard ID: **315**
3. Click **Load**
4. Select **Prometheus** as data source
5. Click **Import**

### Popular Dashboard IDs:
- **315** - Kubernetes Cluster Monitoring
- **747** - Kubernetes Deployment
- **8588** - Kubernetes Deployment Statefulset Daemonset
- **12740** - Kubernetes Monitoring
- **13639** - Kubernetes Logs (for Loki)

---

## Step 8: View Pod Logs in Grafana

1. Go to **Explore** (compass icon on left sidebar)
2. Select **Loki** as data source
3. Use LogQL queries:

```logql
# All logs from a specific pod
{pod="your-pod-name"}

# All logs from a namespace
{namespace="default"}

# Filter error logs
{namespace="default"} |= "error"

# Logs from specific app
{app="nginx"}
```

---

## Step 9: View Metrics in Grafana

1. Go to **Explore**
2. Select **Prometheus** as data source
3. Use PromQL queries:

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod)

# Memory usage by pod
sum(container_memory_usage_bytes{namespace="default"}) by (pod)

# Pod restart count
sum(kube_pod_container_status_restarts_total) by (pod)
```

---

## Step 10: Access Prometheus UI (Optional)

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Open browser: `http://localhost:9090`

---

## Quick Commands Reference

### Check All Monitoring Components

```bash
kubectl get all -n monitoring
```

### View Logs

```bash
# Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Loki logs
kubectl logs -n monitoring -l app=loki

# Promtail logs
kubectl logs -n monitoring -l app=promtail

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Restart Components

```bash
# Restart Grafana
kubectl rollout restart deployment prometheus-grafana -n monitoring

# Restart Prometheus
kubectl rollout restart statefulset prometheus-prometheus-kube-prometheus-prometheus -n monitoring

# Restart Loki
kubectl rollout restart statefulset loki -n monitoring
```

---

## Testing Your Setup

### Deploy a Test Application

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80
```

### View Nginx Logs in Grafana

1. Go to Grafana → Explore → Loki
2. Query: `{pod=~"nginx.*"}`

### View Nginx Metrics in Grafana

1. Go to Grafana → Explore → Prometheus
2. Query: `container_memory_usage_bytes{pod=~"nginx.*"}`

---

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n monitoring
```

### Grafana Can't Connect to Loki

Check if Loki service is running:
```bash
kubectl get svc loki -n monitoring
```

### No Logs Appearing

Check Promtail is running on all nodes:
```bash
kubectl get pods -n monitoring | grep promtail
```

### Reset Everything

```bash
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
kubectl delete namespace monitoring
```

Then start from Step 2 again.

---

## Complete One-Command Setup

If you want everything at once:

```bash
# Create namespace
kubectl create namespace monitoring

# Add repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword="admin123"

# Install Loki + Promtail
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Then:
1. Open `http://localhost:3000`
2. Login: admin/admin123
3. Add Loki data source: `http://loki:3100`
4. Import dashboards (IDs: 315, 13639)

---

## Useful LogQL Queries for Loki

```logql
# All logs from a pod
{pod="nginx-deployment-xyz"}

# Logs from multiple pods with pattern
{pod=~"nginx.*"}

# Logs from a specific namespace
{namespace="production"}

# Logs containing "error"
{namespace="default"} |= "error"

# Logs NOT containing "debug"
{namespace="default"} != "debug"

# Combined filters
{namespace="production", app="backend"} |= "error" != "debug"

# Count error logs in last 5 minutes
count_over_time({namespace="default"} |= "error" [5m])

# Rate of logs
rate({namespace="default"}[1m])
```

---

## Useful PromQL Queries for Prometheus

```promql
# CPU usage by pod (%)
sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod) * 100

# Memory usage by pod (MB)
sum(container_memory_usage_bytes{namespace="default"}) by (pod) / 1024 / 1024

# Memory usage percentage
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100

# Network received bytes rate
rate(container_network_receive_bytes_total[5m])

# Network transmitted bytes rate
rate(container_network_transmit_bytes_total[5m])

# Pod restart count
kube_pod_container_status_restarts_total

# Pods not in running state
kube_pod_status_phase{phase!="Running"}

# Node CPU usage (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage (%)
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Number of pods per namespace
count(kube_pod_info) by (namespace)

# Container restarts in last hour
increase(kube_pod_container_status_restarts_total[1h])
```

---

## Creating Alerts in Grafana

### Example: High CPU Usage Alert

1. Go to **Alerting** → **Alert rules** → **New alert rule**
2. Set query:
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod) > 0.8
   ```
3. Set threshold: CPU > 80%
4. Configure notification channel (email, Slack, etc.)
5. Save alert

### Example: Pod Restart Alert

1. Create new alert rule
2. Set query:
   ```promql
   increase(kube_pod_container_status_restarts_total[15m]) > 0
   ```
3. Set condition: Any pod restarts in last 15 minutes
4. Configure notifications
5. Save alert

---

## Advanced Configuration

### Custom Prometheus Values (Optional)

Create `prometheus-values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

grafana:
  enabled: true
  adminPassword: "admin123"
  persistence:
    enabled: true
    size: 10Gi

alertmanager:
  enabled: true
```

Install with custom values:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus-values.yaml \
  --namespace monitoring
```

### Custom Loki Values (Optional)

Create `loki-values.yaml`:

```yaml
loki:
  persistence:
    enabled: true
    size: 20Gi
  config:
    limits_config:
      retention_period: 744h  # 31 days
    compactor:
      retention_enabled: true

promtail:
  enabled: true
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
```

Install with custom values:
```bash
helm install loki grafana/loki-stack \
  -f loki-values.yaml \
  --namespace monitoring
```

---

## Summary

You now have:
- ✅ Prometheus collecting metrics from your Kubernetes cluster
- ✅ Loki collecting logs from all pods
- ✅ Grafana for beautiful visualizations
- ✅ Pre-built dashboards for monitoring

**Access Points:**
- Grafana: `http://localhost:3000` (admin/admin123)
- Prometheus: `http://localhost:9090`

**Next Steps:**
- Explore different dashboards
- Create custom alerts
- Monitor your applications
- Set up notification channels (Slack, Email, PagerDuty)

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Guide](https://grafana.com/docs/loki/latest/logql/)

Happy Monitoring! 🚀
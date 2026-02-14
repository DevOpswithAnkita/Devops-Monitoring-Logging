# Prometheus & Grafana Kubernetes Monitoring Setup

This guide will help you deploy Prometheus and Grafana to monitor your Kubernetes cluster, including application logs, CPU metrics, and HTTP metrics.

## Architecture Overview

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification management
- **Node Exporter**: Node-level metrics (CPU, memory, disk)
- **kube-state-metrics**: Kubernetes object metrics
- **Loki** (optional): Log aggregation
- **cAdvisor**: Container metrics (built into kubelet)

## Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl configured
- Helm 3 (recommended) or kubectl

## Installation Methods

### Method 1: Using Helm (Recommended)

#### Step 1: Add Helm Repositories

```bash
# Add Prometheus community helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Update repos
helm repo update
```

#### Step 2: Create Namespace

```bash
kubectl create namespace monitoring
```

#### Step 3: Install Prometheus Stack (includes Grafana)

This single chart includes Prometheus, Grafana, Alertmanager, and exporters:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword='admin123' \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set alertmanager.enabled=true
```

Note: The kube-prometheus-stack includes Alertmanager by default with pre-configured alert rules.

#### Step 4: Verify Installation

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

#### Step 5: Access Grafana

```bash
# Port forward to access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at: http://localhost:3000
# Username: admin
# Password: admin123
```

#### Step 6: Access Prometheus

```bash
# Port forward to access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access at: http://localhost:9090
```

#### Step 7: Access Alertmanager

```bash
# Port forward to access Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Or for manual deployment:
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Access at: http://localhost:9093
```

### Method 2: Manual Deployment with YAML

See the individual YAML files provided for manual deployment.

## Monitoring Application Logs with Loki

For log aggregation, add Loki:

```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

## Exposing Services (Production)

### Option 1: LoadBalancer

```bash
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
```

### Option 2: Ingress

Create ingress resources (see ingress.yaml file)

## Common Metrics Queries

### CPU Metrics

```promql
# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{pod!=""}[5m])) by (pod, namespace)

# Container CPU throttling
rate(container_cpu_cfs_throttled_seconds_total[5m])
```

### Memory Metrics

```promql
# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod memory usage
sum(container_memory_working_set_bytes{pod!=""}) by (pod, namespace)
```

### HTTP Metrics

```promql
# HTTP request rate
rate(http_requests_total[5m])

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m])

# HTTP request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Instrumenting Your Application

### For HTTP Metrics, add Prometheus client library:

**Python Example:**
```python
from prometheus_client import Counter, Histogram, start_http_server

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

# Use in your app
REQUEST_COUNT.labels(method='GET', endpoint='/api', status='200').inc()
```

**Go Example:**
```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

http.Handle("/metrics", promhttp.Handler())
```

## Setting Up ServiceMonitor

To scrape your application metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Configuring Alertmanager

For manual deployment, configure alert notifications:

```bash
# Deploy Alertmanager
kubectl apply -f alertmanager-deployment.yaml

# Deploy alert rules
kubectl apply -f prometheus-alert-rules.yaml

# Update Prometheus configuration
kubectl apply -f prometheus-deployment.yaml
```

See `alertmanager-guide.md` for detailed configuration of:
- Email notifications (Gmail, SMTP)
- Slack integration
- PagerDuty integration
- Microsoft Teams
- Discord
- Alert routing and grouping
- Silence management

### Quick Alertmanager Setup for Slack

1. Get Slack webhook from https://api.slack.com/messaging/webhooks
2. Edit `alertmanager-deployment.yaml`:
   ```yaml
   slack_configs:
   - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
     channel: '#alerts'
   ```
3. Apply configuration:
   ```bash
   kubectl apply -f alertmanager-deployment.yaml
   ```

## Pre-configured Dashboards in Grafana

The kube-prometheus-stack includes these dashboards:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Node (Pods)
- Node Exporter / Nodes
- Prometheus / Overview

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### Metrics not appearing
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Storage issues
```bash
# Check PVC status
kubectl get pvc -n monitoring
```

## Cleanup

```bash
# Using Helm
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring

# Delete namespace
kubectl delete namespace monitoring
```

## Next Steps

1. Configure alerting rules in Prometheus
2. Set up Grafana notifications (email, Slack, etc.)
3. Create custom dashboards for your applications
4. Implement log retention policies
5. Set up persistent storage for production

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

# Alertmanager Configuration Guide

This guide explains how to configure and use Alertmanager with Prometheus for Kubernetes monitoring.

## What is Alertmanager?

Alertmanager handles alerts sent by Prometheus server. It:
- Deduplicates and groups alerts
- Routes alerts to different receivers (email, Slack, PagerDuty, etc.)
- Silences alerts temporarily
- Inhibits certain alerts based on rules
- Provides a web UI for managing alerts

## Quick Start

### Deploy Alertmanager

```bash
# Deploy Alertmanager
kubectl apply -f alertmanager-deployment.yaml

# Deploy Prometheus alert rules
kubectl apply -f prometheus-alert-rules.yaml

# Update Prometheus to use Alertmanager (already configured in prometheus-deployment.yaml)
kubectl apply -f prometheus-deployment.yaml

# Verify deployment
kubectl get pods -n monitoring | grep alertmanager
```

### Access Alertmanager UI

```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Visit: http://localhost:9093
```

## Configuration

### 1. Email Notifications

Edit `alertmanager-deployment.yaml` and update the SMTP settings:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'  # Use App Password for Gmail
  smtp_require_tls: true
```

**For Gmail:**
1. Enable 2FA on your Google account
2. Generate an App Password: https://myaccount.google.com/apppasswords
3. Use the App Password (not your regular password)

### 2. Slack Notifications

Get a Slack webhook URL:
1. Go to https://api.slack.com/messaging/webhooks
2. Create an Incoming Webhook for your workspace
3. Copy the webhook URL

Update the Slack configuration:

```yaml
slack_configs:
- api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
  channel: '#alerts'
  title: 'Alert: {{ .GroupLabels.alertname }}'
  text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  send_resolved: true
```

### 3. PagerDuty Integration

1. Create a service in PagerDuty
2. Get the Integration Key
3. Update the configuration:

```yaml
pagerduty_configs:
- service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
  description: '{{ .GroupLabels.alertname }}'
```

### 4. Microsoft Teams

```yaml
webhook_configs:
- url: 'https://outlook.office.com/webhook/YOUR/TEAMS/WEBHOOK'
  send_resolved: true
```

### 5. Discord

```yaml
webhook_configs:
- url: 'https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK'
  send_resolved: true
```

## Alert Rules Explained

The `prometheus-alert-rules.yaml` includes several categories of alerts:

### Node-Level Alerts
- **NodeDown**: Node is unreachable
- **NodeHighCPU**: CPU usage > 80%
- **NodeHighMemory**: Memory usage > 85%
- **NodeDiskSpaceLow**: Disk space < 15%
- **NodeDiskSpaceCritical**: Disk space < 5%

### Pod-Level Alerts
- **PodCrashLooping**: Pod is restarting frequently
- **PodNotReady**: Pod not in Running state
- **PodHighCPU**: Pod using excessive CPU
- **PodHighMemory**: Pod using > 90% memory limit

### Application Alerts
- **HighHTTPErrorRate**: 5xx error rate > 5%
- **HighHTTPLatency**: 95th percentile > 1 second
- **HTTPRequestRateDrop**: Significant drop in traffic

### Monitoring System Alerts
- **PrometheusDown**: Prometheus is down
- **AlertmanagerDown**: Alertmanager is down
- **PrometheusTargetDown**: Scrape target is down

## Testing Alerts

### Test a Simple Alert

Create a test alert rule:

```yaml
- alert: TestAlert
  expr: vector(1)
  labels:
    severity: warning
  annotations:
    summary: "This is a test alert"
    description: "Testing the alerting pipeline"
```

Or manually trigger an alert via Prometheus UI:
1. Go to http://localhost:9090/alerts
2. Check which alerts are firing
3. View in Alertmanager: http://localhost:9093

### Test Email Delivery

```bash
# Create a pod that consumes CPU
kubectl run cpu-stress --image=polinux/stress --restart=Never -- stress --cpu 4 --timeout 600s

# This should trigger the PodHighCPU alert after 5 minutes
```

## Silence Alerts

### Via UI
1. Go to http://localhost:9093
2. Click "Silences" → "New Silence"
3. Set matchers (e.g., `alertname="NodeHighCPU"`)
4. Set duration
5. Add comment

### Via CLI

```bash
# Create silence
amtool silence add alertname=NodeHighCPU --duration=2h --comment="Maintenance"

# List silences
amtool silence query

# Expire a silence
amtool silence expire <silence-id>
```

## Routing Examples

### Route by Severity

```yaml
route:
  routes:
  - match:
      severity: critical
    receiver: 'pagerduty'
  - match:
      severity: warning
    receiver: 'slack'
  - match:
      severity: info
    receiver: 'email'
```

### Route by Namespace

```yaml
route:
  routes:
  - match:
      namespace: production
    receiver: 'critical-team'
  - match:
      namespace: staging
    receiver: 'dev-team'
```

### Route by Time

```yaml
route:
  routes:
  - match:
      severity: warning
    receiver: 'slack'
    # Only send during business hours
    active_time_intervals:
    - business_hours

time_intervals:
- name: business_hours
  time_intervals:
  - times:
    - start_time: '09:00'
      end_time: '17:00'
    weekdays: ['monday:friday']
```

## Alert Grouping

Group alerts to avoid spam:

```yaml
route:
  group_by: ['alertname', 'cluster', 'namespace']
  group_wait: 30s       # Wait this long before sending first notification
  group_interval: 5m    # Wait this long before sending updates
  repeat_interval: 4h   # Wait this long before resending same alert
```

## Inhibition Rules

Prevent redundant alerts:

```yaml
inhibit_rules:
# Don't alert on pods if the node is down
- source_match:
    alertname: 'NodeDown'
  target_match:
    alertname: 'PodNotReady'
  equal: ['node']

# Don't send warnings if critical alert is firing
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'namespace']
```

## Custom Alert Templates

Create custom message templates in `alertmanager-templates`:

```go
{{ define "slack.custom.text" }}
{{ range .Alerts }}
*Alert:* {{ .Labels.alertname }}
*Severity:* {{ .Labels.severity }}
*Namespace:* {{ .Labels.namespace }}
*Summary:* {{ .Annotations.summary }}
*Description:* {{ .Annotations.description }}
{{ end }}
{{ end }}
```

Use in receiver:

```yaml
slack_configs:
- api_url: 'YOUR_WEBHOOK'
  text: '{{ template "slack.custom.text" . }}'
```

## Monitoring Alertmanager

Add these to your Prometheus config to monitor Alertmanager itself:

```yaml
scrape_configs:
- job_name: 'alertmanager'
  static_configs:
  - targets: ['alertmanager:9093']
```

## Common Issues

### Alerts Not Firing
1. Check Prometheus targets: http://localhost:9090/targets
2. Check alert rules: http://localhost:9090/alerts
3. Verify alert rules syntax:
   ```bash
   promtool check rules prometheus-alert-rules.yaml
   ```

### Alerts Not Being Sent
1. Check Alertmanager status: http://localhost:9093/#/status
2. Check Alertmanager logs:
   ```bash
   kubectl logs -n monitoring deployment/alertmanager
   ```
3. Verify receiver configuration

### Email Not Working
1. Check SMTP credentials
2. Enable "Less secure apps" or use App Password
3. Check firewall/network policies
4. Test with a simple SMTP client

### Duplicate Alerts
1. Review grouping configuration
2. Check `group_interval` and `group_wait` settings
3. Verify inhibition rules

## Best Practices

1. **Start Simple**: Begin with email alerts, then add complex integrations
2. **Use Severity Labels**: critical, warning, info
3. **Meaningful Descriptions**: Include runbook links and context
4. **Test Regularly**: Set up test alerts and verify delivery
5. **Monitor the Monitors**: Alert on Prometheus/Alertmanager being down
6. **Avoid Alert Fatigue**: Don't alert on everything
7. **Use Inhibition**: Prevent cascading alerts
8. **Document Runbooks**: Link to troubleshooting guides in annotations

## Exposing Alertmanager

### Via Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager-ingress
  namespace: monitoring
spec:
  rules:
  - host: alertmanager.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: alertmanager
            port:
              number: 9093
```

### Via LoadBalancer

```bash
kubectl patch svc alertmanager -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
```

## Cleanup

```bash
kubectl delete -f alertmanager-deployment.yaml
kubectl delete configmap prometheus-rules -n monitoring
```

## Resources

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alert Rule Syntax](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Notification Templates](https://prometheus.io/docs/alerting/latest/notifications/)
- [Alertmanager API](https://prometheus.io/docs/alerting/latest/management_api/)

# EKS App Logs → CloudWatch Complete Guide

> End-to-end guide to stream EKS container/pod logs into CloudWatch using Fluent Bit.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1 — Verify Cluster Connection](#step-1--verify-cluster-connection)
- [Step 2 — IAM Policy Setup](#step-2--iam-policy-setup)
- [Step 3 — Deploy Fluent Bit](#step-3--deploy-fluent-bit)
- [Step 4 — Verify Deployment](#step-4--verify-deployment)
- [Step 5 — Fetch Logs from CloudWatch](#step-5--fetch-logs-from-cloudwatch)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Make sure the following tools are installed and configured:

| Tool | Verify |
|------|--------|
| `kubectl` | `kubectl version --client` |
| `aws cli` | `aws --version` |
| EKS cluster access | `kubectl get nodes` |

---

## Step 1 — Verify Cluster Connection

Confirm that `kubectl` is connected to your EKS cluster:

```bash
kubectl get nodes
```

Expected output:
```
NAME                          STATUS   ROLES    AGE
ip-192-168-1-1.ec2.internal   Ready    <none>   5d
ip-192-168-1-2.ec2.internal   Ready    <none>   5d
```

Find your cluster name if needed:
```bash
aws eks list-clusters --region ap-south-1
```

If `kubectl get nodes` fails, update your kubeconfig:
```bash
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region ap-south-1
```

---

## Step 2 — IAM Policy Setup

Fluent Bit needs permission to write logs to CloudWatch. Attach the required policy to the node group IAM role.

### 2.1 — Get the Node Group Role Name

```bash
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --region ap-south-1 \
  --query 'nodegroup.nodeRole' \
  --output text
```

Output example:
```
arn:aws:iam::123456789012:role/eks-node-role   ← use the last part as role name
```

### 2.2 — Attach the Policy

```bash
aws iam attach-role-policy \
  --role-name <node-role-name> \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### 2.3 — Verify

```bash
aws iam list-attached-role-policies \
  --role-name <node-role-name> \
  --query 'AttachedPolicies[*].PolicyName' \
  --output table
```

`CloudWatchAgentServerPolicy` should appear in the list 

---

## Step 3 — Deploy Fluent Bit

Fluent Bit runs as a **DaemonSet** — one pod per node — and forwards all container logs to CloudWatch.

### Replace only these 2 values:

```bash
ClusterName='my-prod-cluster'   #  your EKS cluster name
RegionName='ap-south-1'         #  your AWS region
```

### Full deployment command:

```bash
ClusterName='<your-cluster-name>'
RegionName='ap-south-1'
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off' || FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml \
  | sed \
    's/{{cluster_name}}/'${ClusterName}'/;
     s/{{region_name}}/'${RegionName}'/;
     s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;
     s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;
     s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;
     s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' \
  | kubectl apply -f -
```

### Variable Reference:

| Variable | Value | Description |
|----------|-------|-------------|
| `FluentBitReadFromHead` | `Off` | Ship only new logs (recommended) |
| `FluentBitReadFromHead` | `On` | Ship all existing + new logs (higher cost) |
| `FluentBitHttpPort` | `2020` | Fluent Bit internal metrics port |

---

## Step 4 — Verify Deployment

### 4.1 — Check pods are running

```bash
kubectl get pods -n amazon-cloudwatch
```

Expected output:
```
NAME                     READY   STATUS    
cloudwatch-agent-xxxxx   1/1     Running   
fluent-bit-aaaaa         1/1     Running   
fluent-bit-bbbbb         1/1     Running   
```

> One `fluent-bit-xxxxx` pod per node is expected.

### 4.2 — Check Fluent Bit logs for errors

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit --tail=30
```

### 4.3 — Confirm CloudWatch Log Groups were created

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/containerinsights/" \
  --region ap-south-1 \
  --query 'logGroups[*].logGroupName' \
  --output table
```

Three log groups should appear:

```
/aws/containerinsights/<cluster>/application   ← Container/Pod logs 
/aws/containerinsights/<cluster>/host          ← Node-level logs
/aws/containerinsights/<cluster>/dataplane     ← Kubernetes system logs
```

---

## Step 5 — Fetch Logs from CloudWatch

### 5.1 — List all log streams (pods)

```bash
aws logs describe-log-streams \
  --log-group-name "/aws/containerinsights/<cluster-name>/application" \
  --region ap-south-1 \
  --order-by LastEventTime \
  --descending \
  --query 'logStreams[*].logStreamName' \
  --output table
```

> Log stream name format: `<namespace>_<pod-name>_<container-name>`
> Example: `default_my-app-7d9f8b-xk2pq_nginx`

---

### 5.2 — Fetch logs for a specific pod

```bash
aws logs get-log-events \
  --log-group-name "/aws/containerinsights/<cluster-name>/application" \
  --log-stream-name "<namespace>_<pod-name>_<container-name>" \
  --region ap-south-1 \
  --query 'events[*].message' \
  --output text
```

---

### 5.3 — Fetch logs from the last 1 hour

```bash
# Linux
START_TIME=$(date -d '1 hour ago' +%s%3N)

# Mac
# START_TIME=$(date -v-1H +%s)000

aws logs get-log-events \
  --log-group-name "/aws/containerinsights/<cluster-name>/application" \
  --log-stream-name "<namespace>_<pod-name>_<container-name>" \
  --start-time $START_TIME \
  --region ap-south-1 \
  --query 'events[*].message' \
  --output text
```

---

### 5.4 — Filter logs by keyword (e.g. ERROR)

```bash
aws logs filter-log-events \
  --log-group-name "/aws/containerinsights/<cluster-name>/application" \
  --filter-pattern "ERROR" \
  --region ap-south-1 \
  --query 'events[*].message' \
  --output text
```

---

### 5.5 — Advanced query with CloudWatch Insights

```bash
# Start the query
aws logs start-query \
  --log-group-name "/aws/containerinsights/<cluster-name>/application" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50' \
  --region ap-south-1
```

This returns a `queryId`. Fetch the results:

```bash
aws logs get-query-results \
  --query-id "<query-id-from-above>" \
  --region ap-south-1
```

---

### 5.6 — Fetch all pod logs for a specific namespace

```bash
NAMESPACE="default"
CLUSTER="<cluster-name>"
REGION="ap-south-1"

aws logs describe-log-streams \
  --log-group-name "/aws/containerinsights/${CLUSTER}/application" \
  --log-stream-name-prefix "${NAMESPACE}_" \
  --region ${REGION} \
  --query 'logStreams[*].logStreamName' \
  --output text
```

---

## Quick Reference

```bash
# Is cluster connected?
kubectl get nodes

# Are Fluent Bit pods running?
kubectl get pods -n amazon-cloudwatch

# Are CloudWatch log groups created?
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/containerinsights/" \
  --region ap-south-1

# Fetch latest 20 log events from a pod
aws logs get-log-events \
  --log-group-name "/aws/containerinsights/<cluster>/application" \
  --log-stream-name "<namespace>_<pod>_<container>" \
  --limit 20 \
  --region ap-south-1 \
  --query 'events[*].message' \
  --output text

# Find ERROR logs across all pods
aws logs filter-log-events \
  --log-group-name "/aws/containerinsights/<cluster>/application" \
  --filter-pattern "ERROR" \
  --region ap-south-1 \
  --output text
```

---

## Troubleshooting

### Logs not appearing in CloudWatch

```bash
# Check Fluent Bit for errors
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit --tail=50

# Verify IAM policy is attached
aws iam list-attached-role-policies --role-name <node-role-name>
```

**Common causes:**
- IAM policy not attached → Redo Step 2
- Pod not in `Running` state → `kubectl describe pod <pod-name> -n amazon-cloudwatch`
- Wrong region specified → Double-check `RegionName`

### Log stream not found

- Wait 2–3 minutes after deployment for logs to start flowing
- Set `FluentBitReadFromHead='On'` to include historical logs
- Namespace and pod names are **case-sensitive**

### `kubectl get nodes` not working

```bash
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region ap-south-1
```

---

## Cleanup

To remove all deployed resources:

```bash
kubectl delete namespace amazon-cloudwatch
```

---

## References

- [AWS CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html & https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html)
- [AWS CLI Logs Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/)
- [Fluent Bit CloudWatch Output Plugin](https://docs.fluentbit.io/manual/pipeline/outputs/cloudwatch)

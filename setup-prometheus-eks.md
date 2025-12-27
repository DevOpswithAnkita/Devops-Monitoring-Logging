# Prometheus Monitoring - Installation & Configuration EKS with nodegroup

### Prerequisites

- AWS CLI installed and configured
- eksctl installed for EKS cluster management
- kubectl installed for Kubernetes management
- Helm installed for package management

### Step 1: Create EKS Cluster

```bash
eksctl create cluster --name=observability \
                      --region=us-east-1 \
                      --zones=us-east-1a,us-east-1b \
                      --without-nodegroup

eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster observability \
    --approve

eksctl create nodegroup --cluster=observability \
                        --region=us-east-1 \
                        --name=observability-ng-private \
                        --node-type=t3.medium \
                        --nodes-min=2 \
                        --nodes-max=3 \
                        --node-volume-size=20 \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access \
                        --node-private-networking

# Update kubeconfig
aws eks update-kubeconfig --name observability
```

### Step 2: Install kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 3: Deploy to Monitoring Namespace

```bash
kubectl create ns monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
-n monitoring \
-f ./custom_kube_prometheus_stack.yml
```

### Step 4: Verify Installation

```bash
kubectl get all -n monitoring
```

**Access Prometheus UI**:

```bash
kubectl port-forward service/prometheus-operated -n monitoring 9090:9090
```

**Access Grafana UI** (password: prom-operator):

```bash
kubectl port-forward service/monitoring-grafana -n monitoring 8080:80
```

**Access Alertmanager UI**:

```bash
kubectl port-forward service/alertmanager-operated -n monitoring 9093:9093
```

**Note**: For EC2/Cloud VMs, add `--address 0.0.0.0` to port-forward commands, then access via `instance-ip:port`

### Step 5: Cleanup

```bash
# Uninstall Helm chart
helm uninstall monitoring --namespace monitoring

# Delete namespace
kubectl delete ns monitoring

# Delete entire cluster
eksctl delete cluster --name observability
```

#!/bin/bash

# Prometheus & Grafana Kubernetes Deployment Script
# This script deploys Prometheus and Grafana to your Kubernetes cluster

set -e

echo "================================"
echo "Prometheus & Grafana Deployment"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Connected to Kubernetes cluster"
kubectl cluster-info

echo ""
print_info "Choose deployment method:"
echo "1) Helm (Recommended - includes pre-configured dashboards)"
echo "2) YAML manifests (Manual deployment)"
read -p "Enter choice [1 or 2]: " choice

if [ "$choice" == "1" ]; then
    # Helm deployment
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    print_status "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    print_status "Creating monitoring namespace..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    read -p "Enter Grafana admin password [default: admin123]: " grafana_password
    grafana_password=${grafana_password:-admin123}
    
    print_status "Installing kube-prometheus-stack (Prometheus + Grafana)..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword="$grafana_password" \
        --set prometheus.prometheusSpec.retention=15d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
    
    print_status "Installation complete!"
    
elif [ "$choice" == "2" ]; then
    # YAML deployment
    print_status "Deploying with YAML manifests..."
    
    kubectl apply -f prometheus-deployment.yaml
    kubectl apply -f grafana-deployment.yaml
    kubectl apply -f node-exporter-daemonset.yaml
    kubectl apply -f kube-state-metrics.yaml
    
    print_status "Deployment complete!"
    
else
    print_error "Invalid choice. Exiting."
    exit 1
fi

echo ""
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s || true

echo ""
print_status "Checking deployment status..."
kubectl get pods -n monitoring

echo ""
echo "================================"
print_status "Deployment Summary"
echo "================================"
echo ""

echo "To access Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Or: kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  Then visit: http://localhost:3000"
echo "  Username: admin"
echo "  Password: $grafana_password"
echo ""

echo "To access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Or: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  Then visit: http://localhost:9090"
echo ""

echo "To expose via LoadBalancer (if supported):"
echo "  kubectl patch svc prometheus-grafana -n monitoring -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
echo ""

print_info "For more options, see the setup guide: prometheus-grafana-setup.md"

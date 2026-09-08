#!/bin/bash
set -e
set -o pipefail

echo "============================================"
echo "  Deploy cargo-tracker to Azure AKS"
echo "============================================"

# Prompt for Azure resource group
read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
  echo "ERROR: Resource group cannot be empty." >&2
  exit 1
fi

# Prompt for AKS cluster name
read -rp "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "${CLUSTER_NAME}" ]; then
  echo "ERROR: AKS cluster name cannot be empty." >&2
  exit 1
fi

# Prompt for Docker image URI
read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
  echo "ERROR: Image URI cannot be empty." >&2
  exit 1
fi

# Prompt for application environment variables
echo ""
echo "--- Application Configuration (press Enter to skip optional values) ---"

read -rp "Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/cargotracker): " DB_JDBC_URL
if [ -z "${DB_JDBC_URL}" ]; then
  DB_JDBC_URL="jdbc:postgresql://localhost:5432/cargotracker"
fi

read -rp "Enter DB_USER [postgres]: " DB_USER
if [ -z "${DB_USER}" ]; then
  DB_USER="postgres"
fi

read -rsp "Enter DB_PASSWORD: " DB_PASSWORD
echo ""
if [ -z "${DB_PASSWORD}" ]; then
  DB_PASSWORD="postgres"
fi

read -rp "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL
if [ -z "${GRAPH_TRAVERSAL_URL}" ]; then
  GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
fi

echo ""
echo "Configuring kubectl for AKS cluster: ${CLUSTER_NAME} in resource group: ${RESOURCE_GROUP} ..."
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials." >&2
  exit 1
fi

echo "Verifying cluster connectivity ..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster." >&2; exit 1; }

echo ""
echo "Updating Kubernetes manifests with provided values ..."

# Create working copies of manifests
cp kubernetes/deployment.yaml kubernetes/deployment.yaml.bak 2>/dev/null || true

# Replace placeholders using pipe delimiter
sed -i 's|{{IMAGE_URI}}|'"${IMAGE_URI}"'|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|'"${DB_JDBC_URL}"'|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}|'"${DB_USER}"'|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|'"${DB_PASSWORD}"'|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|'"${GRAPH_TRAVERSAL_URL}"'|g' kubernetes/deployment.yaml

echo ""
echo "Applying Kubernetes manifests ..."

echo "  [1/4] Applying namespace ..."
kubectl apply -f kubernetes/namespace.yaml

echo "  [2/4] Applying deployment ..."
kubectl apply -f kubernetes/deployment.yaml

echo "  [3/4] Applying service ..."
kubectl apply -f kubernetes/service.yaml

echo "  [4/4] Applying ingress ..."
kubectl apply -f kubernetes/ingress.yaml

echo ""
echo "Waiting for deployment rollout ..."
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Running rollback ..." >&2
  kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
  echo "Rollback initiated. Check pod status with: kubectl get pods -n cargo-tracker"
  exit 1
fi

echo ""
echo "Verifying deployed resources ..."
kubectl get pods,svc,ingress -n cargo-tracker

echo ""
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n cargo-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo "============================================"
echo "  Deployment Successful!"
echo "  Application URL: http://cargo-tracker.example.com"
if [ "${INGRESS_IP}" != "pending" ] && [ -n "${INGRESS_IP}" ]; then
  echo "  Ingress IP: ${INGRESS_IP}"
fi
echo "  Namespace: cargo-tracker"
echo "============================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n cargo-tracker"
echo "  kubectl logs -f deployment/cargo-tracker -n cargo-tracker"
echo "  kubectl rollout undo deployment/cargo-tracker -n cargo-tracker  # rollback"

#!/bin/bash
set -e
set -o pipefail

# ============================================================
# Deploy cargo-tracker to Azure AKS
# ============================================================

echo "============================================================"
echo "  Deploy cargo-tracker to Azure AKS"
echo "============================================================"
echo ""

# Prompt for Azure Resource Group
read -p "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
  echo "ERROR: Resource group cannot be empty."
  exit 1
fi

# Prompt for AKS Cluster Name
read -p "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "${CLUSTER_NAME}" ]; then
  echo "ERROR: AKS cluster name cannot be empty."
  exit 1
fi

# Prompt for Docker Image URI
read -p "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
  echo "ERROR: Docker image URI cannot be empty."
  exit 1
fi

echo ""
echo "------------------------------------------------------------"
echo "  Configuration:"
echo "  Resource Group : ${RESOURCE_GROUP}"
echo "  AKS Cluster    : ${CLUSTER_NAME}"
echo "  Image URI      : ${IMAGE_URI}"
echo "------------------------------------------------------------"
echo ""

# Prompt for application environment variables
echo "Configure application environment variables (press Enter to skip):"
echo ""

read -p "Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/cargotracker): " DB_JDBC_URL
if [ -z "${DB_JDBC_URL}" ]; then
  DB_JDBC_URL="jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"
fi

read -p "Enter DB_DRIVER_CLASS (e.g., org.postgresql.ds.PGPoolingDataSource): " DB_DRIVER_CLASS
if [ -z "${DB_DRIVER_CLASS}" ]; then
  DB_DRIVER_CLASS="org.h2.jdbcx.JdbcDataSource"
fi

read -p "Enter DB_USER: " DB_USER
if [ -z "${DB_USER}" ]; then
  DB_USER=""
fi

read -s -p "Enter DB_PASSWORD: " DB_PASSWORD
echo ""
if [ -z "${DB_PASSWORD}" ]; then
  DB_PASSWORD=""
fi

read -p "Enter GRAPH_TRAVERSAL_URL (press Enter for default): " GRAPH_TRAVERSAL_URL
if [ -z "${GRAPH_TRAVERSAL_URL}" ]; then
  GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
fi

echo ""
echo "Configuring kubectl for AKS cluster..."
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials."
  exit 1
fi

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }
echo ""

# Update Kubernetes manifests with actual values
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
cp -r kubernetes kubernetes_deploy_tmp

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" kubernetes_deploy_tmp/deployment.yaml
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" kubernetes_deploy_tmp/deployment.yaml
sed -i "s|{{DB_DRIVER_CLASS}}|${DB_DRIVER_CLASS}|g" kubernetes_deploy_tmp/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER}|g" kubernetes_deploy_tmp/deployment.yaml
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" kubernetes_deploy_tmp/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" kubernetes_deploy_tmp/deployment.yaml

echo "Manifests updated successfully."
echo ""

# Apply Kubernetes manifests in order
echo "Applying Kubernetes manifests..."
echo ""

echo "[1/4] Applying namespace..."
kubectl apply -f kubernetes_deploy_tmp/namespace.yaml
echo ""

echo "[2/4] Applying deployment..."
kubectl apply -f kubernetes_deploy_tmp/deployment.yaml
echo ""

echo "[3/4] Applying service..."
kubectl apply -f kubernetes_deploy_tmp/service.yaml
echo ""

echo "[4/4] Applying ingress..."
kubectl apply -f kubernetes_deploy_tmp/ingress.yaml
echo ""

# Clean up temporary manifests
rm -rf kubernetes_deploy_tmp

# Wait for deployment rollout
echo "Waiting for deployment rollout to complete..."
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed or timed out."
  echo "Run the following to check pod status:"
  echo "  kubectl get pods -n cargo-tracker"
  echo "  kubectl describe pods -n cargo-tracker"
  echo ""
  echo "To rollback:"
  echo "  kubectl rollout undo deployment/cargo-tracker -n cargo-tracker"
  exit 1
fi

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n cargo-tracker
echo ""

# Display application URL
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n cargo-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n cargo-tracker -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo "============================================================"
echo "  DEPLOYMENT SUCCESSFUL!"
echo "============================================================"
echo ""
if [ -n "${INGRESS_IP}" ]; then
  echo "  Application URL : http://${INGRESS_IP}/cargo-tracker"
fi
echo "  Ingress Host    : http://${INGRESS_HOST}/cargo-tracker"
echo ""
echo "  To check pod logs:"
echo "    kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=100"
echo ""
echo "  To rollback if needed:"
echo "    kubectl rollout undo deployment/cargo-tracker -n cargo-tracker"
echo "============================================================"

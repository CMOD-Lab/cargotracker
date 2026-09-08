#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to Azure AKS
# ============================================================

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "============================================"
echo " Deploy to Azure AKS - ${APP_NAME}"
echo "============================================"
echo ""

# ---- Prompt for Azure details ----
read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "$RESOURCE_GROUP" ]; then
  echo "ERROR: Resource group cannot be empty."
  exit 1
fi

read -rp "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: AKS cluster name cannot be empty."
  exit 1
fi

read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Image URI cannot be empty."
  exit 1
fi

echo ""
echo "---- Application Configuration ----"
read -rp "Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/postgres) [required]: " DB_JDBC_URL
if [ -z "$DB_JDBC_URL" ]; then
  DB_JDBC_URL="jdbc:postgresql://localhost:5432/postgres"
  echo "Using default: ${DB_JDBC_URL}"
fi

read -rp "Enter DB_USERNAME (press Enter to skip): " DB_USERNAME
if [ -z "$DB_USERNAME" ]; then
  DB_USERNAME="postgres"
fi

read -rsp "Enter DB_PASSWORD (press Enter to skip): " DB_PASSWORD
echo ""
if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD="postgres"
fi

read -rp "Enter GRAPH_TRAVERSAL_URL (press Enter for default): " GRAPH_TRAVERSAL_URL
if [ -z "$GRAPH_TRAVERSAL_URL" ]; then
  GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
fi

echo ""
echo "---- Configuring kubectl for AKS ----"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials. Check resource group and cluster name."
  exit 1
fi

echo ""
echo "---- Verifying cluster connectivity ----"
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }

echo ""
echo "---- Updating Kubernetes manifests ----"
MANIFESTS_DIR="${PROJECT_ROOT}/kubernetes"

# Create working copies of manifests
cp "${MANIFESTS_DIR}/deployment.yaml" "${MANIFESTS_DIR}/deployment.yaml.bak"

# Replace placeholders using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${MANIFESTS_DIR}/deployment.yaml"
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" "${MANIFESTS_DIR}/deployment.yaml"
sed -i "s|{{DB_USERNAME}}|${DB_USERNAME}|g" "${MANIFESTS_DIR}/deployment.yaml"
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" "${MANIFESTS_DIR}/deployment.yaml"
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" "${MANIFESTS_DIR}/deployment.yaml"

echo "Manifests updated successfully."

echo ""
echo "---- Applying Kubernetes manifests ----"

echo "Applying namespace..."
kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"

echo "Applying deployment..."
kubectl apply -f "${MANIFESTS_DIR}/deployment.yaml"

echo "Applying service..."
kubectl apply -f "${MANIFESTS_DIR}/service.yaml"

echo "Applying ingress..."
kubectl apply -f "${MANIFESTS_DIR}/ingress.yaml"

echo ""
echo "---- Waiting for deployment rollout ----"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed or timed out."
  echo "To rollback, run: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  # Restore original manifest
  mv "${MANIFESTS_DIR}/deployment.yaml.bak" "${MANIFESTS_DIR}/deployment.yaml"
  exit 1
fi

# Restore original manifest (with placeholders) after successful deployment
mv "${MANIFESTS_DIR}/deployment.yaml.bak" "${MANIFESTS_DIR}/deployment.yaml"

echo ""
echo "---- Verifying deployed resources ----"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "---- Application Access ----"
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo "Ingress IP   : ${INGRESS_IP}"
echo "Ingress Host : ${INGRESS_HOST}"
echo "Application  : http://${INGRESS_HOST}/"
echo ""
echo "============================================"
echo " SUCCESS: ${APP_NAME} deployed to AKS!"
echo "============================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # rollback"

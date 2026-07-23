#!/bin/bash
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"

echo "============================================"
echo "  Deploy ${APP_NAME} to Azure AKS"
echo "============================================"
echo ""

# Prompt for Azure resource group
read -p "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
  echo "ERROR: Resource group cannot be empty."
  exit 1
fi

# Prompt for AKS cluster name
read -p "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "${CLUSTER_NAME}" ]; then
  echo "ERROR: AKS cluster name cannot be empty."
  exit 1
fi

# Prompt for Docker image URI
read -p "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
  echo "ERROR: Docker image URI cannot be empty."
  exit 1
fi

# Prompt for application-specific environment variables
echo ""
echo "--- Application Configuration (press Enter to skip optional values) ---"
read -p "Enter GRAPH_TRAVERSAL_URL (default: http://localhost:8080/rest/graph-traversal/shortest-path): " GRAPH_TRAVERSAL_URL
if [ -z "${GRAPH_TRAVERSAL_URL}" ]; then
  GRAPH_TRAVERSAL_URL="http://localhost:8080/rest/graph-traversal/shortest-path"
fi

read -p "Enter DB_JDBC_URL (default: jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database): " DB_JDBC_URL
if [ -z "${DB_JDBC_URL}" ]; then
  DB_JDBC_URL="jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"
fi

read -p "Enter DB_USER (or press Enter to skip): " DB_USER
read -s -p "Enter DB_PASSWORD (or press Enter to skip): " DB_PASSWORD
echo ""

echo ""
echo "--- Configuring kubectl for AKS ---"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials."
  exit 1
fi

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }

echo ""
echo "--- Updating Kubernetes manifests ---"
# Replace placeholders in deployment.yaml using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" kubernetes/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" kubernetes/deployment.yaml
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" kubernetes/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER}|g" kubernetes/deployment.yaml

echo ""
echo "--- Applying Kubernetes manifests ---"
echo "Applying namespace..."
kubectl apply -f kubernetes/namespace.yaml

echo "Applying deployment..."
kubectl apply -f kubernetes/deployment.yaml

echo "Applying service..."
kubectl apply -f kubernetes/service.yaml

echo "Applying ingress..."
kubectl apply -f kubernetes/ingress.yaml

echo ""
echo "--- Waiting for deployment rollout ---"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Check pod logs:"
  kubectl get pods -n ${NAMESPACE}
  kubectl describe deployment/${APP_NAME} -n ${NAMESPACE}
  echo ""
  echo "To rollback: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
fi

echo ""
echo "--- Verifying deployed resources ---"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "--- Application Access ---"
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "${INGRESS_IP}" != "pending" ] && [ -n "${INGRESS_IP}" ]; then
  echo "Application URL: http://${INGRESS_IP}/"
else
  echo "Ingress IP is still being assigned. Run the following to check:"
  echo "  kubectl get ingress -n ${NAMESPACE}"
fi

echo ""
echo "============================================"
echo "  Deployment Completed Successfully!"
echo "  App: ${APP_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo "============================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # rollback"

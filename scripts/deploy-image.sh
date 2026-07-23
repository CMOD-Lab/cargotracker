#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to Azure AKS
# ============================================================

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
MANIFESTS_DIR="kubernetes"

echo "=============================================="
echo "  cargo-tracker - Azure AKS Deployment Script"
echo "=============================================="
echo ""

# Prompt for Azure resource group
read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "$RESOURCE_GROUP" ]; then
  echo "ERROR: Resource group cannot be empty."
  exit 1
fi

# Prompt for AKS cluster name
read -rp "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: AKS cluster name cannot be empty."
  exit 1
fi

# Prompt for Docker image URI
read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Image URI cannot be empty."
  exit 1
fi

echo ""
echo "--- Application Configuration ---"
echo "Provide values for environment variables (press Enter to use placeholder):"
echo ""

read -rp "Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/cargotracker): " DB_JDBC_URL_VAL
DB_JDBC_URL_VAL="${DB_JDBC_URL_VAL:-jdbc:postgresql://postgres-service:5432/cargotracker}"

read -rp "Enter DB_USER [postgres]: " DB_USER_VAL
DB_USER_VAL="${DB_USER_VAL:-postgres}"

read -rsp "Enter DB_PASSWORD: " DB_PASSWORD_VAL
echo ""
DB_PASSWORD_VAL="${DB_PASSWORD_VAL:-changeme}"

read -rp "Enter GRAPH_TRAVERSAL_URL [http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL_VAL
GRAPH_TRAVERSAL_URL_VAL="${GRAPH_TRAVERSAL_URL_VAL:-http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path}"

echo ""
echo "--- Configuring kubectl for AKS ---"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials."
  exit 1
fi

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }

echo ""
echo "--- Updating Kubernetes manifests ---"

# Create a working copy of manifests
cp -r "${MANIFESTS_DIR}" /tmp/cargo-tracker-manifests

# Replace placeholders using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" /tmp/cargo-tracker-manifests/deployment.yaml
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL_VAL}|g" /tmp/cargo-tracker-manifests/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER_VAL}|g" /tmp/cargo-tracker-manifests/deployment.yaml
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD_VAL}|g" /tmp/cargo-tracker-manifests/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL_VAL}|g" /tmp/cargo-tracker-manifests/deployment.yaml

echo ""
echo "--- Applying Kubernetes manifests ---"

echo "Applying namespace..."
kubectl apply -f /tmp/cargo-tracker-manifests/namespace.yaml

echo "Applying deployment..."
kubectl apply -f /tmp/cargo-tracker-manifests/deployment.yaml

echo "Applying service..."
kubectl apply -f /tmp/cargo-tracker-manifests/service.yaml

echo "Applying ingress..."
kubectl apply -f /tmp/cargo-tracker-manifests/ingress.yaml

echo ""
echo "--- Waiting for deployment rollout ---"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Rolling back..."
  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}
  echo "Rollback initiated. Check pod status:"
  kubectl get pods -n ${NAMESPACE}
  exit 1
fi

echo ""
echo "--- Verifying deployed resources ---"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "--- Application Access ---"
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo ""
echo "=============================================="
echo "  DEPLOYMENT SUCCESSFUL!"
echo "=============================================="
echo ""
echo "  Application: ${APP_NAME}"
echo "  Namespace:   ${NAMESPACE}"
echo "  Image:       ${IMAGE_URI}"
echo ""
echo "  Ingress Host: ${INGRESS_HOST}"
if [ "${INGRESS_IP}" != "pending" ] && [ -n "${INGRESS_IP}" ]; then
  echo "  Ingress IP:   ${INGRESS_IP}"
  echo "  Access URL:   http://${INGRESS_IP}/"
else
  echo "  Ingress IP:   (pending - may take a few minutes)"
  echo "  Access URL:   http://${INGRESS_HOST}/"
fi
echo ""
echo "  To check pod logs:"
echo "    kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} --tail=100"
echo ""
echo "  To rollback if needed:"
echo "    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo ""

# Cleanup temp manifests
rm -rf /tmp/cargo-tracker-manifests

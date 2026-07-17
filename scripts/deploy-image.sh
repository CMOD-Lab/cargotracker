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
echo "  Deploy ${APP_NAME} to Azure AKS"
echo "=============================================="

# ---- Prompt for Azure details ----
read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
  echo "ERROR: Resource group cannot be empty."
  exit 1
fi

read -rp "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "${CLUSTER_NAME}" ]; then
  echo "ERROR: AKS cluster name cannot be empty."
  exit 1
fi

read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
  echo "ERROR: Image URI cannot be empty."
  exit 1
fi

echo ""
echo "---- Application Environment Variables ----"
read -rp "Enter POSTGRESQL_JDBC_URL (or press Enter to skip): " POSTGRESQL_JDBC_URL
read -rp "Enter POSTGRESQL_USERNAME (or press Enter to skip): " POSTGRESQL_USERNAME
read -rsp "Enter POSTGRESQL_PASSWORD (or press Enter to skip): " POSTGRESQL_PASSWORD
echo ""

# ---- Configure kubectl for AKS ----
echo ""
echo "Configuring kubectl for AKS cluster: ${CLUSTER_NAME}..."
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
echo "kubectl configured successfully."

# ---- Verify cluster connectivity ----
echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }

# ---- Update manifests with actual values ----
echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Create a working copy of manifests
WORK_DIR=$(mktemp -d)
cp -r "${MANIFESTS_DIR}"/* "${WORK_DIR}/"

# Replace IMAGE_URI placeholder
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${WORK_DIR}/deployment.yaml"

# Replace environment variable placeholders
if [ -n "${POSTGRESQL_JDBC_URL}" ]; then
  sed -i "s|{{POSTGRESQL_JDBC_URL}}|${POSTGRESQL_JDBC_URL}|g" "${WORK_DIR}/deployment.yaml"
else
  sed -i "s|{{POSTGRESQL_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g" "${WORK_DIR}/deployment.yaml"
fi

if [ -n "${POSTGRESQL_USERNAME}" ]; then
  sed -i "s|{{POSTGRESQL_USERNAME}}|${POSTGRESQL_USERNAME}|g" "${WORK_DIR}/deployment.yaml"
else
  sed -i "s|{{POSTGRESQL_USERNAME}}||g" "${WORK_DIR}/deployment.yaml"
fi

if [ -n "${POSTGRESQL_PASSWORD}" ]; then
  sed -i "s|{{POSTGRESQL_PASSWORD}}|${POSTGRESQL_PASSWORD}|g" "${WORK_DIR}/deployment.yaml"
else
  sed -i "s|{{POSTGRESQL_PASSWORD}}||g" "${WORK_DIR}/deployment.yaml"
fi

echo "Manifests updated."

# ---- Apply Kubernetes manifests ----
echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f "${WORK_DIR}/namespace.yaml"

echo "  [2/4] Applying deployment..."
kubectl apply -f "${WORK_DIR}/deployment.yaml"

echo "  [3/4] Applying service..."
kubectl apply -f "${WORK_DIR}/service.yaml"

echo "  [4/4] Applying ingress..."
kubectl apply -f "${WORK_DIR}/ingress.yaml"

# ---- Wait for rollout ----
echo ""
echo "Waiting for deployment rollout to complete..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s

# ---- Verify resources ----
echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n ${NAMESPACE}

# ---- Display application URL ----
echo ""
echo "Fetching application ingress URL..."
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
if [ -n "${INGRESS_HOST}" ]; then
  echo "Application URL: http://${INGRESS_HOST}/"
else
  echo "Ingress host not yet assigned. Check: kubectl get ingress -n ${NAMESPACE}"
fi

# ---- Cleanup temp dir ----
rm -rf "${WORK_DIR}"

echo ""
echo "=============================================="
echo "  Deployment complete!"
echo "  App: ${APP_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo "  Image: ${IMAGE_URI}"
echo "=============================================="
echo ""
echo "Rollback command (if needed):"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"

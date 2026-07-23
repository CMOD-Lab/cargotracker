#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy Eclipse Cargo Tracker to Azure AKS
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="${PROJECT_ROOT}/kubernetes"
APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"

echo "============================================================"
echo "  Eclipse Cargo Tracker - Deploy to Azure AKS"
echo "============================================================"
echo ""

# ---- Validate prerequisites ----
echo "Checking prerequisites ..."
command -v az >/dev/null 2>&1 || { echo "ERROR: Azure CLI (az) is not installed. Please install it first."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed. Please install it first."; exit 1; }
echo "Prerequisites OK."
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

# ---- Prompt for Docker image URI ----
echo ""
read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Image URI cannot be empty."
  exit 1
fi

# ---- Prompt for application environment variables ----
echo ""
echo "------------------------------------------------------------"
echo "  Application Configuration (press Enter to use defaults)"
echo "------------------------------------------------------------"

read -rp "Enter POSTGRES_HOST [localhost]: " POSTGRES_HOST_INPUT
POSTGRES_HOST="${POSTGRES_HOST_INPUT:-localhost}"

read -rp "Enter POSTGRES_PORT [5432]: " POSTGRES_PORT_INPUT
POSTGRES_PORT="${POSTGRES_PORT_INPUT:-5432}"

read -rp "Enter POSTGRES_DB [cargotracker]: " POSTGRES_DB_INPUT
POSTGRES_DB="${POSTGRES_DB_INPUT:-cargotracker}"

read -rp "Enter POSTGRES_USER [postgres]: " POSTGRES_USER_INPUT
POSTGRES_USER="${POSTGRES_USER_INPUT:-postgres}"

read -rsp "Enter POSTGRES_PASSWORD [postgres]: " POSTGRES_PASSWORD_INPUT
echo ""
POSTGRES_PASSWORD="${POSTGRES_PASSWORD_INPUT:-postgres}"

# ---- Configure kubectl for AKS ----
echo ""
echo "Configuring kubectl for AKS cluster: ${CLUSTER_NAME} ..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to get AKS credentials. Check resource group and cluster name."
  exit 1
fi

# ---- Verify cluster connectivity ----
echo ""
echo "Verifying cluster connectivity ..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }
echo ""

# ---- Update Kubernetes manifests with actual values ----
echo "Updating Kubernetes manifests with deployment values ..."

# Create temporary copies of manifests to avoid modifying originals
TMP_DIR=$(mktemp -d)
cp "${K8S_DIR}"/*.yaml "${TMP_DIR}/"

# Replace placeholders using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g"                   "${TMP_DIR}/deployment.yaml"
sed -i "s|{{POSTGRES_HOST}}|${POSTGRES_HOST}|g"           "${TMP_DIR}/deployment.yaml"
sed -i "s|{{POSTGRES_PORT}}|${POSTGRES_PORT}|g"           "${TMP_DIR}/deployment.yaml"
sed -i "s|{{POSTGRES_DB}}|${POSTGRES_DB}|g"               "${TMP_DIR}/deployment.yaml"
sed -i "s|{{POSTGRES_USER}}|${POSTGRES_USER}|g"           "${TMP_DIR}/deployment.yaml"
sed -i "s|{{POSTGRES_PASSWORD}}|${POSTGRES_PASSWORD}|g"   "${TMP_DIR}/deployment.yaml"

echo "Manifests updated successfully."
echo ""

# ---- Apply Kubernetes manifests in order ----
echo "Applying Kubernetes manifests ..."

echo "  [1/4] Applying namespace ..."
kubectl apply -f "${TMP_DIR}/namespace.yaml"

echo "  [2/4] Applying deployment ..."
kubectl apply -f "${TMP_DIR}/deployment.yaml"

echo "  [3/4] Applying service ..."
kubectl apply -f "${TMP_DIR}/service.yaml"

echo "  [4/4] Applying ingress ..."
kubectl apply -f "${TMP_DIR}/ingress.yaml"

echo ""
echo "All manifests applied successfully."

# ---- Wait for deployment rollout ----
echo ""
echo "Waiting for deployment rollout to complete ..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: Deployment rollout did not complete within timeout."
  echo "To rollback, run: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
fi

# ---- Verify deployed resources ----
echo ""
echo "------------------------------------------------------------"
echo "  Deployed Resources in namespace: ${NAMESPACE}"
echo "------------------------------------------------------------"
kubectl get pods,svc,ingress -n ${NAMESPACE}

# ---- Display application URL ----
echo ""
echo "------------------------------------------------------------"
echo "  Application Access Information"
echo "------------------------------------------------------------"
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "  Application URL : http://${INGRESS_HOST}/cargo-tracker"
echo "  Ingress IP      : ${INGRESS_IP}"
echo ""
echo "  Note: If Ingress IP is 'pending', wait a few minutes for Azure Application Gateway to provision."
echo "        Run: kubectl get ingress -n ${NAMESPACE} --watch"
echo ""

# ---- Cleanup temp files ----
rm -rf "${TMP_DIR}"

echo "============================================================"
echo "  SUCCESS: Eclipse Cargo Tracker deployed to AKS!"
echo "============================================================"
echo ""
echo "Useful commands:"
echo "  View pods    : kubectl get pods -n ${NAMESPACE}"
echo "  View logs    : kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  Rollback     : kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  Scale        : kubectl scale deployment/${APP_NAME} --replicas=3 -n ${NAMESPACE}"

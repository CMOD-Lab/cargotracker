#!/bin/bash
# =============================================================================
# deploy-image.sh  –  Deploy cargo-tracker to Azure AKS
# Prerequisites   : azure-cli, kubectl
# Usage           : bash scripts/deploy-image.sh
# =============================================================================
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
K8S_DIR="kubernetes"

echo "=============================================="
echo "  Eclipse Cargo Tracker – AKS Deployment"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# Collect Azure / AKS details
# ---------------------------------------------------------------------------
read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
    echo "ERROR: Resource group cannot be empty." >&2
    exit 1
fi

read -rp "Enter AKS Cluster name: " CLUSTER_NAME
if [ -z "${CLUSTER_NAME}" ]; then
    echo "ERROR: AKS cluster name cannot be empty." >&2
    exit 1
fi

read -rp "Enter full Docker image URI (e.g. myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "${IMAGE_URI}" ]; then
    echo "ERROR: Image URI cannot be empty." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Collect optional application environment variables
# ---------------------------------------------------------------------------
echo ""
echo "--- Application Configuration (press Enter to use defaults) ---"

read -rp "Enter DB_DRIVER_CLASS [org.h2.jdbcx.JdbcDataSource]: " DB_DRIVER_CLASS
DB_DRIVER_CLASS="${DB_DRIVER_CLASS:-org.h2.jdbcx.JdbcDataSource}"

read -rp "Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: " DB_JDBC_URL
DB_JDBC_URL="${DB_JDBC_URL:-jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database}"

read -rp "Enter DB_USER []: " DB_USER
DB_USER="${DB_USER:-}"

read -rsp "Enter DB_PASSWORD []: " DB_PASSWORD
echo ""
DB_PASSWORD="${DB_PASSWORD:-}"

read -rp "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL:-http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path}"

# ---------------------------------------------------------------------------
# Configure kubectl for AKS
# ---------------------------------------------------------------------------
echo ""
echo "Configuring kubectl for AKS cluster '${CLUSTER_NAME}' ..."
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get AKS credentials." >&2
    exit 1
fi

echo "Verifying cluster connectivity ..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Substitute placeholders in Kubernetes manifests (working copies)
# ---------------------------------------------------------------------------
echo ""
echo "Preparing Kubernetes manifests ..."

# Create temporary working copies
TMP_DIR=$(mktemp -d)
cp -r "${K8S_DIR}"/* "${TMP_DIR}/"

# Replace IMAGE_URI
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${TMP_DIR}/deployment.yaml"

# Replace application environment variable placeholders
sed -i "s|{{DB_DRIVER_CLASS}}|${DB_DRIVER_CLASS}|g"       "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g"               "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_USER}}|${DB_USER}|g"                       "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g"               "${TMP_DIR}/deployment.yaml"
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" "${TMP_DIR}/deployment.yaml"

# ---------------------------------------------------------------------------
# Apply manifests in order
# ---------------------------------------------------------------------------
echo ""
echo "Applying Kubernetes manifests ..."

echo "  [1/4] Applying namespace ..."
kubectl apply -f "${TMP_DIR}/namespace.yaml"

echo "  [2/4] Applying deployment ..."
kubectl apply -f "${TMP_DIR}/deployment.yaml"

echo "  [3/4] Applying service ..."
kubectl apply -f "${TMP_DIR}/service.yaml"

echo "  [4/4] Applying ingress ..."
kubectl apply -f "${TMP_DIR}/ingress.yaml"

# Clean up temp files
rm -rf "${TMP_DIR}"

# ---------------------------------------------------------------------------
# Wait for rollout
# ---------------------------------------------------------------------------
echo ""
echo "Waiting for deployment rollout ..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
    echo ""
    echo "WARNING: Rollout did not complete within timeout. Checking pod status ..."
    kubectl get pods -n ${NAMESPACE}
    echo ""
    echo "To rollback, run:"
    echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Verify resources
# ---------------------------------------------------------------------------
echo ""
echo "Verifying deployed resources ..."
kubectl get pods,svc,ingress -n ${NAMESPACE}

# ---------------------------------------------------------------------------
# Display access URL
# ---------------------------------------------------------------------------
echo ""
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo ""
echo "  Application URL : http://${INGRESS_HOST}/"
if [ -n "${INGRESS_IP}" ]; then
    echo "  Ingress IP      : ${INGRESS_IP}"
fi
echo ""
echo "  Health Check    : http://${INGRESS_HOST}/cargo-tracker/rest/health"
echo ""
echo "  To check pods   : kubectl get pods -n ${NAMESPACE}"
echo "  To view logs    : kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} --tail=100"
echo "  To rollback     : kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "=============================================="

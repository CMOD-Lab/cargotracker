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
echo "Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "ERROR: Azure CLI (az) is not installed. Install from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
echo "  [OK] Azure CLI found"
echo "  [OK] kubectl found"
echo ""

# ---- Prompt for inputs ----
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
echo "---- Optional Environment Configuration ----"
echo "Press Enter to skip any value and use defaults."
echo ""

read -rp "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL_INPUT
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL_INPUT:-http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path}"

read -rp "Enter DB_DRIVER_CLASS [org.h2.jdbcx.JdbcDataSource]: " DB_DRIVER_CLASS_INPUT
DB_DRIVER_CLASS="${DB_DRIVER_CLASS_INPUT:-org.h2.jdbcx.JdbcDataSource}"

read -rp "Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: " DB_JDBC_URL_INPUT
DB_JDBC_URL="${DB_JDBC_URL_INPUT:-jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database}"

echo ""
echo "============================================================"
echo "  Deployment Configuration:"
echo "  Resource Group : ${RESOURCE_GROUP}"
echo "  AKS Cluster    : ${CLUSTER_NAME}"
echo "  Image URI      : ${IMAGE_URI}"
echo "  Namespace      : ${NAMESPACE}"
echo "============================================================"
echo ""

# ---- Configure kubectl for AKS ----
echo "Configuring kubectl for AKS cluster: ${CLUSTER_NAME} ..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
echo "  [OK] kubectl configured"
echo ""

# ---- Verify cluster connectivity ----
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster. Check credentials and cluster status."; exit 1; }
echo "  [OK] Cluster is reachable"
echo ""

# ---- Prepare manifest copies ----
DEPLOY_DIR=$(mktemp -d)
cp -r "${K8S_DIR}/." "${DEPLOY_DIR}/"
echo "Working manifests copied to: ${DEPLOY_DIR}"

# ---- Replace placeholders in manifests ----
echo "Updating manifests with deployment values..."

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{DB_DRIVER_CLASS}}|${DB_DRIVER_CLASS}|g" "${DEPLOY_DIR}/deployment.yaml"
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" "${DEPLOY_DIR}/deployment.yaml"

echo "  [OK] Placeholders replaced"
echo ""

# ---- Apply Kubernetes manifests ----
echo "Applying Kubernetes manifests..."

echo "  Applying namespace..."
kubectl apply -f "${DEPLOY_DIR}/namespace.yaml"

echo "  Applying deployment..."
kubectl apply -f "${DEPLOY_DIR}/deployment.yaml"

echo "  Applying service..."
kubectl apply -f "${DEPLOY_DIR}/service.yaml"

echo "  Applying ingress..."
kubectl apply -f "${DEPLOY_DIR}/ingress.yaml"

echo "  [OK] All manifests applied"
echo ""

# ---- Wait for rollout ----
echo "Waiting for deployment rollout (this may take several minutes for JVM startup)..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo ""
  echo "ERROR: Deployment rollout failed or timed out."
  echo "Run the following to investigate:"
  echo "  kubectl describe pods -n ${NAMESPACE}"
  echo "  kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} --tail=50"
  echo ""
  echo "To rollback:"
  echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
fi

echo "  [OK] Deployment rollout complete"
echo ""

# ---- Verify resources ----
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n ${NAMESPACE}
echo ""

# ---- Display access URL ----
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo "============================================================"
echo "  DEPLOYMENT SUCCESSFUL!"
echo "============================================================"
echo ""
if [ -n "$INGRESS_IP" ]; then
  echo "  Application URL : http://${INGRESS_IP}/cargo-tracker"
fi
echo "  Ingress Host    : http://${INGRESS_HOST}/cargo-tracker"
echo "  Health Check    : http://${INGRESS_HOST}/cargo-tracker/rest/health"
echo ""
echo "  Useful commands:"
echo "    kubectl get pods -n ${NAMESPACE}"
echo "    kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} -f"
echo "    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # rollback"
echo ""

# ---- Cleanup temp dir ----
rm -rf "${DEPLOY_DIR}"

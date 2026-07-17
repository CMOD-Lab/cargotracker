#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to GCP GKE
# Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="${PROJECT_ROOT}/kubernetes"
APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"

echo "============================================================"
echo "  Eclipse Cargo Tracker - GKE Deployment"
echo "============================================================"
echo ""

# ---- Prompt for GCP configuration ----
read -p "Enter GCP Project ID: " GCP_PROJECT
if [ -z "$GCP_PROJECT" ]; then
    echo "ERROR: GCP Project ID is required."
    exit 1
fi

read -p "Enter GCP Zone (e.g. us-central1-a): " GCP_ZONE
if [ -z "$GCP_ZONE" ]; then
    echo "ERROR: GCP Zone is required."
    exit 1
fi

read -p "Enter GKE Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
    echo "ERROR: GKE Cluster Name is required."
    exit 1
fi

read -p "Enter full Docker image URI (e.g. us-central1-docker.pkg.dev/my-project/repo/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
    echo "ERROR: Docker image URI is required."
    exit 1
fi

echo ""
echo "--- Optional Application Configuration ---"
echo "(Press Enter to skip any value and use the default)"
echo ""

read -p "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL:-http://localhost:8080/rest/graph-traversal/shortest-path}"

read -p "Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: " DB_JDBC_URL
DB_JDBC_URL="${DB_JDBC_URL:-jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database}"

read -p "Enter DB_USER []: " DB_USER
DB_USER="${DB_USER:-}"

read -p "Enter DB_PASSWORD []: " DB_PASSWORD
DB_PASSWORD="${DB_PASSWORD:-}"

echo ""
echo "============================================================"
echo "  Deployment Summary"
echo "  GCP Project : ${GCP_PROJECT}"
echo "  GCP Zone    : ${GCP_ZONE}"
echo "  Cluster     : ${CLUSTER_NAME}"
echo "  Image       : ${IMAGE_URI}"
echo "  Namespace   : ${NAMESPACE}"
echo "============================================================"
echo ""

# ---- Configure kubectl for GKE ----
echo "Configuring kubectl for GKE cluster..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${GCP_ZONE}" \
    --project "${GCP_PROJECT}"

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to cluster."; exit 1; }

# ---- Update Kubernetes manifests with actual values ----
echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
TMP_DIR=$(mktemp -d)
cp "${K8S_DIR}"/*.yaml "${TMP_DIR}/"

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${TMP_DIR}/deployment.yaml"
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_USER}}|${DB_USER}|g" "${TMP_DIR}/deployment.yaml"
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" "${TMP_DIR}/deployment.yaml"

# ---- Apply manifests in order ----
echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f "${TMP_DIR}/namespace.yaml"

echo "  [2/4] Applying deployment..."
kubectl apply -f "${TMP_DIR}/deployment.yaml"

echo "  [3/4] Applying service..."
kubectl apply -f "${TMP_DIR}/service.yaml"

echo "  [4/4] Applying ingress..."
kubectl apply -f "${TMP_DIR}/ingress.yaml"

# ---- Wait for rollout ----
echo ""
echo "Waiting for deployment rollout..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
    echo "ERROR: Deployment rollout failed. Running rollback..."
    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}
    echo "Rollback initiated. Check pod status:"
    kubectl get pods -n ${NAMESPACE}
    rm -rf "${TMP_DIR}"
    exit 1
fi

# ---- Verify resources ----
echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n ${NAMESPACE}

# ---- Display access URL ----
echo ""
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "============================================================"
echo "  DEPLOYMENT SUCCESSFUL!"
echo "  Application: ${APP_NAME}"
echo "  Namespace  : ${NAMESPACE}"
echo "  Image      : ${IMAGE_URI}"
if [ "$INGRESS_IP" != "pending" ] && [ -n "$INGRESS_IP" ]; then
    echo "  Access URL : http://${INGRESS_IP}/"
else
    echo "  Ingress IP : (pending - run 'kubectl get ingress -n ${NAMESPACE}' to check)"
fi
echo "============================================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl describe deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # rollback"

# Cleanup temp files
rm -rf "${TMP_DIR}"

#!/bin/bash
# =============================================================================
# deploy-image.sh - Deploy Eclipse Cargo Tracker to GCP GKE
# Target Platform: GCP GKE (Google Kubernetes Engine)
# =============================================================================
set -e
set -o pipefail

NAMESPACE="cargo-tracker"
APP_NAME="cargo-tracker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo " Eclipse Cargo Tracker - GKE Deploy Script"
echo "=============================================="
echo ""

# -------------------------------------------------------
# Prompt for GCP configuration
# -------------------------------------------------------
read -p "Enter GCP Project ID: " GCP_PROJECT
if [ -z "$GCP_PROJECT" ]; then
    echo "ERROR: GCP Project ID cannot be empty."
    exit 1
fi

read -p "Enter GCP Zone (e.g., us-central1-a): " GCP_ZONE
if [ -z "$GCP_ZONE" ]; then
    echo "ERROR: GCP Zone cannot be empty."
    exit 1
fi

read -p "Enter GKE Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
    echo "ERROR: GKE Cluster Name cannot be empty."
    exit 1
fi

read -p "Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
    echo "ERROR: Docker image URI cannot be empty."
    exit 1
fi

# -------------------------------------------------------
# Prompt for application environment variables
# -------------------------------------------------------
echo ""
echo "--- Application Environment Variables ---"
echo "(Press Enter to skip optional values)"
echo ""

read -p "Enter DB_HOST (PostgreSQL host, e.g., 10.0.0.1 or Cloud SQL IP): " DB_HOST
DB_HOST="${DB_HOST:-localhost}"

read -p "Enter DB_PORT [default: 5432]: " DB_PORT
DB_PORT="${DB_PORT:-5432}"

read -p "Enter DB_NAME [default: postgres]: " DB_NAME
DB_NAME="${DB_NAME:-postgres}"

read -p "Enter DB_USER [default: postgres]: " DB_USER
DB_USER="${DB_USER:-postgres}"

read -sp "Enter DB_PASSWORD: " DB_PASSWORD
echo ""
DB_PASSWORD="${DB_PASSWORD:-postgres}"

read -p "Enter GRAPH_TRAVERSAL_URL [default: http://localhost:8080/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL:-http://localhost:8080/rest/graph-traversal/shortest-path}"

# -------------------------------------------------------
# Configure kubectl for GKE
# -------------------------------------------------------
echo ""
echo "Configuring kubectl for GKE cluster: ${CLUSTER_NAME}..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get GKE cluster credentials."
    exit 1
fi

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to Kubernetes cluster."; exit 1; }

# -------------------------------------------------------
# Update Kubernetes manifests with actual values
# -------------------------------------------------------
echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
cp -r "${PROJECT_ROOT}/kubernetes" /tmp/cargo-tracker-k8s

# Replace IMAGE_URI placeholder
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" /tmp/cargo-tracker-k8s/deployment.yaml

# Replace database and application environment variable placeholders
sed -i "s|{{DB_HOST}}|${DB_HOST}|g"                           /tmp/cargo-tracker-k8s/deployment.yaml
sed -i "s|{{DB_PORT}}|${DB_PORT}|g"                           /tmp/cargo-tracker-k8s/deployment.yaml
sed -i "s|{{DB_NAME}}|${DB_NAME}|g"                           /tmp/cargo-tracker-k8s/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER}|g"                           /tmp/cargo-tracker-k8s/deployment.yaml
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g"                   /tmp/cargo-tracker-k8s/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g"   /tmp/cargo-tracker-k8s/deployment.yaml

# -------------------------------------------------------
# Apply Kubernetes manifests in order
# -------------------------------------------------------
echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f /tmp/cargo-tracker-k8s/namespace.yaml

echo "  [2/4] Applying deployment..."
kubectl apply -f /tmp/cargo-tracker-k8s/deployment.yaml

echo "  [3/4] Applying service..."
kubectl apply -f /tmp/cargo-tracker-k8s/service.yaml

echo "  [4/4] Applying ingress..."
kubectl apply -f /tmp/cargo-tracker-k8s/ingress.yaml

# -------------------------------------------------------
# Wait for rollout
# -------------------------------------------------------
echo ""
echo "Waiting for deployment rollout to complete..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Deployment rollout failed or timed out."
    echo "To rollback, run: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
    exit 1
fi

# -------------------------------------------------------
# Verify deployment
# -------------------------------------------------------
echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n ${NAMESPACE}

# -------------------------------------------------------
# Display access information
# -------------------------------------------------------
echo ""
echo "Fetching application access URL..."
INGRESS_IP=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$INGRESS_IP" ]; then
    echo ""
    echo "=============================================="
    echo " SUCCESS: Deployment complete!"
    echo " Application URL: http://${INGRESS_IP}/"
    echo " Health Check:    http://${INGRESS_IP}/rest/health"
    echo "=============================================="
else
    echo ""
    echo "=============================================="
    echo " SUCCESS: Deployment complete!"
    echo " Note: Ingress IP is still being provisioned."
    echo " Run: kubectl get ingress -n ${NAMESPACE}"
    echo " to check the external IP once assigned."
    echo "=============================================="
fi

echo ""
echo "Useful commands:"
echo "  View pods:     kubectl get pods -n ${NAMESPACE}"
echo "  View logs:     kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} --tail=100"
echo "  Rollback:      kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "  Scale:         kubectl scale deployment/${APP_NAME} --replicas=3 -n ${NAMESPACE}"

# Cleanup temp files
rm -rf /tmp/cargo-tracker-k8s

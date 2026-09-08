#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to GCP GKE
# ============================================================

echo "=============================================="
echo "  cargo-tracker - GKE Deployment Script"
echo "=============================================="
echo ""

# ---- Prompt for GCP / GKE details ----
read -p "Enter GCP Project ID: " GCP_PROJECT
if [ -z "$GCP_PROJECT" ]; then
  echo "ERROR: GCP Project ID is required."
  exit 1
fi

read -p "Enter GCP Zone (e.g., us-central1-a): " GCP_ZONE
if [ -z "$GCP_ZONE" ]; then
  echo "ERROR: GCP Zone is required."
  exit 1
fi

read -p "Enter GKE Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: GKE Cluster Name is required."
  exit 1
fi

read -p "Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/repo/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "---- Optional: Application Environment Variables ----"
echo "Press Enter to skip any variable."
echo ""

read -p "Enter DB_JDBC_URL (e.g., jdbc:h2:file:/opt/cargo-tracker-data/cargo-tracker-database): " DB_JDBC_URL
DB_JDBC_URL="${DB_JDBC_URL:-jdbc:h2:file:/opt/cargo-tracker-data/cargo-tracker-database}"

read -p "Enter DB_USER (or press Enter to skip): " DB_USER
DB_USER="${DB_USER:-}"

read -p "Enter DB_PASSWORD (or press Enter to skip): " DB_PASSWORD
DB_PASSWORD="${DB_PASSWORD:-}"

read -p "Enter GRAPH_TRAVERSAL_URL (or press Enter for default): " GRAPH_TRAVERSAL_URL
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL:-http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path}"

echo ""
echo "----------------------------------------------"
echo "  GCP Project : $GCP_PROJECT"
echo "  GCP Zone    : $GCP_ZONE"
echo "  GKE Cluster : $CLUSTER_NAME"
echo "  Image URI   : $IMAGE_URI"
echo "----------------------------------------------"
echo ""

# ---- Configure kubectl for GKE ----
echo "Configuring kubectl for GKE cluster..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT"

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to GKE cluster."; exit 1; }

echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
DEPLOY_DIR=$(mktemp -d)
cp kubernetes/namespace.yaml "$DEPLOY_DIR/"
cp kubernetes/deployment.yaml "$DEPLOY_DIR/"
cp kubernetes/service.yaml "$DEPLOY_DIR/"
cp kubernetes/ingress.yaml "$DEPLOY_DIR/"

# Replace placeholders using pipe delimiter
sed -i 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' "$DEPLOY_DIR/deployment.yaml"
sed -i 's|{{DB_JDBC_URL}}|'"$DB_JDBC_URL"'|g' "$DEPLOY_DIR/deployment.yaml"
sed -i 's|{{DB_USER}}|'"$DB_USER"'|g' "$DEPLOY_DIR/deployment.yaml"
sed -i 's|{{DB_PASSWORD}}|'"$DB_PASSWORD"'|g' "$DEPLOY_DIR/deployment.yaml"
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|'"$GRAPH_TRAVERSAL_URL"'|g' "$DEPLOY_DIR/deployment.yaml"

echo ""
echo "Applying Kubernetes manifests..."
echo "----------------------------------------------"

echo "[1/4] Applying namespace..."
kubectl apply -f "$DEPLOY_DIR/namespace.yaml"

echo "[2/4] Applying deployment..."
kubectl apply -f "$DEPLOY_DIR/deployment.yaml"

echo "[3/4] Applying service..."
kubectl apply -f "$DEPLOY_DIR/service.yaml"

echo "[4/4] Applying ingress..."
kubectl apply -f "$DEPLOY_DIR/ingress.yaml"

echo ""
echo "Waiting for deployment rollout..."
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n cargo-tracker

echo ""
echo "----------------------------------------------"
echo "Fetching application URL from ingress..."
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n cargo-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$INGRESS_IP" = "pending" ] || [ -z "$INGRESS_IP" ]; then
  echo "Ingress IP is still being provisioned. Check later with:"
  echo "  kubectl get ingress cargo-tracker-ingress -n cargo-tracker"
else
  echo "Application is accessible at: http://$INGRESS_IP/cargo-tracker"
fi

# Cleanup temp dir
rm -rf "$DEPLOY_DIR"

echo ""
echo "=============================================="
echo "  Deployment complete!"
echo "  Namespace : cargo-tracker"
echo "  Image     : $IMAGE_URI"
echo "=============================================="
echo ""
echo "Rollback command (if needed):"
echo "  kubectl rollout undo deployment/cargo-tracker -n cargo-tracker"

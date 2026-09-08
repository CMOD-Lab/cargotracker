#!/bin/bash
# ============================================================
# deploy-image.sh - Deploy to GCP GKE
# Eclipse Cargo Tracker - Jakarta EE 10 Application
# Target Platform: GCP GKE
# ============================================================
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
K8S_DIR="kubernetes"

echo "============================================================"
echo "  Eclipse Cargo Tracker - GKE Deployment"
echo "============================================================"
echo ""

# ---- Prompt for GCP configuration ----
read -rp "Enter GCP Project ID: " GCP_PROJECT
if [ -z "$GCP_PROJECT" ]; then
  echo "ERROR: GCP Project ID is required."
  exit 1
fi

read -rp "Enter GCP Zone (e.g., us-central1-a): " GCP_ZONE
if [ -z "$GCP_ZONE" ]; then
  echo "ERROR: GCP Zone is required."
  exit 1
fi

read -rp "Enter GKE Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: GKE Cluster Name is required."
  exit 1
fi

read -rp "Enter full Docker Image URI (e.g., us-central1-docker.pkg.dev/my-project/repo/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker Image URI is required."
  exit 1
fi

echo ""
echo "---- Optional: Application Environment Variables ----"
echo "Press Enter to skip any variable (placeholder will remain in manifest)."
echo ""

read -rp "Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/db) [skip]: " DB_JDBC_URL_VAL
read -rp "Enter DB_USER [skip]: " DB_USER_VAL
read -rsp "Enter DB_PASSWORD [skip]: " DB_PASSWORD_VAL
echo ""
read -rp "Enter GRAPH_TRAVERSAL_URL (e.g., http://pathfinder-svc/rest/graph-traversal/shortest-path) [skip]: " GRAPH_TRAVERSAL_URL_VAL

echo ""
echo "------------------------------------------------------------"
echo "  GCP Project  : ${GCP_PROJECT}"
echo "  GCP Zone     : ${GCP_ZONE}"
echo "  Cluster      : ${CLUSTER_NAME}"
echo "  Image URI    : ${IMAGE_URI}"
echo "  Namespace    : ${NAMESPACE}"
echo "------------------------------------------------------------"
echo ""

# ---- Configure kubectl for GKE ----
echo "Configuring kubectl for GKE cluster..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --zone "${GCP_ZONE}" \
  --project "${GCP_PROJECT}"

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to cluster."; exit 1; }

echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
cp -r "${K8S_DIR}" /tmp/cargo-tracker-k8s-deploy

# Replace IMAGE_URI placeholder
sed -i 's|{{IMAGE_URI}}|'"${IMAGE_URI}"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml

# Replace environment variable placeholders
if [ -n "$DB_JDBC_URL_VAL" ]; then
  sed -i 's|{{DB_JDBC_URL}}|'"${DB_JDBC_URL_VAL}"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
else
  sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
fi

if [ -n "$DB_USER_VAL" ]; then
  sed -i 's|{{DB_USER}}|'"${DB_USER_VAL}"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
else
  sed -i 's|{{DB_USER}}||g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
fi

if [ -n "$DB_PASSWORD_VAL" ]; then
  sed -i 's|{{DB_PASSWORD}}|'"${DB_PASSWORD_VAL}"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
else
  sed -i 's|{{DB_PASSWORD}}||g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
fi

if [ -n "$GRAPH_TRAVERSAL_URL_VAL" ]; then
  sed -i 's|{{GRAPH_TRAVERSAL_URL}}|'"${GRAPH_TRAVERSAL_URL_VAL}"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
else
  sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/rest/graph-traversal/shortest-path|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
fi

echo "Manifests updated."
echo ""

# ---- Apply Kubernetes manifests in order ----
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/namespace.yaml

echo "  [2/4] Applying deployment..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo "  [3/4] Applying service..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/service.yaml

echo "  [4/4] Applying ingress..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/ingress.yaml

echo ""
echo "Waiting for deployment rollout to complete..."
echo "(Note: Payara Micro may take 2-3 minutes to start)"
kubectl rollout status deployment/"${APP_NAME}" -n "${NAMESPACE}" --timeout=300s

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n "${NAMESPACE}"

echo ""
echo "------------------------------------------------------------"
echo "  Deployment Complete!"
echo ""
echo "  Application URL: http://cargo-tracker.example.com"
echo "  (Update ingress.yaml with your actual domain)"
echo ""
echo "  To check pod logs:"
echo "    kubectl logs -l app=${APP_NAME} -n ${NAMESPACE} --tail=100"
echo ""
echo "  To rollback if needed:"
echo "    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "------------------------------------------------------------"

# Cleanup temp files
rm -rf /tmp/cargo-tracker-k8s-deploy

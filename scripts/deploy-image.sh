#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to GCP GKE
# ============================================================

echo "============================================================"
echo "  cargo-tracker - GCP GKE Deployment"
echo "============================================================"
echo ""

# ---- Prompt for GCP configuration ----
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

read -p "Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "--- Optional: Application Environment Variables ---"
echo "(Press Enter to skip any variable)"
echo ""

read -p "Enter DB_JDBC_URL (database JDBC URL): " DB_JDBC_URL
read -p "Enter DB_DRIVER_CLASS (JDBC driver class): " DB_DRIVER_CLASS
read -p "Enter DB_USER (database username): " DB_USER
read -s -p "Enter DB_PASSWORD (database password): " DB_PASSWORD
echo ""
read -p "Enter GRAPH_TRAVERSAL_URL (graph traversal service URL): " GRAPH_TRAVERSAL_URL

echo ""
echo "============================================================"
echo "  Configuring kubectl for GKE cluster: $CLUSTER_NAME"
echo "============================================================"

gcloud config set project "$GCP_PROJECT"
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT"

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to cluster."; exit 1; }

echo ""
echo "============================================================"
echo "  Updating Kubernetes manifests with deployment values"
echo "============================================================"

# Create a working copy of manifests
MANIFEST_DIR="kubernetes"

# Update deployment.yaml with actual values using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" ${MANIFEST_DIR}/deployment.yaml

if [ -n "$DB_JDBC_URL" ]; then
  sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g" ${MANIFEST_DIR}/deployment.yaml
else
  sed -i "s|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g" ${MANIFEST_DIR}/deployment.yaml
fi

if [ -n "$DB_DRIVER_CLASS" ]; then
  sed -i "s|{{DB_DRIVER_CLASS}}|${DB_DRIVER_CLASS}|g" ${MANIFEST_DIR}/deployment.yaml
else
  sed -i "s|{{DB_DRIVER_CLASS}}|org.h2.jdbcx.JdbcDataSource|g" ${MANIFEST_DIR}/deployment.yaml
fi

if [ -n "$DB_USER" ]; then
  sed -i "s|{{DB_USER}}|${DB_USER}|g" ${MANIFEST_DIR}/deployment.yaml
else
  sed -i "s|{{DB_USER}}||g" ${MANIFEST_DIR}/deployment.yaml
fi

if [ -n "$DB_PASSWORD" ]; then
  sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" ${MANIFEST_DIR}/deployment.yaml
else
  sed -i "s|{{DB_PASSWORD}}||g" ${MANIFEST_DIR}/deployment.yaml
fi

if [ -n "$GRAPH_TRAVERSAL_URL" ]; then
  sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g" ${MANIFEST_DIR}/deployment.yaml
else
  sed -i "s|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path|g" ${MANIFEST_DIR}/deployment.yaml
fi

echo "Manifests updated successfully."

echo ""
echo "============================================================"
echo "  Applying Kubernetes manifests"
echo "============================================================"

echo "Applying namespace..."
kubectl apply -f ${MANIFEST_DIR}/namespace.yaml

echo "Applying deployment..."
kubectl apply -f ${MANIFEST_DIR}/deployment.yaml

echo "Applying service..."
kubectl apply -f ${MANIFEST_DIR}/service.yaml

echo "Applying ingress..."
kubectl apply -f ${MANIFEST_DIR}/ingress.yaml

echo ""
echo "============================================================"
echo "  Waiting for deployment rollout..."
echo "============================================================"
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s

echo ""
echo "============================================================"
echo "  Verifying deployed resources"
echo "============================================================"
kubectl get pods,svc,ingress -n cargo-tracker

echo ""
echo "============================================================"
echo "  Retrieving application URL"
echo "============================================================"
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n cargo-tracker -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$INGRESS_IP" = "pending" ] || [ -z "$INGRESS_IP" ]; then
  echo "Ingress IP is still being provisioned. Run the following to check:"
  echo "  kubectl get ingress cargo-tracker-ingress -n cargo-tracker"
else
  echo "Application is accessible at: http://${INGRESS_IP}"
fi

echo ""
echo "============================================================"
echo "  Deployment complete!"
echo ""
echo "  Useful commands:"
echo "  kubectl get pods -n cargo-tracker"
echo "  kubectl logs -f deployment/cargo-tracker -n cargo-tracker"
echo "  kubectl rollout undo deployment/cargo-tracker -n cargo-tracker  # Rollback"
echo "============================================================"

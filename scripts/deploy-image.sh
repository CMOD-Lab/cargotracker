#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy cargo-tracker to AWS EKS
# ============================================================

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
K8S_DIR="kubernetes"

echo "=============================================="
echo "  cargo-tracker - AWS EKS Deployment Script"
echo "=============================================="
echo ""

# Prompt for AWS configuration
read -rp "Enter AWS Region (e.g. us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS Region is required."
  exit 1
fi

read -rp "Enter EKS Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: EKS Cluster Name is required."
  exit 1
fi

read -rp "Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "--- Optional Application Configuration ---"
echo "(Press Enter to skip any value and use defaults)"
echo ""

read -rp "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL
GRAPH_TRAVERSAL_URL="${GRAPH_TRAVERSAL_URL:-http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path}"

read -rp "Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: " DB_JDBC_URL
DB_JDBC_URL="${DB_JDBC_URL:-jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database}"

read -rp "Enter DB_USER []: " DB_USER
DB_USER="${DB_USER:-}"

read -rsp "Enter DB_PASSWORD []: " DB_PASSWORD
echo ""
DB_PASSWORD="${DB_PASSWORD:-}"

echo ""
echo "=============================================="
echo "  Configuring kubectl for EKS cluster..."
echo "=============================================="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to EKS cluster."; exit 1; }

echo ""
echo "=============================================="
echo "  Updating Kubernetes manifests..."
echo "=============================================="

# Create working copies of manifests
cp -r "$K8S_DIR" /tmp/cargo-tracker-k8s-deploy

# Replace placeholders using pipe delimiter
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g"                           /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL}|g"      /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL}|g"                      /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER}|g"                              /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g"                      /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo "Manifests updated successfully."

echo ""
echo "=============================================="
echo "  Applying Kubernetes manifests..."
echo "=============================================="

echo "Applying namespace..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/namespace.yaml

echo "Applying deployment..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo "Applying service..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/service.yaml

echo "Applying ingress..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/ingress.yaml

echo ""
echo "=============================================="
echo "  Waiting for deployment rollout..."
echo "=============================================="
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s || {
  echo ""
  echo "ERROR: Deployment rollout failed or timed out."
  echo "To rollback, run: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
}

echo ""
echo "=============================================="
echo "  Verifying deployed resources..."
echo "=============================================="
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "=============================================="
echo "  Retrieving application URL..."
echo "=============================================="
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$INGRESS_HOST" != "pending" ] && [ -n "$INGRESS_HOST" ]; then
  echo "Application URL: http://${INGRESS_HOST}"
else
  echo "Ingress hostname is still being provisioned. Run the following to check:"
  echo "  kubectl get ingress -n ${NAMESPACE}"
fi

echo ""
echo "=============================================="
echo "  Deployment completed successfully!"
echo "  Namespace: ${NAMESPACE}"
echo "  Image:     ${IMAGE_URI}"
echo "=============================================="

# Cleanup temp files
rm -rf /tmp/cargo-tracker-k8s-deploy

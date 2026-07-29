#!/bin/bash
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
K8S_DIR="kubernetes"

echo "============================================"
echo "  Cargo Tracker - Deploy to AWS EKS"
echo "============================================"
echo ""

# Prompt for AWS region
read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS Region is required."
  exit 1
fi

# Prompt for EKS cluster name
read -p "Enter EKS Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: EKS Cluster Name is required."
  exit 1
fi

# Prompt for Docker image URI
read -p "Enter full Docker image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

# Prompt for application-specific environment variables
echo ""
echo "--- Application Configuration (press Enter to skip) ---"
read -p "Enter GRAPH_TRAVERSAL_URL (e.g., http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path): " GRAPH_TRAVERSAL_URL_VAL
if [ -z "$GRAPH_TRAVERSAL_URL_VAL" ]; then
  GRAPH_TRAVERSAL_URL_VAL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
fi

read -p "Enter DB_JDBC_URL (e.g., jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database): " DB_JDBC_URL_VAL
if [ -z "$DB_JDBC_URL_VAL" ]; then
  DB_JDBC_URL_VAL="jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"
fi

read -p "Enter DB_USER (press Enter to skip): " DB_USER_VAL
read -s -p "Enter DB_PASSWORD (press Enter to skip): " DB_PASSWORD_VAL
echo ""

echo ""
echo "Configuring kubectl for EKS cluster: $CLUSTER_NAME in $AWS_REGION..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure kubectl for EKS cluster."
  exit 1
fi

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to Kubernetes cluster."; exit 1; }

echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Create working copies of manifests
cp -r "$K8S_DIR" /tmp/cargo-tracker-k8s-deploy

# Replace placeholders using pipe delimiter
sed -i 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|'"$GRAPH_TRAVERSAL_URL_VAL"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|'"$DB_JDBC_URL_VAL"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i 's|{{DB_USER}}|'"$DB_USER_VAL"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|'"$DB_PASSWORD_VAL"'|g' /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo ""
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
echo "Waiting for deployment rollout..."
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Rolling back..."
  kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE
  echo "Rollback initiated. Check pod status with: kubectl get pods -n $NAMESPACE"
  exit 1
fi

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n $NAMESPACE

echo ""
echo "Fetching application URL..."
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$INGRESS_HOST" != "pending" ] && [ -n "$INGRESS_HOST" ]; then
  echo "Application URL: http://$INGRESS_HOST/cargo-tracker"
else
  echo "Ingress hostname is still being provisioned. Run the following to check:"
  echo "  kubectl get ingress -n $NAMESPACE"
fi

# Cleanup temp files
rm -rf /tmp/cargo-tracker-k8s-deploy

echo ""
echo "============================================"
echo "  Deployment to AWS EKS completed!"
echo "  Namespace: $NAMESPACE"
echo "  Image: $IMAGE_URI"
echo "============================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/$APP_NAME -n $NAMESPACE"
echo "  kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE  # Rollback"

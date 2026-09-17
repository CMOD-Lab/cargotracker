#!/bin/bash
set -e
set -o pipefail

# =============================================================================
# deploy-image.sh - Deploy cargo-tracker to AWS EKS
# =============================================================================

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
MANIFESTS_DIR="kubernetes"

echo "=============================================="
echo "  cargo-tracker - Deploy to AWS EKS"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------
# Collect deployment inputs
# -----------------------------------------------------------------------
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
echo "--- Application Environment Variables ---"
echo "Press Enter to skip any variable (it will keep the placeholder value)."
echo ""

read -rp "Enter POSTGRESQL_JDBC_URL (e.g. jdbc:postgresql://host:5432/cargotracker): " POSTGRESQL_JDBC_URL
read -rp "Enter POSTGRESQL_USERNAME [postgres]: " POSTGRESQL_USERNAME
POSTGRESQL_USERNAME="${POSTGRESQL_USERNAME:-postgres}"
read -rsp "Enter POSTGRESQL_PASSWORD: " POSTGRESQL_PASSWORD
echo ""
read -rp "Enter REDIS_HOST (ElastiCache endpoint): " REDIS_HOST
read -rp "Enter REDIS_PORT [6379]: " REDIS_PORT
REDIS_PORT="${REDIS_PORT:-6379}"
read -rsp "Enter REDIS_PASSWORD (leave blank if none): " REDIS_PASSWORD
echo ""

# -----------------------------------------------------------------------
# Configure kubectl for EKS
# -----------------------------------------------------------------------
echo ""
echo "Configuring kubectl for EKS cluster: $CLUSTER_NAME in $AWS_REGION ..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to EKS cluster."; exit 1; }

# -----------------------------------------------------------------------
# Update Kubernetes manifests with actual values (pipe delimiter in sed)
# -----------------------------------------------------------------------
echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals permanently
cp "${MANIFESTS_DIR}/deployment.yaml" "${MANIFESTS_DIR}/deployment.yaml.deploy"

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"

if [ -n "$POSTGRESQL_JDBC_URL" ]; then
  sed -i "s|{{POSTGRESQL_JDBC_URL}}|${POSTGRESQL_JDBC_URL}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
fi
if [ -n "$POSTGRESQL_USERNAME" ]; then
  sed -i "s|{{POSTGRESQL_USERNAME}}|${POSTGRESQL_USERNAME}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
fi
if [ -n "$POSTGRESQL_PASSWORD" ]; then
  sed -i "s|{{POSTGRESQL_PASSWORD}}|${POSTGRESQL_PASSWORD}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
fi
if [ -n "$REDIS_HOST" ]; then
  sed -i "s|{{REDIS_HOST}}|${REDIS_HOST}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
fi
sed -i "s|{{REDIS_PORT}}|${REDIS_PORT}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
if [ -n "$REDIS_PASSWORD" ]; then
  sed -i "s|{{REDIS_PASSWORD}}|${REDIS_PASSWORD}|g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
else
  sed -i "s|{{REDIS_PASSWORD}}||g" "${MANIFESTS_DIR}/deployment.yaml.deploy"
fi

# -----------------------------------------------------------------------
# Apply Kubernetes manifests in order
# -----------------------------------------------------------------------
echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"

echo "  [2/4] Applying deployment..."
kubectl apply -f "${MANIFESTS_DIR}/deployment.yaml.deploy"

echo "  [3/4] Applying service..."
kubectl apply -f "${MANIFESTS_DIR}/service.yaml"

echo "  [4/4] Applying ingress..."
kubectl apply -f "${MANIFESTS_DIR}/ingress.yaml"

# Clean up temporary file
rm -f "${MANIFESTS_DIR}/deployment.yaml.deploy"

# -----------------------------------------------------------------------
# Wait for rollout
# -----------------------------------------------------------------------
echo ""
echo "Waiting for deployment rollout: $APP_NAME in namespace $NAMESPACE ..."
kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout=300s

# -----------------------------------------------------------------------
# Verify resources
# -----------------------------------------------------------------------
echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n "$NAMESPACE"

# -----------------------------------------------------------------------
# Display application URL
# -----------------------------------------------------------------------
echo ""
echo "Fetching application ingress URL..."
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$INGRESS_HOST" ]; then
  echo ""
  echo "=============================================="
  echo "  Application is accessible at:"
  echo "  http://${INGRESS_HOST}"
  echo "  https://${INGRESS_HOST}"
  echo "=============================================="
else
  echo "INFO: Ingress hostname not yet assigned. Run the following to check:"
  echo "  kubectl get ingress -n $NAMESPACE"
fi

echo ""
echo "Deployment completed successfully!"
echo ""
echo "--- Rollback Instructions ---"
echo "To rollback to the previous version:"
echo "  kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE"
echo ""
echo "To check rollout history:"
echo "  kubectl rollout history deployment/$APP_NAME -n $NAMESPACE"

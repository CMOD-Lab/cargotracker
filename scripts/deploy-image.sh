#!/bin/bash
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
K8S_DIR="kubernetes"

echo "============================================================"
echo "  Cargo Tracker - Deploy to Azure AKS"
echo "============================================================"
echo ""

# ── Azure credentials ──────────────────────────────────────────
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

# ── Docker image ───────────────────────────────────────────────
read -rp "Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Image URI cannot be empty."
  exit 1
fi

# ── Application environment variables ─────────────────────────
echo ""
echo "Configure application environment variables (press Enter to use defaults):"

read -rp "Enter DB_JDBC_URL [jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database]: " DB_JDBC_URL_VAL
DB_JDBC_URL_VAL="${DB_JDBC_URL_VAL:-jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database}"

read -rp "Enter DB_USER [leave empty for H2]: " DB_USER_VAL
DB_USER_VAL="${DB_USER_VAL:-}"

read -rsp "Enter DB_PASSWORD [leave empty for H2]: " DB_PASSWORD_VAL
echo ""
DB_PASSWORD_VAL="${DB_PASSWORD_VAL:-}"

read -rp "Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: " GRAPH_TRAVERSAL_URL_VAL
GRAPH_TRAVERSAL_URL_VAL="${GRAPH_TRAVERSAL_URL_VAL:-http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path}"

# ── Configure kubectl ──────────────────────────────────────────
echo ""
echo "Configuring kubectl for AKS cluster: ${CLUSTER_NAME} ..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
echo "kubectl configured successfully."

echo ""
echo "Verifying cluster connectivity ..."
kubectl cluster-info || { echo "ERROR: Cannot connect to AKS cluster."; exit 1; }

# ── Patch manifests ────────────────────────────────────────────
echo ""
echo "Updating Kubernetes manifests with deployment values ..."

# Work on copies to avoid modifying originals
cp -r "${K8S_DIR}" /tmp/cargo-tracker-k8s-deploy

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g"                                   /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_JDBC_URL}}|${DB_JDBC_URL_VAL}|g"                          /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_USER}}|${DB_USER_VAL}|g"                                   /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD_VAL}|g"                           /tmp/cargo-tracker-k8s-deploy/deployment.yaml
sed -i "s|{{GRAPH_TRAVERSAL_URL}}|${GRAPH_TRAVERSAL_URL_VAL}|g"           /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo "Manifests updated."

# ── Apply manifests ────────────────────────────────────────────
echo ""
echo "Applying Kubernetes manifests ..."

echo "  [1/4] Applying namespace ..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/namespace.yaml

echo "  [2/4] Applying deployment ..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/deployment.yaml

echo "  [3/4] Applying service ..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/service.yaml

echo "  [4/4] Applying ingress ..."
kubectl apply -f /tmp/cargo-tracker-k8s-deploy/ingress.yaml

# ── Wait for rollout ───────────────────────────────────────────
echo ""
echo "Waiting for deployment rollout ..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s

# ── Verify resources ───────────────────────────────────────────
echo ""
echo "Verifying deployed resources ..."
kubectl get pods,svc,ingress -n ${NAMESPACE}

# ── Display access URL ─────────────────────────────────────────
echo ""
INGRESS_IP=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_HOST=$(kubectl get ingress cargo-tracker-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "cargo-tracker.example.com")

echo "============================================================"
echo "  Deployment Complete!"
echo "  Application: ${APP_NAME}"
echo "  Namespace:   ${NAMESPACE}"
if [ -n "$INGRESS_IP" ]; then
  echo "  Access URL:  http://${INGRESS_IP}/"
else
  echo "  Ingress Host: ${INGRESS_HOST}"
  echo "  (Update DNS to point ${INGRESS_HOST} to the ingress IP)"
fi
echo ""
echo "  Rollback command (if needed):"
echo "    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "============================================================"

# Cleanup temp files
rm -rf /tmp/cargo-tracker-k8s-deploy

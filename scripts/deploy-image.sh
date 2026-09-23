#!/bin/bash
set -e
set -o pipefail

APP_NAME="cargo-tracker"
NAMESPACE="cargo-tracker"
DEPLOYMENT_FILE="kubernetes/deployment.yaml"
SERVICE_FILE="kubernetes/service.yaml"
INGRESS_FILE="kubernetes/ingress.yaml"
NAMESPACE_FILE="kubernetes/namespace.yaml"

read -r -p "Enter Azure resource group: " RESOURCE_GROUP
read -r -p "Enter AKS cluster name: " CLUSTER_NAME
read -r -p "Enter Docker image URI (including tag): " IMAGE_URI
read -r -p "Enter value for POSTGRESQL_JDBC_URL (or press Enter to skip): " POSTGRESQL_JDBC_URL
read -r -p "Enter value for POSTGRESQL_USERNAME (or press Enter to skip): " POSTGRESQL_USERNAME
read -r -p "Enter value for POSTGRESQL_PASSWORD (or press Enter to skip): " POSTGRESQL_PASSWORD
read -r -p "Enter value for GRAPH_TRAVERSAL_URL (or press Enter to skip): " GRAPH_TRAVERSAL_URL

if [ -z "$RESOURCE_GROUP" ] || [ -z "$CLUSTER_NAME" ] || [ -z "$IMAGE_URI" ]; then
  echo "Resource group, cluster name, and image URI are required."
  exit 1
fi

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
kubectl cluster-info

cp "$DEPLOYMENT_FILE" "$DEPLOYMENT_FILE.tmp"
sed -i 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' "$DEPLOYMENT_FILE.tmp"
sed -i 's|{{POSTGRESQL_JDBC_URL}}|'"${POSTGRESQL_JDBC_URL}"'|g' "$DEPLOYMENT_FILE.tmp"
sed -i 's|{{POSTGRESQL_USERNAME}}|'"${POSTGRESQL_USERNAME}"'|g' "$DEPLOYMENT_FILE.tmp"
sed -i 's|{{POSTGRESQL_PASSWORD}}|'"${POSTGRESQL_PASSWORD}"'|g' "$DEPLOYMENT_FILE.tmp"
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|'"${GRAPH_TRAVERSAL_URL}"'|g' "$DEPLOYMENT_FILE.tmp"

kubectl apply -f "$NAMESPACE_FILE"
kubectl apply -f "$DEPLOYMENT_FILE.tmp"
kubectl apply -f "$SERVICE_FILE"
kubectl apply -f "$INGRESS_FILE"

kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE}
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo "Application should be available via the configured ingress host once DNS is mapped."
echo "Rollback command: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"

rm -f "$DEPLOYMENT_FILE.tmp"

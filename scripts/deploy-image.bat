@echo off
setlocal enabledelayedexpansion

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"

set /p RESOURCE_GROUP="Enter Azure resource group: "
set /p CLUSTER_NAME="Enter AKS cluster name: "
set /p IMAGE_URI="Enter Docker image URI (including tag): "
set /p POSTGRESQL_JDBC_URL="Enter value for POSTGRESQL_JDBC_URL (or press Enter to skip): "
set /p POSTGRESQL_USERNAME="Enter value for POSTGRESQL_USERNAME (or press Enter to skip): "
set /p POSTGRESQL_PASSWORD="Enter value for POSTGRESQL_PASSWORD (or press Enter to skip): "
set /p GRAPH_TRAVERSAL_URL="Enter value for GRAPH_TRAVERSAL_URL (or press Enter to skip): "

if "!RESOURCE_GROUP!"=="" (
  echo Resource group is required
  exit /b 1
)
if "!CLUSTER_NAME!"=="" (
  echo Cluster name is required
  exit /b 1
)
if "!IMAGE_URI!"=="" (
  echo Image URI is required
  exit /b 1
)

az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if %ERRORLEVEL% neq 0 exit /b 1
kubectl cluster-info
if %ERRORLEVEL% neq 0 exit /b 1

powershell -NoProfile -Command "(Get-Content 'kubernetes/deployment.yaml') -replace '\{\{IMAGE_URI\}\}','!IMAGE_URI!' -replace '\{\{POSTGRESQL_JDBC_URL\}\}','!POSTGRESQL_JDBC_URL!' -replace '\{\{POSTGRESQL_USERNAME\}\}','!POSTGRESQL_USERNAME!' -replace '\{\{POSTGRESQL_PASSWORD\}\}','!POSTGRESQL_PASSWORD!' -replace '\{\{GRAPH_TRAVERSAL_URL\}\}','!GRAPH_TRAVERSAL_URL!' | Set-Content 'kubernetes/deployment.rendered.yaml'"
if %ERRORLEVEL% neq 0 exit /b 1

kubectl apply -f kubernetes/namespace.yaml
if %ERRORLEVEL% neq 0 exit /b 1
kubectl apply -f kubernetes/deployment.rendered.yaml
if %ERRORLEVEL% neq 0 exit /b 1
kubectl apply -f kubernetes/service.yaml
if %ERRORLEVEL% neq 0 exit /b 1
kubectl apply -f kubernetes/ingress.yaml
if %ERRORLEVEL% neq 0 exit /b 1
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE!
if %ERRORLEVEL% neq 0 exit /b 1
kubectl get pods,svc,ingress -n !NAMESPACE!

echo Application should be available via the configured ingress host once DNS is mapped.
echo Rollback command: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
exit /b 0

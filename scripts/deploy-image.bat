@echo off
setlocal enabledelayedexpansion

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker

echo ============================================
echo   Deploy %APP_NAME% to Azure AKS
echo ============================================
echo.

set /p RESOURCE_GROUP="Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

set /p CLUSTER_NAME="Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI cannot be empty.
    exit /b 1
)

echo.
echo --- Application Configuration (press Enter to skip optional values) ---
set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL (default: http://localhost:8080/rest/graph-traversal/shortest-path): "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path

set /p DB_JDBC_URL="Enter DB_JDBC_URL (default: jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database): "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database

set /p DB_USER="Enter DB_USER (or press Enter to skip): "
set /p DB_PASSWORD="Enter DB_PASSWORD (or press Enter to skip): "

echo.
echo --- Configuring kubectl for AKS ---
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

echo.
echo --- Updating Kubernetes manifests ---
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DB_USER}}', '!DB_USER!' | Set-Content kubernetes\deployment.yaml"

echo.
echo --- Applying Kubernetes manifests ---
echo Applying namespace...
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo Applying deployment...
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo Applying service...
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo Applying ingress...
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

echo.
echo --- Waiting for deployment rollout ---
kubectl rollout status deployment/%APP_NAME% -n %NAMESPACE% --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed.
    echo Run: kubectl get pods -n %NAMESPACE%
    echo To rollback: kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%
    exit /b 1
)

echo.
echo --- Verifying deployed resources ---
kubectl get pods,svc,ingress -n %NAMESPACE%

echo.
echo ============================================
echo   Deployment Completed Successfully!
echo   App: %APP_NAME%
echo   Namespace: %NAMESPACE%
echo ============================================
echo.
echo Useful commands:
echo   kubectl get pods -n %NAMESPACE%
echo   kubectl logs -f deployment/%APP_NAME% -n %NAMESPACE%
echo   kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%

endlocal

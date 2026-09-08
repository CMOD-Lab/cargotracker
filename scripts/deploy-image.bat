@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Deploy cargo-tracker to Azure AKS
echo ============================================

rem Prompt for Azure resource group
set /p RESOURCE_GROUP="Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

rem Prompt for AKS cluster name
set /p CLUSTER_NAME="Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

rem Prompt for Docker image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

echo.
echo --- Application Configuration (press Enter to skip optional values) ---

set /p DB_JDBC_URL="Enter DB_JDBC_URL [jdbc:postgresql://localhost:5432/cargotracker]: "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:postgresql://localhost:5432/cargotracker

set /p DB_USER="Enter DB_USER [postgres]: "
if "!DB_USER!"=="" set DB_USER=postgres

set /p DB_PASSWORD="Enter DB_PASSWORD [postgres]: "
if "!DB_PASSWORD!"=="" set DB_PASSWORD=postgres

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path

echo.
echo Configuring kubectl for AKS cluster: !CLUSTER_NAME! in resource group: !RESOURCE_GROUP! ...
az aks get-credentials --resource-group !RESOURCE_GROUP! --name !CLUSTER_NAME! --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials.
    exit /b 1
)

echo Verifying cluster connectivity ...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

echo.
echo Updating Kubernetes manifests with provided values ...

rem Use PowerShell to replace placeholders in deployment.yaml
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DB_USER}}', '!DB_USER!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DB_PASSWORD}}', '!DB_PASSWORD!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content kubernetes\deployment.yaml"

echo.
echo Applying Kubernetes manifests ...

echo   [1/4] Applying namespace ...
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo   [2/4] Applying deployment ...
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo   [3/4] Applying service ...
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo   [4/4] Applying ingress ...
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

echo.
echo Waiting for deployment rollout ...
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Running rollback ...
    kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
    echo Rollback initiated. Check pod status with: kubectl get pods -n cargo-tracker
    exit /b 1
)

echo.
echo Verifying deployed resources ...
kubectl get pods,svc,ingress -n cargo-tracker

echo.
echo ============================================
echo   Deployment Successful!
echo   Application URL: http://cargo-tracker.example.com
echo   Namespace: cargo-tracker
echo ============================================
echo.
echo Useful commands:
echo   kubectl get pods -n cargo-tracker
echo   kubectl logs -f deployment/cargo-tracker -n cargo-tracker
echo   kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

endlocal

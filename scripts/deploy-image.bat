@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem Deploy cargo-tracker to Azure AKS
rem ============================================================

echo ============================================================
echo   Deploy cargo-tracker to Azure AKS
echo ============================================================
echo.

rem Prompt for Azure Resource Group
set /p RESOURCE_GROUP="Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

rem Prompt for AKS Cluster Name
set /p CLUSTER_NAME="Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

rem Prompt for Docker Image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI cannot be empty.
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo   Configuration:
echo   Resource Group : !RESOURCE_GROUP!
echo   AKS Cluster    : !CLUSTER_NAME!
echo   Image URI      : !IMAGE_URI!
echo ------------------------------------------------------------
echo.

rem Prompt for application environment variables
echo Configure application environment variables (press Enter to skip):
echo.

set /p DB_JDBC_URL="Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/cargotracker): "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database

set /p DB_DRIVER_CLASS="Enter DB_DRIVER_CLASS (e.g., org.postgresql.ds.PGPoolingDataSource): "
if "!DB_DRIVER_CLASS!"=="" set DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource

set /p DB_USER="Enter DB_USER: "
if "!DB_USER!"=="" set DB_USER=

set /p DB_PASSWORD="Enter DB_PASSWORD: "
if "!DB_PASSWORD!"=="" set DB_PASSWORD=

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL (press Enter for default): "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path

echo.
echo Configuring kubectl for AKS cluster...
az aks get-credentials --resource-group !RESOURCE_GROUP! --name !CLUSTER_NAME! --overwrite-existing
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

rem Create temporary deployment directory
if exist kubernetes_deploy_tmp rmdir /s /q kubernetes_deploy_tmp
xcopy /s /e /i /q kubernetes kubernetes_deploy_tmp >nul

rem Update Kubernetes manifests with actual values using PowerShell
echo Updating Kubernetes manifests with deployment values...

powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{DB_DRIVER_CLASS}}', '!DB_DRIVER_CLASS!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{DB_USER}}', '!DB_USER!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{DB_PASSWORD}}', '!DB_PASSWORD!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes_deploy_tmp\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content 'kubernetes_deploy_tmp\deployment.yaml'"

echo Manifests updated successfully.
echo.

rem Apply Kubernetes manifests in order
echo Applying Kubernetes manifests...
echo.

echo [1/4] Applying namespace...
kubectl apply -f kubernetes_deploy_tmp\namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    rmdir /s /q kubernetes_deploy_tmp
    exit /b 1
)
echo.

echo [2/4] Applying deployment...
kubectl apply -f kubernetes_deploy_tmp\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    rmdir /s /q kubernetes_deploy_tmp
    exit /b 1
)
echo.

echo [3/4] Applying service...
kubectl apply -f kubernetes_deploy_tmp\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    rmdir /s /q kubernetes_deploy_tmp
    exit /b 1
)
echo.

echo [4/4] Applying ingress...
kubectl apply -f kubernetes_deploy_tmp\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    rmdir /s /q kubernetes_deploy_tmp
    exit /b 1
)
echo.

rem Clean up temporary manifests
rmdir /s /q kubernetes_deploy_tmp

rem Wait for deployment rollout
echo Waiting for deployment rollout to complete...
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo Run the following to check pod status:
    echo   kubectl get pods -n cargo-tracker
    echo   kubectl describe pods -n cargo-tracker
    echo.
    echo To rollback:
    echo   kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
    exit /b 1
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n cargo-tracker
echo.

echo ============================================================
echo   DEPLOYMENT SUCCESSFUL!
echo ============================================================
echo.
echo   Ingress Host: http://cargo-tracker.example.com/cargo-tracker
echo.
echo   To check pod logs:
echo     kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=100
echo.
echo   To rollback if needed:
echo     kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
echo ============================================================

endlocal
